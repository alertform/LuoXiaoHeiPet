import { useEffect, useRef, useState } from "react";
import type { ChatMessage } from "../../types/chat";
import styles from "./MessageList.module.css";

function ReasoningBlock({ content }: { content: string }) {
  const [collapsed, setCollapsed] = useState(true);

  return (
    <div className={styles.reasoningBlock}>
      <button
        className={styles.reasoningToggle}
        onClick={() => setCollapsed((c) => !c)}
      >
        <span className={`${styles.arrow} ${collapsed ? "" : styles.arrowOpen}`}>▶</span>
        思考过程
      </button>
      {!collapsed && (
        <div className={styles.reasoningBody}>{content}</div>
      )}
    </div>
  );
}

interface MessageListProps {
  history: ChatMessage[];
  streamingContent: string;
  reasoningContent: string;
  toolStatus: string | null;
  queuedMessages: ChatMessage[];
}

export function MessageList({
  history,
  streamingContent,
  reasoningContent,
  toolStatus,
  queuedMessages,
}: MessageListProps) {
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [history, streamingContent, reasoningContent, toolStatus, queuedMessages]);

  const displayMessages = history.filter(
    (m) => m.role === "user" || m.role === "assistant"
  );

  return (
    <div className={styles.list}>
      {displayMessages.length === 0 && !reasoningContent && !streamingContent && queuedMessages.length === 0 && (
        <p className={styles.empty}>双击呼出小黑，开始聊天喵~</p>
      )}

      {displayMessages.map((msg, i) => (
        <div key={i}>
          {msg.role === "assistant" && msg.reasoning && (
            <div className={`${styles.message} ${styles.assistant}`}>
              <ReasoningBlock content={msg.reasoning} />
            </div>
          )}
          <div
            className={`${styles.message} ${msg.role === "user" ? styles.user : styles.assistant}`}
          >
            <div className={styles.bubble}>{msg.content}</div>
          </div>
        </div>
      ))}

      {reasoningContent && (
        <div className={`${styles.message} ${styles.assistant}`}>
          <div className={styles.reasoningStreaming}>
            <span className={styles.reasoningLabel}>思考中...</span>
            {reasoningContent}
          </div>
        </div>
      )}

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

      {queuedMessages.map((msg, i) => (
        <div key={`${msg.timestamp}-${i}`} className={`${styles.message} ${styles.user} ${styles.queued}`}>
          <div className={styles.bubble}>{msg.content}</div>
        </div>
      ))}

      <div ref={bottomRef} />
    </div>
  );
}
