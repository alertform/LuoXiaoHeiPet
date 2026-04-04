#!/usr/bin/env python3
"""
罗小黑桌宠 - 占位素材生成器
在没有正式素材时，生成一套简笔画风格的罗小黑动画帧，用于开发调试。
生成的是一个可爱的黑猫剪影，带有简单的逐帧动画。
"""

import math
from pathlib import Path
from PIL import Image, ImageDraw
import argparse


def draw_cat_base(draw, cx, cy, scale=1.0, ear_angle=0):
    """画罗小黑的基本形状：圆身体 + 圆头 + 三角耳朵 + 绿眼睛"""
    s = scale

    # 身体（椭圆）
    body_w, body_h = int(50 * s), int(40 * s)
    draw.ellipse(
        [cx - body_w, cy + int(5 * s), cx + body_w, cy + int(5 * s) + body_h * 2],
        fill=(30, 30, 30)
    )

    # 头（大圆）
    head_r = int(38 * s)
    head_cy = cy - int(5 * s)
    draw.ellipse(
        [cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r],
        fill=(20, 20, 20)
    )

    # 左耳（三角形）
    ear_size = int(22 * s)
    left_ear_x = cx - int(25 * s)
    left_ear_y = head_cy - head_r + int(5 * s)
    draw.polygon([
        (left_ear_x, left_ear_y),
        (left_ear_x - int(12 * s) + ear_angle, left_ear_y - ear_size),
        (left_ear_x + int(15 * s), left_ear_y - int(5 * s)),
    ], fill=(20, 20, 20))

    # 右耳
    right_ear_x = cx + int(25 * s)
    draw.polygon([
        (right_ear_x, left_ear_y),
        (right_ear_x + int(12 * s) - ear_angle, left_ear_y - ear_size),
        (right_ear_x - int(15 * s), left_ear_y - int(5 * s)),
    ], fill=(20, 20, 20))

    # 内耳（粉色）
    inner_size = int(8 * s)
    draw.polygon([
        (left_ear_x, left_ear_y + int(2 * s)),
        (left_ear_x - int(5 * s) + ear_angle, left_ear_y - inner_size),
        (left_ear_x + int(8 * s), left_ear_y),
    ], fill=(180, 100, 120))

    draw.polygon([
        (right_ear_x, left_ear_y + int(2 * s)),
        (right_ear_x + int(5 * s) - ear_angle, left_ear_y - inner_size),
        (right_ear_x - int(8 * s), left_ear_y),
    ], fill=(180, 100, 120))

    return head_cy  # 返回头部中心 y，方便画眼睛


def draw_eyes(draw, cx, cy, scale=1.0, state="open", look_x=0):
    """画眼睛"""
    s = scale
    eye_spacing = int(15 * s)
    eye_r = int(7 * s)

    for side in [-1, 1]:
        ex = cx + side * eye_spacing + look_x
        ey = cy

        if state == "open":
            # 绿色大眼睛
            draw.ellipse(
                [ex - eye_r, ey - eye_r, ex + eye_r, ey + eye_r],
                fill=(50, 220, 100)
            )
            # 瞳孔
            pr = int(3 * s)
            draw.ellipse(
                [ex - pr, ey - pr, ex + pr, ey + pr],
                fill=(10, 10, 10)
            )
            # 高光
            hr = int(2 * s)
            draw.ellipse(
                [ex - hr + int(2 * s), ey - hr - int(1 * s),
                 ex + int(2 * s), ey - int(1 * s)],
                fill=(255, 255, 255)
            )
        elif state == "closed":
            # 闭眼（弧线）
            draw.arc(
                [ex - eye_r, ey - int(2 * s), ex + eye_r, ey + int(6 * s)],
                start=0, end=180, fill=(100, 100, 100), width=int(2 * s)
            )
        elif state == "happy":
            # 开心的倒 U 形眼
            draw.arc(
                [ex - eye_r, ey - eye_r, ex + eye_r, ey + int(2 * s)],
                start=200, end=340, fill=(50, 220, 100), width=int(3 * s)
            )


def draw_mouth(draw, cx, cy, scale=1.0, state="normal"):
    """画嘴巴"""
    s = scale
    my = cy + int(12 * s)

    if state == "normal":
        # 小三角嘴
        draw.polygon([
            (cx - int(4 * s), my),
            (cx + int(4 * s), my),
            (cx, my + int(5 * s)),
        ], fill=(180, 80, 100))
    elif state == "open":
        # 张嘴
        draw.ellipse(
            [cx - int(6 * s), my, cx + int(6 * s), my + int(8 * s)],
            fill=(180, 60, 80)
        )
    elif state == "smile":
        # 微笑弧线
        draw.arc(
            [cx - int(8 * s), my - int(4 * s), cx + int(8 * s), my + int(8 * s)],
            start=10, end=170, fill=(180, 80, 100), width=int(2 * s)
        )


