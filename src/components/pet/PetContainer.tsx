import { getCurrentWebviewWindow } from "@tauri-apps/api/webviewWindow";
import { LogicalPosition, LogicalSize } from "@tauri-apps/api/dpi";
import { currentMonitor } from "@tauri-apps/api/window";
import { useCallback, useEffect, useRef, useState } from "react";
import { ChatBubble } from "../chat/ChatBubble";
import { PetCanvas } from "./PetCanvas";
import { useAnimationEngine } from "../../hooks/useAnimationEngine";
import { useChatManager, type ChatNoticeReason } from "../../hooks/useChatManager";
import { useDrag } from "../../hooks/useDrag";
import type { AppSettings } from "../../types/config";
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
  settings: AppSettings;
}

export function PetContainer({ settings }: PetContainerProps) {
  const [chatOpen, setChatOpen] = useState(false);
  const [chatPlacement, setChatPlacement] = useState<ChatPlacement>("above");
  const [petLine, setPetLine] = useState<string | null>(null);
  const petPositionBeforeChatRef = useRef<LogicalPoint | null>(null);
  const petLineTimerRef = useRef<number | null>(null);
  const idleTimerRef = useRef<number | null>(null);
  const lastPetLineAtRef = useRef(0);
  const clickBurstRef = useRef({ startedAt: 0, count: 0 });
  const animation = useAnimationEngine();
  const interactionLevel = settings.interaction_level ?? "low";
  const interactionsEnabled = interactionLevel !== "off";

  const showPetLine = useCallback(
    (line: string, duration = 3600, force = false) => {
      if (!interactionsEnabled || chatOpen) return false;
      const now = Date.now();
      if (!force && now - lastPetLineAtRef.current < 1400) return false;

      lastPetLineAtRef.current = now;
      setPetLine(line);
      if (petLineTimerRef.current) {
        window.clearTimeout(petLineTimerRef.current);
      }
      petLineTimerRef.current = window.setTimeout(() => {
        setPetLine(null);
        petLineTimerRef.current = null;
      }, duration);
      return true;
    },
    [chatOpen, interactionsEnabled]
  );

  const handleChatNotice = useCallback(
    (reason: ChatNoticeReason) => {
      showPetLine(pickLine(NOTICE_LINES[reason]), 3600, true);
    },
    [showPetLine]
  );

  const chat = useChatManager(settings.tts_enabled, handleChatNotice);

  useEffect(() => {
    return () => {
      if (petLineTimerRef.current) window.clearTimeout(petLineTimerRef.current);
      if (idleTimerRef.current) window.clearTimeout(idleTimerRef.current);
    };
  }, []);

  useEffect(() => {
    if (!interactionsEnabled) return;
    const today = new Date().toISOString().slice(0, 10);
    const storageKey = "luoxiaohei.lastStartupGreetingDate";
    if (localStorage.getItem(storageKey) === today) return;

    const timer = window.setTimeout(() => {
      if (showPetLine(pickLine(STARTUP_LINES), 4200, true)) {
        localStorage.setItem(storageKey, today);
      }
    }, 1400);

    return () => window.clearTimeout(timer);
  }, [interactionsEnabled, showPetLine]);

  useEffect(() => {
    if (!interactionsEnabled || interactionLevel === "low") return;

    const hour = new Date().getHours();
    const care = timeCareLine(hour);
    if (!care) return;

    const today = new Date().toISOString().slice(0, 10);
    const storageKey = `luoxiaohei.lastTimeCare.${care.key}`;
    if (localStorage.getItem(storageKey) === today) return;

    const timer = window.setTimeout(() => {
      if (showPetLine(care.line, 4600)) {
        localStorage.setItem(storageKey, today);
      }
    }, 5200);

    return () => window.clearTimeout(timer);
  }, [interactionLevel, interactionsEnabled, showPetLine]);

  useEffect(() => {
    if (!interactionsEnabled || interactionLevel === "low") return;

    let cancelled = false;
    const schedule = () => {
      const delay = idleDelay(interactionLevel);
      idleTimerRef.current = window.setTimeout(() => {
        if (cancelled) return;
        showPetLine(pickLine(IDLE_LINES), 4600);
        schedule();
      }, delay);
    };

    schedule();
    return () => {
      cancelled = true;
      if (idleTimerRef.current) {
        window.clearTimeout(idleTimerRef.current);
        idleTimerRef.current = null;
      }
    };
  }, [interactionLevel, interactionsEnabled, showPetLine]);

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

  const handleSingleClick = useCallback(() => {
    animation.handleEvent("click");
    const now = Date.now();
    if (now - clickBurstRef.current.startedAt > 4500) {
      clickBurstRef.current = { startedAt: now, count: 0 };
    }
    clickBurstRef.current.count += 1;
    const lines = clickBurstRef.current.count >= 4 ? CLICK_BURST_LINES : CLICK_LINES;
    showPetLine(pickLine(lines), 2800);
  }, [animation, showPetLine]);

  const drag = useDrag(
    () => {
      animation.handleEvent("startDrag");
      showPetLine(pickLine(DRAG_START_LINES), 2400, true);
    },
    () => {
      animation.handleEvent("endDrag");
      showPetLine(pickLine(DRAG_END_LINES), 2600, true);
    },
    handleSingleClick,
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
        {petLine && !chatOpen && <div className={styles.petLine}>{petLine}</div>}
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

const STARTUP_LINES = ["你来了。", "今天也在这里。", "我醒了。", "嗯，我在。"];
const CLICK_LINES = ["嗯？", "怎么了？", "我在听。", "别突然戳我。"];
const CLICK_BURST_LINES = ["别戳了。", "我知道你在。", "有事就说。"];
const DRAG_START_LINES = ["去哪？", "要搬家吗？", "慢一点。"];
const DRAG_END_LINES = ["这里也行。", "放这？", "嗯，先待着。"];
const IDLE_LINES = ["有点安静。", "你还在忙吗？", "我看一会儿。", "要休息一下吗？"];
const NOTICE_LINES: Record<ChatNoticeReason, string[]> = {
  missingConfig: ["我还不知道该去哪说话。", "先把钥匙给我。", "API Key 好像还没填。"],
  networkError: ["没连上。", "外面好像断了一下。", "信号不太对。"],
  serverError: ["那边没有回应。", "模型那边出问题了。", "这次没说成。"],
  emptyResponse: ["它什么都没说。", "空的。再试一次？", "我没听到回答。"],
  toolLimit: ["工具绕太久了。", "先停一下。", "这样会转圈。"],
};

function pickLine(lines: string[]): string {
  return lines[Math.floor(Math.random() * lines.length)] ?? lines[0] ?? "";
}

function idleDelay(level: AppSettings["interaction_level"]): number {
  if (level === "active") return randomBetween(10, 18) * 60 * 1000;
  return randomBetween(28, 48) * 60 * 1000;
}

function randomBetween(min: number, max: number): number {
  return min + Math.random() * (max - min);
}

function timeCareLine(hour: number): { key: string; line: string } | null {
  if (hour >= 0 && hour < 5) return { key: "lateNight", line: "还没睡？" };
  if (hour >= 6 && hour < 10) return { key: "morning", line: "早。今天也开始了。" };
  if (hour >= 12 && hour < 14) return { key: "noon", line: "要不要先吃饭？" };
  if (hour >= 22) return { key: "night", line: "今天差不多了吧。" };
  return null;
}
