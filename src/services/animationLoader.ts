import { convertFileSrc } from "@tauri-apps/api/core";
import { resourceDir, join } from "@tauri-apps/api/path";
import type { AnimationStateName } from "../types/animation";

const frameCache = new Map<AnimationStateName, HTMLImageElement[]>();

// 同步生成占位猫图，确保启动时立即可用
let placeholderImg: HTMLImageElement | null = null;

export function getPlaceholderSync(): HTMLImageElement {
  return getPlaceholder();
}

function getPlaceholder(): HTMLImageElement {
  if (placeholderImg) return placeholderImg;

  const img = new Image();
  img.src = "/animations/xiaohei_idle.gif";
  placeholderImg = img;
  return img;
}

async function loadImage(src: string): Promise<HTMLImageElement | null> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = src;
  });
}

async function loadResourceImage(fileName: string): Promise<HTMLImageElement | null> {
  try {
    const resDir = await resourceDir();
    const filePath = await join(resDir, "animations", fileName);
    const url = convertFileSrc(filePath);
    const img = await loadImage(url);
    if (img) return img;
  } catch {
    // 普通浏览器 / Vite preview 下没有 Tauri resourceDir
  }

  return loadImage(`/animations/${fileName}`);
}

export async function loadFrames(state: AnimationStateName): Promise<HTMLImageElement[]> {
  if (frameCache.has(state)) {
    return frameCache.get(state)!;
  }

  const frames: HTMLImageElement[] = [];

  if (state === "idle") {
    const gif = await loadResourceImage("xiaohei_idle.gif");
    if (gif) {
      frames.push(gif);
      frameCache.set(state, frames);
      return frames;
    }
  }

  for (let i = 0; i < 100; i++) {
    const fileName = `${state}_${String(i).padStart(3, "0")}.png`;
    const img = await loadResourceImage(fileName);
    if (!img) break;
    frames.push(img);
  }

  if (frames.length === 0) {
    frames.push(getPlaceholder());
  }

  frameCache.set(state, frames);
  return frames;
}
