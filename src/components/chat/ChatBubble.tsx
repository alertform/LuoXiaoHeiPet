import { useEffect, useState } from "react";
import type { ChatMessage, ChatState } from "../../types/chat";
import { ChatInput } from "./ChatInput";
import { MessageList } from "./MessageList";
import styles from "./ChatBubble.module.css";

interface ChatBubbleProps {
  history: ChatMessage[];
  streamingContent: string;
  reasoningContent: string;
  chatState: ChatState;
  toolStatus: string | null;
  queuedMessages: ChatMessage[];
  onSend: (text: string) => void;
  onUpdateQueuedMessage: (index: number, text: string) => void;
  onRemoveQueuedMessage: (index: number) => void;
  onCancel: () => void;
  onClose: () => void;
}

export function ChatBubble({
  history,
  streamingContent,
  reasoningContent,
  chatState,
  toolStatus,
  queuedMessages,
  onSend,
  onUpdateQueuedMessage,
  onRemoveQueuedMessage,
  onCancel,
  onClose,
}: ChatBubbleProps) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    requestAnimationFrame(() => setVisible(true));
  }, []);

  const handleClose = () => {
    setVisible(false);
    setTimeout(onClose, 200);
  };

  return (
    <div
      className={`${styles.bubble} ${visible ? styles.visible : ""}`}
      onMouseDown={(e) => e.stopPropagation()}
    >
      <div className={styles.header}>
        <span className={styles.title}>罗小黑</span>
        <button className={styles.closeBtn} onClick={handleClose}>✕</button>
      </div>

      <MessageList
        history={history}
        streamingContent={streamingContent}
        reasoningContent={reasoningContent}
        toolStatus={toolStatus}
        queuedMessages={queuedMessages}
      />

      <ChatInput
        chatState={chatState}
        queuedMessages={queuedMessages}
        onSend={onSend}
        onUpdateQueuedMessage={onUpdateQueuedMessage}
        onRemoveQueuedMessage={onRemoveQueuedMessage}
        onCancel={onCancel}
      />

      <div className={styles.arrow} />
    </div>
  );
}
