import { useEffect, useRef, useState } from "react";
import type { ChatMessage, ChatState } from "../../types/chat";
import styles from "./ChatInput.module.css";

interface ChatInputProps {
  chatState: ChatState;
  queuedMessages: ChatMessage[];
  onSend: (text: string) => void;
  onUpdateQueuedMessage: (index: number, text: string) => void;
  onRemoveQueuedMessage: (index: number) => void;
  onCancel: () => void;
}

export function ChatInput({
  chatState,
  queuedMessages,
  onSend,
  onUpdateQueuedMessage,
  onRemoveQueuedMessage,
  onCancel,
}: ChatInputProps) {
  const [text, setText] = useState("");
  const [editingQueueIndex, setEditingQueueIndex] = useState<number | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const isBusy = chatState !== "idle";
  const isEditingQueued = editingQueueIndex !== null;

  useEffect(() => {
    if (editingQueueIndex === null) return;
    if (!queuedMessages[editingQueueIndex]) {
      setEditingQueueIndex(null);
      setText("");
    }
  }, [editingQueueIndex, queuedMessages]);

  const handleSend = () => {
    const trimmed = text.trim();
    if (!trimmed) return;

    if (editingQueueIndex !== null) {
      onUpdateQueuedMessage(editingQueueIndex, trimmed);
      setEditingQueueIndex(null);
      setText("");
      return;
    }

    onSend(trimmed);
    setText("");
  };

  const selectQueuedMessage = (direction: "up" | "down") => {
    if (queuedMessages.length === 0) return;
    const currentIndex = editingQueueIndex ?? queuedMessages.length;
    const nextIndex =
      direction === "up"
        ? (currentIndex + queuedMessages.length - 1) % queuedMessages.length
        : (currentIndex + 1) % queuedMessages.length;

    setEditingQueueIndex(nextIndex);
    setText(queuedMessages[nextIndex].content);
    requestAnimationFrame(() => inputRef.current?.focus());
  };

  const cancelQueuedEdit = () => {
    setEditingQueueIndex(null);
    setText("");
    requestAnimationFrame(() => inputRef.current?.focus());
  };

  const placeholder =
    isEditingQueued ? "正在编辑待发送消息..."
    : chatState === "waiting" ? "小黑思考中，可继续输入..."
    : chatState === "streaming" ? "小黑回复中，可继续输入..."
    : chatState === "toolCalling" ? "工具执行中，可继续输入..."
    : "和小黑说点什么...";

  return (
    <div className={styles.inputArea}>
      <div className={styles.inputRow}>
        <input
          ref={inputRef}
          className={`${styles.input} ${isEditingQueued ? styles.editing : ""}`}
          value={text}
          onChange={(e) => {
            setText(e.target.value);
          }}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              handleSend();
            } else if (e.key === "ArrowUp" && !e.shiftKey && (isEditingQueued || !text.trim())) {
              e.preventDefault();
              selectQueuedMessage("up");
            } else if (e.key === "ArrowDown" && !e.shiftKey && isEditingQueued) {
              e.preventDefault();
              selectQueuedMessage("down");
            } else if (e.key === "Escape" && isEditingQueued) {
              e.preventDefault();
              cancelQueuedEdit();
            }
          }}
          placeholder={placeholder}
          autoFocus
        />
        {isBusy && (
          <button className={`${styles.btn} ${styles.cancelBtn}`} onClick={onCancel} title="取消当前回复和队列">
            ✕
          </button>
        )}
        {isEditingQueued && (
          <button className={`${styles.btn} ${styles.removeBtn}`} onClick={() => {
            onRemoveQueuedMessage(editingQueueIndex);
            cancelQueuedEdit();
          }} title="移除这条待发送消息">
            −
          </button>
        )}
        <button
          className={`${styles.btn} ${styles.sendBtn}`}
          onClick={handleSend}
          disabled={!text.trim()}
          title={isEditingQueued ? "保存修改" : isBusy ? "加入发送队列" : "发送"}
        >
          {isEditingQueued ? "✓" : "↑"}
        </button>
      </div>
    </div>
  );
}
