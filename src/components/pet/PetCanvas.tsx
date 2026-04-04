import { useEffect, useRef } from "react";

interface PetCanvasProps {
  frame: HTMLImageElement | null;
  size?: number;
}

export function PetCanvas({ frame, size = 128 }: PetCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.clearRect(0, 0, size, size);

    if (!frame) return;

    // aspect-fit 居中绘制
    const scale = Math.min(size / frame.naturalWidth, size / frame.naturalHeight);
    const w = frame.naturalWidth * scale;
    const h = frame.naturalHeight * scale;
    const x = (size - w) / 2;
    const y = (size - h) / 2;

    ctx.drawImage(frame, x, y, w, h);
  }, [frame, size]);

  return (
    <canvas
      ref={canvasRef}
      width={size}
      height={size}
      style={{ display: "block", imageRendering: "pixelated" }}
    />
  );
}
