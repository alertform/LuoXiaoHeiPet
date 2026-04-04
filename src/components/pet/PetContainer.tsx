import { getCurrentWebviewWindow } from "@tauri-apps/api/webviewWindow";
import { PhysicalPosition, PhysicalSize } from "@tauri-apps/api/dpi";
import { useCallback, useEffect, useState } from "react";
import { ChatBubble } from "../chat/ChatBubble";
import { PetCanvas } from "./PetCanvas";
import { useAnimationEngine } from "../../hooks/useAnimationEngine";
import { useChatManager } from "../../hooks/useChatManager";
import { useDrag } from "../../hooks/useDrag";
import styles from "./PetContainer.module.css";

const PET_SIZE = 128;
const CHAT_HEIGHT = 400;
const CHAT_WIDTH = 280;

interface PetContainerProps {
  ttsEnabled: boolean;
}

export function PetContainer({ ttsEnabled }: PetContainerProps) {
  const [chatOpen, setChatOpen] = useState(false);
  const animation = useAnimationEngine();
  const chat = useChatManager(ttsEnabled);

  const openChat = useCallback(async () => {
    if (chatOpen) return;
    setChatOpen(true);
    animation.handleEvent("startChat");
    const win = getCurrentWebviewWindow();
    const pos = await win.outerPosition();
    await win.setSize(new PhysicalSize(CHAT_WIDTH, CHAT_HEIGHT + PET_SIZE));
    await win.setPosition(new PhysicalPosition(
      pos.x + (PET_SIZE - CHAT_WIDTH) / 2,
      pos.y - CHAT_HEIGHT,
    ));
  }, [chatOpen, animation]);

  const closeChat = useCallback(async () => {
    setChatOpen(false);
    animation.handleEvent("endChat");
    chat.cancel();
    const win = getCurrentWebviewWindow();
    const pos = await win.outerPosition();
    await win.setSize(new PhysicalSize(PET_SIZE, PET_SIZE));
    await win.setPosition(new PhysicalPosition(
      pos.x + (CHAT_WIDTH - PET_SIZE) / 2,
      pos.y + CHAT_HEIGHT,
    ));
  }, [animation, chat]);

  // 聊天状态 → 动画
  useEffect(() => {
    if (chat.chatState === "waiting" || chat.chatState === "toolCalling") {
      animation.handleEvent("llmThinking");
    } else if (chat.chatState === "streaming") {
      animation.handleEvent("llmResponded");
    } else if (chat.chatState === "idle" && chatOpen) {
      animation.play("talking");
    }
  }, [chat.chatState, chatOpen, animation]);

  const drag = useDrag(
    () => animation.handleEvent("startDrag"),
    () => animation.handleEvent("endDrag"),
    () => animation.handleEvent("click"),
    () => {
      if (chatOpen) closeChat();
      else openChat();
    }
  );

  return (
    <div className={styles.container}>
      {chatOpen && (
        <ChatBubble
          history={chat.history}
          streamingContent={chat.streamingContent}
          chatState={chat.chatState}
          toolStatus={chat.toolStatus}
          onSend={chat.send}
          onCancel={chat.cancel}
          onClose={closeChat}
        />
      )}

      <div
        className={styles.petWrapper}
        onMouseDown={drag.onMouseDown}
        onMouseMove={drag.onMouseMove}
        onMouseUp={drag.onMouseUp}
        onContextMenu={(e) => e.preventDefault()}
      >
        <PetCanvas frame={animation.currentFrame} size={PET_SIZE} />
      </div>
    </div>
  );
}
