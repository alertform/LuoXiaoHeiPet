import { useEffect, useRef } from "react";
import type { ChatMessage } from "../../types/chat";
import styles from "./MessageList.module.css";

interface MessageListProps {
  history: ChatMessage[];
  streamingContent: string;
  toolStatus: string | null;
}

export function MessageList({ history, streamingContent, toolStatus }: MessageListProps) {
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [history, streamingContent, toolStatus]);

  const displayMessages = history.filter(
    (m) => m.role === "user" || m.role === "assistant"
  );

  return (
    <div className={styles.list}>
      {displayMessages.length === 0 && (
        <p className={styles.empty}>双击呼出小黑，开始聊天喵~</p>
      )}

      {displayMessages.map((msg, i) => (
        <div
          key={i}
          className={`${styles.message} ${msg.role === "user" ? styles.user : styles.assistant}`}
        >
          <div className={styles.bubble}>{msg.content}</div>
        </div>
      ))}

      {streamingContent && (
        <div className={`${styles.message} ${styles.assistant}`}>
          <div className={`${styles.bubble} ${styles.streaming}`}>
            {streamingContent}
            <span className={styles.cursor} />
          </div>
        </div>
      )}

      {toolStatus && (
        <div className={`${styles.message} ${styles.system}`}>
          <div className={styles.toolStatus}>⚙️ {toolStatus}</div>
        </div>
      )}

      <div ref={bottomRef} />
    </div>
  );
}
