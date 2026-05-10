import { getCurrentWebviewWindow } from "@tauri-apps/api/webviewWindow";
import { LogicalPosition, LogicalSize } from "@tauri-apps/api/dpi";
import { currentMonitor } from "@tauri-apps/api/window";
import { useCallback, useEffect, useRef, useState } from "react";
import { ChatBubble } from "../chat/ChatBubble";
import { PetCanvas } from "./PetCanvas";
import { useAnimationEngine } from "../../hooks/useAnimationEngine";
import { useChatManager } from "../../hooks/useChatManager";
import { useDrag } from "../../hooks/useDrag";
import styles from "./PetContainer.module.css";

const PET_SIZE = 128;
const CHAT_HEIGHT = 360;
const CHAT_WIDTH = 280;
const SCREEN_MARGIN = 8;

type ChatPlacement = "above" | "below";

interface LogicalPoint {
  x: number;
  y: number;
}

interface LogicalRect extends LogicalPoint {
  width: number;
  height: number;
}

interface PetContainerProps {
  ttsEnabled: boolean;
}

export function PetContainer({ ttsEnabled }: PetContainerProps) {
  const [chatOpen, setChatOpen] = useState(false);
  const [chatPlacement, setChatPlacement] = useState<ChatPlacement>("above");
  const petPositionBeforeChatRef = useRef<LogicalPoint | null>(null);
  const animation = useAnimationEngine();
  const chat = useChatManager(ttsEnabled);

  const openChat = useCallback(async () => {
    if (chatOpen) return;
    const win = getCurrentWebviewWindow();
    const factor = await win.scaleFactor();
    const pos = await win.outerPosition();
    // outerPosition returns physical pixels, convert to logical
    const lx = pos.x / factor;
    const ly = pos.y / factor;
    petPositionBeforeChatRef.current = { x: lx, y: ly };

    const workArea = await getLogicalWorkArea(factor);
    const placement = chooseChatPlacement(ly, workArea);
    const targetX = clamp(
      lx + (PET_SIZE - CHAT_WIDTH) / 2,
      workArea.x + SCREEN_MARGIN,
      workArea.x + workArea.width - CHAT_WIDTH - SCREEN_MARGIN,
    );
    const targetY =
      placement === "above"
        ? clamp(
            ly - CHAT_HEIGHT,
            workArea.y + SCREEN_MARGIN,
            workArea.y + workArea.height - CHAT_HEIGHT - PET_SIZE - SCREEN_MARGIN,
          )
        : clamp(
            ly,
            workArea.y + SCREEN_MARGIN,
            workArea.y + workArea.height - CHAT_HEIGHT - PET_SIZE - SCREEN_MARGIN,
          );

    setChatPlacement(placement);
    setChatOpen(true);
    animation.handleEvent("startChat");
    await win.setSize(new LogicalSize(CHAT_WIDTH, CHAT_HEIGHT + PET_SIZE));
    await win.setPosition(new LogicalPosition(targetX, targetY));
  }, [chatOpen, animation]);

  const closeChat = useCallback(async () => {
    setChatOpen(false);
    animation.handleEvent("endChat");
    chat.cancel();
    const win = getCurrentWebviewWindow();
    const factor = await win.scaleFactor();
    const pos = await win.outerPosition();
    const lx = pos.x / factor;
    const ly = pos.y / factor;
    const fallbackX = lx + (CHAT_WIDTH - PET_SIZE) / 2;
    const fallbackY = chatPlacement === "above" ? ly + CHAT_HEIGHT : ly;
    const target = petPositionBeforeChatRef.current ?? { x: fallbackX, y: fallbackY };
    petPositionBeforeChatRef.current = null;
    const workArea = await getLogicalWorkArea(factor);
    const targetX = clamp(
      target.x,
      workArea.x + SCREEN_MARGIN,
      workArea.x + workArea.width - PET_SIZE - SCREEN_MARGIN,
    );
    const targetY = clamp(
      target.y,
      workArea.y + SCREEN_MARGIN,
      workArea.y + workArea.height - PET_SIZE - SCREEN_MARGIN,
    );

    await win.setSize(new LogicalSize(PET_SIZE, PET_SIZE));
    await win.setPosition(new LogicalPosition(targetX, targetY));
  }, [animation, chat, chatPlacement]);

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
    <div className={`${styles.container} ${chatPlacement === "below" ? styles.below : ""}`}>
      {chatOpen && (
        <div className={styles.chatLayer} onMouseDown={closeChat}>
          <ChatBubble
            history={chat.history}
            streamingContent={chat.streamingContent}
            reasoningContent={chat.reasoningContent}
            chatState={chat.chatState}
            toolStatus={chat.toolStatus}
            queuedMessages={chat.queuedMessages}
            onSend={chat.send}
            onUpdateQueuedMessage={chat.updateQueuedMessage}
            onRemoveQueuedMessage={chat.removeQueuedMessage}
            onCancel={chat.cancel}
            onClose={closeChat}
          />
        </div>
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

async function getLogicalWorkArea(fallbackScaleFactor: number): Promise<LogicalRect> {
  const monitor = await currentMonitor().catch(() => null);
  if (!monitor) {
    return {
      x: 0,
      y: 0,
      width: window.screen.availWidth,
      height: window.screen.availHeight,
    };
  }

  const scaleFactor = monitor.scaleFactor || fallbackScaleFactor || 1;
  return {
    x: monitor.workArea.position.x / scaleFactor,
    y: monitor.workArea.position.y / scaleFactor,
    width: monitor.workArea.size.width / scaleFactor,
    height: monitor.workArea.size.height / scaleFactor,
  };
}

function chooseChatPlacement(petY: number, workArea: LogicalRect): ChatPlacement {
  const spaceAbove = petY - workArea.y;
  const spaceBelow = workArea.y + workArea.height - petY - PET_SIZE;
  if (spaceAbove >= CHAT_HEIGHT) return "above";
  if (spaceBelow >= CHAT_HEIGHT) return "below";
  return spaceBelow > spaceAbove ? "below" : "above";
}

function clamp(value: number, min: number, max: number): number {
  if (max < min) return min;
  return Math.min(Math.max(value, min), max);
}
