interface PetCanvasProps {
  frame: HTMLImageElement | null;
  size?: number;
}

export function PetCanvas({ frame, size = 128 }: PetCanvasProps) {
  if (!frame?.src) {
    return (
      <div
        style={{
          width: size,
          height: size,
        }}
      />
    );
  }

  return (
    <img
      src={frame.src}
      width={size}
      height={size}
      draggable={false}
      style={{
        display: "block",
        width: size,
        height: size,
        objectFit: "contain",
        userSelect: "none",
        pointerEvents: "none",
      }}
    />
  );
}
