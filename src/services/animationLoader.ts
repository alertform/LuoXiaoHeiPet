import { convertFileSrc } from "@tauri-apps/api/core";
import { resourceDir, join } from "@tauri-apps/api/path";
import type { AnimationStateName } from "../types/animation";

const frameCache = new Map<AnimationStateName, HTMLImageElement[]>();

async function loadImage(src: string): Promise<HTMLImageElement | null> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = src;
  });
}

export async function loadFrames(state: AnimationStateName): Promise<HTMLImageElement[]> {
  if (frameCache.has(state)) {
    return frameCache.get(state)!;
  }

  const frames: HTMLImageElement[] = [];
  const resDir = await resourceDir();

  for (let i = 0; i < 100; i++) {
    const fileName = `${state}_${String(i).padStart(3, "0")}.png`;
    const filePath = await join(resDir, "animations", fileName);
    const url = convertFileSrc(filePath);
    const img = await loadImage(url);
    if (!img) break;
    frames.push(img);
  }

  if (frames.length === 0) {
    // 加载占位帧（纯色方块）
    const placeholder = await createPlaceholder();
    frames.push(placeholder);
  }

  frameCache.set(state, frames);
  return frames;
}

function createPlaceholder(): Promise<HTMLImageElement> {
  const canvas = document.createElement("canvas");
  canvas.width = 128;
  canvas.height = 128;
  const ctx = canvas.getContext("2d")!;

  // 绘制简单小黑猫剪影
  ctx.fillStyle = "#1a1a1a";
  // 身体
  ctx.beginPath();
  ctx.ellipse(64, 55, 34, 30, 0, 0, Math.PI * 2);
  ctx.fill();
  // 头
  ctx.beginPath();
  ctx.arc(64, 30, 26, 0, Math.PI * 2);
  ctx.fill();
  // 左耳
  ctx.beginPath();
  ctx.moveTo(45, 14);
  ctx.lineTo(35, -2);
  ctx.lineTo(58, 10);
  ctx.fill();
  // 右耳
  ctx.beginPath();
  ctx.moveTo(83, 14);
  ctx.lineTo(93, -2);
  ctx.lineTo(70, 10);
  ctx.fill();
  // 眼睛
  ctx.fillStyle = "#4ade80";
  ctx.beginPath();
  ctx.ellipse(55, 30, 6, 7, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.ellipse(73, 30, 6, 7, 0, 0, Math.PI * 2);
  ctx.fill();

  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.src = canvas.toDataURL();
  });
}
