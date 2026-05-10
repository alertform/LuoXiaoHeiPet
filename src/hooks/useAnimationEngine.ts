import { useCallback, useEffect, useRef, useState } from "react";
import { loadFrames, getPlaceholderSync } from "../services/animationLoader";
import { ANIMATION_CONFIGS, type AnimationEvent, type AnimationStateName } from "../types/animation";

export interface AnimationEngine {
  currentState: AnimationStateName;
  currentFrame: HTMLImageElement | null;
  play: (state: AnimationStateName, then?: AnimationStateName) => void;
  handleEvent: (event: AnimationEvent) => void;
  stop: () => void;
}

export function useAnimationEngine(): AnimationEngine {
  const [currentState, setCurrentState] = useState<AnimationStateName>("idle");
  const [currentFrame, setCurrentFrame] = useState<HTMLImageElement | null>(() => getPlaceholderSync());

  const framesRef = useRef<HTMLImageElement[]>([]);
  const frameIndexRef = useRef(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const nextStateRef = useRef<AnimationStateName | null>(null);
  const currentStateRef = useRef<AnimationStateName>("idle");
  const autoBehaviorRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const playRequestRef = useRef(0);

  const stopTimer = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const stopAutoBehavior = useCallback(() => {
    if (autoBehaviorRef.current) {
      clearInterval(autoBehaviorRef.current);
      autoBehaviorRef.current = null;
    }
  }, []);

  const startAutoBehavior = useCallback(() => {
    stopAutoBehavior();
    autoBehaviorRef.current = setInterval(() => {
      if (Math.random() < 0.4) {
        const states: AnimationStateName[] = ["stretch", "lookAround", "walk"];
        const next = states[Math.floor(Math.random() * states.length)];
        playInternal(next, "idle");
      }
    }, 15_000);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [stopAutoBehavior]);

  const playInternal = useCallback(
    async (state: AnimationStateName, thenState?: AnimationStateName) => {
      const config = ANIMATION_CONFIGS[state];

      // 循环状态不重复播放
      if (currentStateRef.current === state && config.isLooping) return;

      const requestId = playRequestRef.current + 1;
      playRequestRef.current = requestId;
      currentStateRef.current = state;
      setCurrentState(state);
      frameIndexRef.current = 0;
      nextStateRef.current = thenState ?? config.defaultTransition;

      stopTimer();
      if (state !== "idle") {
        stopAutoBehavior();
      }

      const frames = await loadFrames(state);
      if (playRequestRef.current !== requestId || currentStateRef.current !== state) {
        return;
      }
      framesRef.current = frames;

      if (frames.length === 0) return;
      setCurrentFrame(frames[0]);

      timerRef.current = setInterval(() => {
        frameIndexRef.current += 1;

        if (frameIndexRef.current >= framesRef.current.length) {
          if (ANIMATION_CONFIGS[currentStateRef.current].isLooping) {
            frameIndexRef.current = 0;
          } else {
            stopTimer();
            const next = nextStateRef.current ?? "idle";
            playInternal(next);
            return;
          }
        }

        setCurrentFrame(framesRef.current[frameIndexRef.current]);
      }, config.frameDuration * 1000);

      if (state === "idle") {
        startAutoBehavior();
      }
    },
    [startAutoBehavior, stopAutoBehavior, stopTimer]
  );

  const handleEvent = useCallback(
    (event: AnimationEvent) => {
      switch (event) {
        case "click": {
          const reactions: AnimationStateName[] = ["happy", "stretch", "lookAround"];
          playInternal(reactions[Math.floor(Math.random() * reactions.length)], "idle");
          break;
        }
        case "startDrag":
          playInternal("drag");
          break;
        case "endDrag":
          playInternal("fall", "idle");
          break;
        case "startChat":
          playInternal("talking");
          break;
        case "endChat":
          playInternal("idle");
          break;
        case "llmThinking":
          playInternal("thinking");
          break;
        case "llmResponded":
          playInternal("talking");
          break;
        case "timer": {
          const behaviors: AnimationStateName[] = ["stretch", "lookAround", "walk"];
          playInternal(behaviors[Math.floor(Math.random() * behaviors.length)], "idle");
          break;
        }
        case "doubleClick":
          break;
      }
    },
    [playInternal]
  );

  const stop = useCallback(() => {
    stopTimer();
    stopAutoBehavior();
  }, [stopTimer, stopAutoBehavior]);

  // 启动初始动画
  useEffect(() => {
    playInternal("idle");
    return () => {
      stopTimer();
      stopAutoBehavior();
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return {
    currentState,
    currentFrame,
    play: playInternal,
    handleEvent,
    stop,
  };
}
