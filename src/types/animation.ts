export type AnimationStateName =
  | "idle"
  | "sleep"
  | "walk"
  | "happy"
  | "stretch"
  | "lookAround"
  | "talking"
  | "thinking"
  | "drag"
  | "fall";

export interface AnimationStateConfig {
  isLooping: boolean;
  frameDuration: number; // seconds
  defaultTransition: AnimationStateName | null;
}

export const ANIMATION_CONFIGS: Record<AnimationStateName, AnimationStateConfig> = {
  idle:        { isLooping: true,  frameDuration: 0.15, defaultTransition: null },
  sleep:       { isLooping: true,  frameDuration: 0.25, defaultTransition: null },
  walk:        { isLooping: true,  frameDuration: 0.10, defaultTransition: null },
  talking:     { isLooping: true,  frameDuration: 0.10, defaultTransition: null },
  thinking:    { isLooping: true,  frameDuration: 0.20, defaultTransition: null },
  happy:       { isLooping: false, frameDuration: 0.08, defaultTransition: "idle" },
  stretch:     { isLooping: false, frameDuration: 0.12, defaultTransition: "idle" },
  lookAround:  { isLooping: false, frameDuration: 0.12, defaultTransition: "idle" },
  drag:        { isLooping: false, frameDuration: 0.10, defaultTransition: "fall" },
  fall:        { isLooping: false, frameDuration: 0.06, defaultTransition: "idle" },
};

export type AnimationEvent =
  | "click"
  | "doubleClick"
  | "startDrag"
  | "endDrag"
  | "startChat"
  | "endChat"
  | "llmThinking"
  | "llmResponded"
  | "timer";
