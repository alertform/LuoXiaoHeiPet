import { useEffect, useState } from "react";
import type { ChatMessage, ChatState } from "../../types/chat";
import { ChatInput } from "./ChatInput";
import { MessageList } from "./MessageList";
import styles from "./ChatBubble.module.css";

interface ChatBubbleProps {
  history: ChatMessage[];
  streamingContent: string;
  chatState: ChatState;
  toolStatus: string | null;
  onSend: (text: string) => void;
  onCancel: () => void;
  onClose: () => void;
}

export function ChatBubble({
  history,
  streamingContent,
  chatState,
  toolStatus,
  onSend,
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
    <div className={`${styles.bubble} ${visible ? styles.visible : ""}`}>
      <div className={styles.header}>
        <span className={styles.title}>罗小黑</span>
        <button className={styles.closeBtn} onClick={handleClose}>✕</button>
      </div>

      <MessageList
        history={history}
        streamingContent={streamingContent}
        toolStatus={toolStatus}
      />

      <ChatInput
        chatState={chatState}
        onSend={onSend}
        onCancel={onCancel}
      />

      <div className={styles.arrow} />
    </div>
  );
}
