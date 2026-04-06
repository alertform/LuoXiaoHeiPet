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

export interface ChatManager {
  history: ChatMessage[];
  streamingContent: string;
  reasoningContent: string;
  chatState: ChatState;
  toolStatus: string | null;
  send: (text: string) => void;
  cancel: () => void;
  clearHistory: () => void;
}

export function useChatManager(ttsEnabled: boolean): ChatManager {
  const [history, setHistory] = useState<ChatMessage[]>([]);
  const [streamingContent, setStreamingContent] = useState("");
  const [reasoningContent, setReasoningContent] = useState("");
  const [chatState, setChatState] = useState<ChatState>("idle");
  const [toolStatus, setToolStatus] = useState<string | null>(null);

  const historyRef = useRef<ChatMessage[]>([]);
  const cancelledRef = useRef(false);
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

  const send = useCallback(
    async (text: string) => {
      cancelledRef.current = false;
      const userMsg = userMessage(text);
      appendMessage(userMsg);
      setChatState("waiting");
      setStreamingContent("");

      await sendToLLM(0);
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [appendMessage]
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
      setReasoningContent("");

      const unlistenReasoning = await onLlmReasoning((token) => {
        if (cancelledRef.current) return;
        setChatState("streaming");
        setReasoningContent((s) => s + token);
      });

      const unlistenToken = await onLlmToken((token) => {
        if (cancelledRef.current) return;
        tokenBuffer += token;
        setChatState("streaming");
        setReasoningContent("");
        setStreamingContent((s) => s + token);
      });

      const unlistenComplete = await onLlmComplete(async () => {
        unlistenReasoning();
        unlistenToken();
        unlistenComplete();

        if (cancelledRef.current) return;

        if (!tokenBuffer) {
          // 流式为空 → 可能有 tool calls，切换非流式
          await sendNonStreaming(messages, toolRound);
          return;
        }

        const assistMsg = assistantMessage(tokenBuffer);
        appendMessage(assistMsg);
        setStreamingContent("");
        setChatState("idle");

        await processConversation([...historyRef.current]).catch(() => {});

        if (ttsEnabledRef.current && tokenBuffer) {
          speakText(tokenBuffer).catch(() => {});
        }
      });

      await sendMessageStream(messages).catch((err) => {
        unlistenReasoning();
        unlistenToken();
        unlistenComplete();
        console.error("[LLM Stream]", err);
        setChatState("idle");
      });
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [appendMessage]
  );

  const sendNonStreaming = useCallback(
    async (messages: ChatMessage[], toolRound: number) => {
      if (toolRound >= MAX_TOOL_ROUNDS) {
        appendMessage(assistantMessage("工具调用次数过多，已停止喵~"));
        setChatState("idle");
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
          setStreamingContent(response.content);
          setTimeout(() => setStreamingContent(""), 100);
          setChatState("idle");

          await processConversation([...historyRef.current]).catch(() => {});
          if (ttsEnabledRef.current) speakText(response.content).catch(() => {});
        } else {
          setChatState("idle");
        }
      } catch (err) {
        appendMessage(assistantMessage(`出错了：${err}`));
        setChatState("idle");
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [appendMessage]
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

  const cancel = useCallback(() => {
    cancelledRef.current = true;
    setChatState("idle");
    setStreamingContent("");
    setToolStatus(null);
  }, []);

  const clearHistory = useCallback(() => {
    setHistory([]);
    historyRef.current = [];
  }, []);

  // app 关闭时保存会话记忆
  useEffect(() => {
    const handleBeforeUnload = () => {
      endSession(historyRef.current).catch(() => {});
    };
    window.addEventListener("beforeunload", handleBeforeUnload);
    return () => window.removeEventListener("beforeunload", handleBeforeUnload);
  }, []);

  return { history, streamingContent, reasoningContent, chatState, toolStatus, send, cancel, clearHistory };
}
