import { useCallback, useEffect, useRef, useState } from "react";
import {
  buildMemoryContext,
  endSession,
  onLlmComplete,
  onLlmReasoning,
  onLlmToken,
  processConversation,
  sendMessage,
  sendMessageStream,
  speakText,
} from "../services/tauriCommands";
import {
  assistantMessage,
  toolMessage,
  userMessage,
  type ChatMessage,
  type ChatState,
  type ToolCall,
} from "../types/chat";

const MAX_HISTORY = 20;
const MAX_TOOL_ROUNDS = 5;

export type ChatNoticeReason = "missingConfig" | "networkError" | "serverError" | "emptyResponse" | "toolLimit";

export interface ChatManager {
  history: ChatMessage[];
  streamingContent: string;
  reasoningContent: string;
  chatState: ChatState;
  toolStatus: string | null;
  queuedMessages: ChatMessage[];
  send: (text: string) => void;
  updateQueuedMessage: (index: number, text: string) => void;
  removeQueuedMessage: (index: number) => void;
  cancel: () => void;
  clearHistory: () => void;
}

export function useChatManager(
  ttsEnabled: boolean,
  onNotice?: (reason: ChatNoticeReason, detail?: string) => void
): ChatManager {
  const [history, setHistory] = useState<ChatMessage[]>([]);
  const [streamingContent, setStreamingContent] = useState("");
  const [reasoningContent, setReasoningContent] = useState("");
  const [chatState, setChatState] = useState<ChatState>("idle");
  const [toolStatus, setToolStatus] = useState<string | null>(null);
  const [queuedMessages, setQueuedMessages] = useState<ChatMessage[]>([]);

  const historyRef = useRef<ChatMessage[]>([]);
  const cancelledRef = useRef(false);
  const processingRef = useRef(false);
  const queuedMessagesRef = useRef<ChatMessage[]>([]);
  const processNextQueuedRef = useRef<() => void>(() => {});
  const ttsEnabledRef = useRef(ttsEnabled);
  ttsEnabledRef.current = ttsEnabled;

  useEffect(() => {
    historyRef.current = history;
  }, [history]);

  const appendMessage = useCallback((msg: ChatMessage) => {
    setHistory((h) => {
      const updated = [...h, msg];
      historyRef.current = updated;
      return updated;
    });
  }, []);

  const syncQueuedMessages = useCallback(() => {
    setQueuedMessages([...queuedMessagesRef.current]);
  }, []);

  const showError = useCallback(
    (err: unknown) => {
      const message = err instanceof Error ? err.message : String(err);
      onNotice?.(classifyError(message), message);
      appendMessage(assistantMessage(`请求失败：${message}`));
      setStreamingContent("");
      setReasoningContent("");
      setToolStatus(null);
      processNextQueuedRef.current();
    },
    [appendMessage, onNotice]
  );

  const completeCurrentTurn = useCallback(
    async (assistantText?: string, shouldProcessMemory = true) => {
      setStreamingContent("");
      setReasoningContent("");
      setToolStatus(null);

      if (shouldProcessMemory) {
        await processConversation([...historyRef.current]).catch(() => {});
      }

      if (ttsEnabledRef.current && assistantText) {
        speakText(assistantText).catch(() => {});
      }

      processNextQueuedRef.current();
    },
    []
  );

  const sendToLLM = useCallback(
    async (toolRound: number) => {
      if (cancelledRef.current) return;

      const memoryContext = await buildMemoryContext().catch(() => "");
      const recent = historyRef.current.slice(-MAX_HISTORY);
      const messages: ChatMessage[] = memoryContext
        ? [{ role: "system", content: memoryContext, timestamp: new Date().toISOString() }, ...recent]
        : recent;

      let tokenBuffer = "";
      let reasoningBuffer = "";
      setReasoningContent("");

      const unlistenReasoning = await onLlmReasoning((token) => {
        if (cancelledRef.current) return;
        reasoningBuffer += token;
        setChatState("streaming");
        setReasoningContent((s) => s + token);
      });

      const unlistenToken = await onLlmToken((token) => {
        if (cancelledRef.current) return;
        tokenBuffer += token;
        setChatState("streaming");
        setStreamingContent((s) => s + token);
      });

      const unlistenComplete = await onLlmComplete(async () => {
        unlistenReasoning();
        unlistenToken();
        unlistenComplete();

        if (cancelledRef.current) return;

        if (!tokenBuffer) {
          await sendNonStreaming(messages, toolRound);
          return;
        }

        const assistMsg = assistantMessage(tokenBuffer, undefined, reasoningBuffer || undefined);
        appendMessage(assistMsg);
        await completeCurrentTurn(tokenBuffer);
      });

      await sendMessageStream(messages).catch((err) => {
        unlistenReasoning();
        unlistenToken();
        unlistenComplete();
        console.error("[LLM Stream]", err);
        showError(err);
      });
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [appendMessage, completeCurrentTurn, showError]
  );

  const sendNonStreaming = useCallback(
    async (messages: ChatMessage[], toolRound: number) => {
      if (toolRound >= MAX_TOOL_ROUNDS) {
        onNotice?.("toolLimit");
        appendMessage(assistantMessage("工具调用次数过多，已停止喵~"));
        await completeCurrentTurn(undefined, false);
        return;
      }

      try {
        const response = await sendMessage(messages);
        if (cancelledRef.current) return;

        if (response.tool_calls.length > 0) {
          await handleToolCalls(response.tool_calls, response.content, toolRound);
        } else if (response.content) {
          const assistMsg = assistantMessage(response.content);
          appendMessage(assistMsg);
          await completeCurrentTurn(response.content);
        } else {
          onNotice?.("emptyResponse");
          appendMessage(assistantMessage("模型返回了空内容，请检查模型是否支持当前参数或工具调用。"));
          await completeCurrentTurn(undefined, false);
        }
      } catch (err) {
        showError(err);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [appendMessage, completeCurrentTurn, showError]
  );

  const handleToolCalls = useCallback(
    async (toolCalls: ToolCall[], assistantContent: string, toolRound: number) => {
      setChatState("toolCalling");

      const assistMsg = assistantMessage(assistantContent, toolCalls);
      appendMessage(assistMsg);

      const { executeTool } = await import("../services/tauriCommands");

      for (const tc of toolCalls) {
        setToolStatus(`正在执行: ${tc.function_name}...`);
        let args: Record<string, unknown> = {};
        try {
          args = JSON.parse(tc.arguments);
        } catch {}

        const result = await executeTool(tc.function_name, args).catch(
          (e) => `执行失败: ${e}`
        );

        appendMessage(toolMessage(result, tc.id));
      }

      setToolStatus(null);

      // 继续发给 LLM
      await sendToLLM(toolRound + 1);
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [appendMessage]
  );

  const startMessage = useCallback(
    (msg: ChatMessage) => {
      processingRef.current = true;
      cancelledRef.current = false;
      appendMessage(msg);
      setChatState("waiting");
      setStreamingContent("");
      setReasoningContent("");
      setToolStatus(null);
      void sendToLLM(0);
    },
    [appendMessage, sendToLLM]
  );

  const processNextQueued = useCallback(() => {
    if (cancelledRef.current) return;

    const next = queuedMessagesRef.current.shift();
    syncQueuedMessages();

    if (!next) {
      processingRef.current = false;
      setChatState("idle");
      return;
    }

    startMessage(next);
  }, [startMessage, syncQueuedMessages]);

  processNextQueuedRef.current = processNextQueued;

  const send = useCallback(
    (text: string) => {
      const trimmed = text.trim();
      if (!trimmed) return;

      const userMsg = userMessage(trimmed);
      if (processingRef.current) {
        queuedMessagesRef.current.push(userMsg);
        syncQueuedMessages();
        return;
      }

      startMessage(userMsg);
    },
    [startMessage, syncQueuedMessages]
  );

  const updateQueuedMessage = useCallback(
    (index: number, text: string) => {
      const trimmed = text.trim();
      if (index < 0 || index >= queuedMessagesRef.current.length) return;

      if (!trimmed) {
        queuedMessagesRef.current.splice(index, 1);
      } else {
        queuedMessagesRef.current[index] = {
          ...queuedMessagesRef.current[index],
          content: trimmed,
          timestamp: new Date().toISOString(),
        };
      }

      syncQueuedMessages();
    },
    [syncQueuedMessages]
  );

  const removeQueuedMessage = useCallback(
    (index: number) => {
      if (index < 0 || index >= queuedMessagesRef.current.length) return;
      queuedMessagesRef.current.splice(index, 1);
      syncQueuedMessages();
    },
    [syncQueuedMessages]
  );

  const cancel = useCallback(() => {
    cancelledRef.current = true;
    processingRef.current = false;
    queuedMessagesRef.current = [];
    syncQueuedMessages();
    setChatState("idle");
    setStreamingContent("");
    setReasoningContent("");
    setToolStatus(null);
  }, [syncQueuedMessages]);

  const clearHistory = useCallback(() => {
    setHistory([]);
    historyRef.current = [];
    queuedMessagesRef.current = [];
    syncQueuedMessages();
  }, [syncQueuedMessages]);

  // app 关闭时保存会话记忆
  useEffect(() => {
    const handleBeforeUnload = () => {
      endSession(historyRef.current).catch(() => {});
    };
    window.addEventListener("beforeunload", handleBeforeUnload);
    return () => window.removeEventListener("beforeunload", handleBeforeUnload);
  }, []);

  return {
    history,
    streamingContent,
    reasoningContent,
    chatState,
    toolStatus,
    queuedMessages,
    send,
    updateQueuedMessage,
    removeQueuedMessage,
    cancel,
    clearHistory,
  };
}

function classifyError(message: string): ChatNoticeReason {
  if (message.includes("API Key") || message.includes("未配置")) return "missingConfig";
  if (message.includes("网络错误") || message.includes("Failed to fetch")) return "networkError";
  return "serverError";
}