def draw_tail(draw, cx, cy, scale=1.0, phase=0):
    """画尾巴（带摆动）"""
    s = scale
    tail_start_x = cx + int(40 * s)
    tail_start_y = cy + int(35 * s)

    points = []
    for t in range(20):
        tt = t / 19.0
        x = tail_start_x + int(tt * 35 * s)
        wave = math.sin(tt * math.pi * 2 + phase) * 12 * s
        y = tail_start_y - int(tt * 25 * s) + int(wave)
        points.append((x, y))

    if len(points) >= 2:
        draw.line(points, fill=(30, 30, 30), width=int(6 * s), joint="curve")


def generate_idle_frames(size, num_frames=12):
    """待机动画：轻微呼吸 + 尾巴摆动"""
    frames = []
    cx, cy = size // 2, size // 2 + 10
    s = size / 256

    for i in range(num_frames):
        phase = i / num_frames * math.pi * 2
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # 呼吸效果：轻微上下浮动
        breathe = math.sin(phase) * 2 * s

        draw_tail(draw, cx, cy + breathe, s, phase)
        head_cy = draw_cat_base(draw, cx, cy + breathe, s)
        draw_eyes(draw, cx, head_cy, s, "open")
        draw_mouth(draw, cx, head_cy, s, "normal")

        frames.append(img)
    return frames


def generate_happy_frames(size, num_frames=8):
    """开心动画：眯眼笑 + 跳动"""
    frames = []
    cx, cy = size // 2, size // 2 + 10
    s = size / 256

    for i in range(num_frames):
        phase = i / num_frames * math.pi * 2
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # 跳跃效果
        bounce = -abs(math.sin(phase)) * 15 * s

        draw_tail(draw, cx, cy + bounce, s, phase * 2)
        head_cy = draw_cat_base(draw, cx, cy + bounce, s, ear_angle=int(math.sin(phase) * 3))
        draw_eyes(draw, cx, head_cy, s, "happy")
        draw_mouth(draw, cx, head_cy, s, "smile")

        frames.append(img)
    return frames


def generate_sleep_frames(size, num_frames=8):
    """睡觉动画：闭眼 + 缓慢呼吸"""
    frames = []
    cx, cy = size // 2, size // 2 + 15
    s = size / 256

    for i in range(num_frames):
        phase = i / num_frames * math.pi * 2
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        breathe = math.sin(phase) * 3 * s
        draw_tail(draw, cx, cy + breathe, s, phase * 0.3)
        head_cy = draw_cat_base(draw, cx, cy + breathe, s)
        draw_eyes(draw, cx, head_cy, s, "closed")
        draw_mouth(draw, cx, head_cy, s, "normal")

        # 画 zzZ
        zz_phase = (i % 4) / 4
        zz_x = cx + int(35 * s)
        zz_y = head_cy - int(30 * s) - int(zz_phase * 15 * s)
        zz_alpha = int(255 * (1 - zz_phase))
        zz_size = int(10 * s + zz_phase * 5 * s)
        draw.text((zz_x, zz_y), "z", fill=(200, 200, 255, zz_alpha))

        frames.append(img)
    return frames


def generate_walk_frames(size, num_frames=8):
    """走路动画：左右晃动"""
    frames = []
    cx, cy = size // 2, size // 2 + 10
    s = size / 256

    for i in range(num_frames):
        phase = i / num_frames * math.pi * 2
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        sway_x = math.sin(phase) * 5 * s
        bob_y = abs(math.sin(phase * 2)) * 4 * s

        draw_tail(draw, cx + sway_x, cy - bob_y, s, phase)
        head_cy = draw_cat_base(draw, cx + sway_x, cy - bob_y, s)
        draw_eyes(draw, cx + sway_x, head_cy, s, "open", look_x=int(sway_x))
        draw_mouth(draw, cx + sway_x, head_cy, s, "normal")

        frames.append(img)
    return frames


def generate_stretch_frames(size, num_frames=10):
    """伸懒腰动画"""
    frames = []
    cx, cy = size // 2, size // 2 + 10
    s = size / 256

    for i in range(num_frames):
        t = i / (num_frames - 1)  # 0 到 1
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # 先缩下去再伸展
        if t < 0.3:
            squeeze = t / 0.3
            offset_y = squeeze * 10 * s
        elif t < 0.7:
            stretch = (t - 0.3) / 0.4
            offset_y = 10 * s - stretch * 20 * s
        else:
            recover = (t - 0.7) / 0.3
            offset_y = -10 * s + recover * 10 * s

        draw_tail(draw, cx, cy + offset_y, s, t * math.pi * 3)
        head_cy = draw_cat_base(draw, cx, cy + offset_y, s)
        draw_eyes(draw, cx, head_cy, s, "closed" if t < 0.6 else "open")
        draw_mouth(draw, cx, head_cy, s, "open" if 0.2 < t < 0.6 else "normal")

        frames.append(img)
    return frames


