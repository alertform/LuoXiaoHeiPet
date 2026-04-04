import { useRef, useState } from "react";
import type { ChatState } from "../../types/chat";
import styles from "./ChatInput.module.css";

interface ChatInputProps {
  chatState: ChatState;
  onSend: (text: string) => void;
  onCancel: () => void;
}

export function ChatInput({ chatState, onSend, onCancel }: ChatInputProps) {
  const [text, setText] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const isBusy = chatState !== "idle";

  const handleSend = () => {
    const trimmed = text.trim();
    if (!trimmed || isBusy) return;
    onSend(trimmed);
    setText("");
  };

  const placeholder =
    chatState === "waiting" ? "思考中..."
    : chatState === "streaming" ? "回复中..."
    : chatState === "toolCalling" ? "执行工具..."
    : "和小黑说点什么...";

  return (
    <div className={styles.inputRow}>
      <input
        ref={inputRef}
        className={styles.input}
        value={text}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            handleSend();
          }
        }}
        placeholder={placeholder}
        disabled={isBusy}
        autoFocus
      />
      {isBusy ? (
        <button className={`${styles.btn} ${styles.cancelBtn}`} onClick={onCancel}>
          ✕
        </button>
      ) : (
        <button
          className={`${styles.btn} ${styles.sendBtn}`}
          onClick={handleSend}
          disabled={!text.trim()}
        >
          ↑
        </button>
      )}
    </div>
  );
}
