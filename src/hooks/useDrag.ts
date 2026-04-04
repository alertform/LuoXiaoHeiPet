import { getCurrentWebviewWindow } from "@tauri-apps/api/webviewWindow";
import { useCallback, useRef } from "react";

const DRAG_THRESHOLD = 3;

export function useDrag(
  onDragStart: () => void,
  onDragEnd: () => void,
  onSingleClick: () => void,
  onDoubleClick: () => void
) {
  const isDraggingRef = useRef(false);
  const startPosRef = useRef({ x: 0, y: 0 });
  const lastClickTimeRef = useRef(0);

  const onMouseDown = useCallback((e: React.MouseEvent) => {
    if (e.button !== 0) return;
    isDraggingRef.current = false;
    startPosRef.current = { x: e.clientX, y: e.clientY };
  }, []);

  const onMouseMove = useCallback(
    (e: React.MouseEvent) => {
      if (e.buttons !== 1) return;
      const dx = Math.abs(e.clientX - startPosRef.current.x);
      const dy = Math.abs(e.clientY - startPosRef.current.y);
      if (!isDraggingRef.current && (dx > DRAG_THRESHOLD || dy > DRAG_THRESHOLD)) {
        isDraggingRef.current = true;
        onDragStart();
        getCurrentWebviewWindow().startDragging().catch(console.error);
      }
    },
    [onDragStart]
  );

  const onMouseUp = useCallback(
    (e: React.MouseEvent) => {
      if (isDraggingRef.current) {
        isDraggingRef.current = false;
        onDragEnd();
        return;
      }

      const now = Date.now();
      const delta = now - lastClickTimeRef.current;
      lastClickTimeRef.current = now;

      if (e.detail === 2 || delta < 300) {
        onDoubleClick();
      } else {
        setTimeout(() => {
          if (Date.now() - lastClickTimeRef.current >= 280) {
            onSingleClick();
          }
        }, 300);
      }
    },
    [onDragEnd, onDoubleClick, onSingleClick]
  );

  return { onMouseDown, onMouseMove, onMouseUp };
}