def generate_look_around_frames(size, num_frames=12):
    """四处张望动画"""
    frames = []
    cx, cy = size // 2, size // 2 + 10
    s = size / 256

    for i in range(num_frames):
        phase = i / num_frames * math.pi * 2
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        look_x = int(math.sin(phase) * 8 * s)

        draw_tail(draw, cx, cy, s, phase * 0.5)
        head_cy = draw_cat_base(draw, cx, cy, s, ear_angle=int(math.sin(phase) * 2))
        draw_eyes(draw, cx, head_cy, s, "open", look_x=look_x)
        draw_mouth(draw, cx, head_cy, s, "normal")

        frames.append(img)
    return frames


def generate_talking_frames(size, num_frames=6):
    """说话动画：嘴巴开合"""
    frames = []
    cx, cy = size // 2, size // 2 + 10
    s = size / 256

    for i in range(num_frames):
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        draw_tail(draw, cx, cy, s, i * 0.5)
        head_cy = draw_cat_base(draw, cx, cy, s)
        draw_eyes(draw, cx, head_cy, s, "open")
        mouth_state = "open" if i % 2 == 0 else "normal"
        draw_mouth(draw, cx, head_cy, s, mouth_state)

        frames.append(img)
    return frames


def generate_thinking_frames(size, num_frames=8):
    """思考动画：歪头 + 问号"""
    frames = []
    cx, cy = size // 2, size // 2 + 10
    s = size / 256

    for i in range(num_frames):
        phase = i / num_frames * math.pi * 2
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        tilt = math.sin(phase * 0.5) * 3 * s

        draw_tail(draw, cx + tilt, cy, s, phase * 0.3)
        head_cy = draw_cat_base(draw, cx + tilt, cy, s)
        draw_eyes(draw, cx + tilt, head_cy, s, "open", look_x=int(5 * s))
        draw_mouth(draw, cx + tilt, head_cy, s, "normal")

        # 画问号/省略号
        dot_y = head_cy - int(45 * s)
        dot_x = cx + int(30 * s)
        dot_alpha = int(128 + 127 * math.sin(phase))
        for di, dx in enumerate([0, 8, 16]):
            r = int(2.5 * s)
            draw.ellipse(
                [dot_x + int(dx * s) - r, dot_y - r,
                 dot_x + int(dx * s) + r, dot_y + r],
                fill=(200, 200, 200, dot_alpha)
            )

        frames.append(img)
    return frames


def generate_fall_frames(size, num_frames=6):
    """掉落动画"""
    frames = []
    cx = size // 2
    s = size / 256

    for i in range(num_frames):
        t = i / (num_frames - 1)
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # 加速下落
        fall_y = int(t * t * 60 * s)
        cy = size // 2 - int(30 * s) + fall_y

        # 着地弹跳
        if t > 0.7:
            bounce = math.sin((t - 0.7) / 0.3 * math.pi) * 10 * s
            cy -= int(bounce)

        draw_tail(draw, cx, cy, s, t * math.pi * 4)
        head_cy = draw_cat_base(draw, cx, cy, s)

        # 掉落时惊讶的表情
        if t < 0.7:
            draw_eyes(draw, cx, head_cy, s, "open")
            draw_mouth(draw, cx, head_cy, s, "open")
        else:
            draw_eyes(draw, cx, head_cy, s, "closed")
            draw_mouth(draw, cx, head_cy, s, "normal")

        frames.append(img)
    return frames


# 所有状态的生成函数映射
STATE_GENERATORS = {
    "idle":       generate_idle_frames,
    "happy":      generate_happy_frames,
    "sleep":      generate_sleep_frames,
    "walk":       generate_walk_frames,
    "stretch":    generate_stretch_frames,
    "lookAround": generate_look_around_frames,
    "talking":    generate_talking_frames,
    "thinking":   generate_thinking_frames,
    "fall":       generate_fall_frames,
}


def main():
    parser = argparse.ArgumentParser(description="罗小黑桌宠 - 占位素材生成器")
    parser.add_argument("--output", required=True, help="输出目录")
    parser.add_argument("--size", type=int, default=256, help="帧尺寸（默认256）")

    args = parser.parse_args()
    output = Path(args.output)

    print(f"\n   🎨 生成占位素材 (尺寸: {args.size}x{args.size})")

    total_frames = 0
    for state_name, generator in STATE_GENERATORS.items():
        state_dir = output / state_name
        state_dir.mkdir(parents=True, exist_ok=True)

        frames = generator(args.size)
        for i, frame in enumerate(frames):
            frame.save(state_dir / f"{i:03d}.png", "PNG")
            total_frames += 1

        print(f"   ✅ {state_name:12s}: {len(frames)} 帧")

    print(f"\n   🎉 共生成 {total_frames} 帧占位素材")
    print(f"   📁 输出目录: {output}")


if __name__ == "__main__":
    main()
