#!/usr/bin/env python3
"""
罗小黑桌宠 - 素材转换工具
功能：
  1. GIF → PNG 序列帧（透明背景）
  2. Spine 模型文件索引
  3. 自动按动画状态分类整理
"""

import os
import sys
import argparse
import struct
from pathlib import Path
from PIL import Image

# ============================================================
# 动画状态映射表
# 将明日方舟的 Spine 动画名 / GIF 文件名 映射到桌宠状态
# ============================================================
ANIMATION_MAPPING = {
    # 明日方舟 Spine 动画名 → 桌宠状态
    "Idle":         "idle",
    "idle":         "idle",
    "Relax":        "idle",
    "relax":        "idle",
    "Sit":          "sleep",
    "sit":          "sleep",
    "Sleep":        "sleep",
    "sleep":        "sleep",
    "Move":         "walk",
    "move":         "walk",
    "Walk":         "walk",
    "walk":         "walk",
    "Attack":       "happy",
    "attack":       "happy",
    "Skill":        "happy",
    "skill":        "happy",
    "Special":      "stretch",
    "special":      "stretch",
    "Interact":     "lookAround",
    "interact":     "lookAround",
    "Begin":        "happy",
    "Die":          "fall",

    # 常见 GIF 文件名关键词 → 桌宠状态
    "待机":         "idle",
    "发呆":         "idle",
    "站立":         "idle",
    "睡觉":         "sleep",
    "睡":           "sleep",
    "走":           "walk",
    "跑":           "walk",
    "开心":         "happy",
    "高兴":         "happy",
    "笑":           "happy",
    "摸":           "happy",
    "伸懒腰":       "stretch",
    "伸":           "stretch",
    "打哈欠":       "stretch",
    "看":           "lookAround",
    "张望":         "lookAround",
    "说":           "talking",
    "说话":         "talking",
    "聊":           "talking",
    "想":           "thinking",
    "思考":         "thinking",
    "拽":           "drag",
    "拖":           "drag",
    "掉":           "fall",
    "摔":           "fall",
}

# 默认状态：无法识别的文件归入此类
DEFAULT_STATE = "idle"


def gif_to_frames(gif_path: Path, output_dir: Path, target_size: int = 256):
    """
    将 GIF 拆分为透明背景的 PNG 序列帧

    Args:
        gif_path: GIF 文件路径
        output_dir: 输出目录
        target_size: 目标尺寸（正方形边长）
    """
    try:
        img = Image.open(gif_path)
    except Exception as e:
        print(f"   ⚠️  无法打开 {gif_path.name}: {e}")
        return 0

    if not hasattr(img, 'n_frames'):
        print(f"   ⚠️  {gif_path.name} 不是动画 GIF")
        return 0

    n_frames = img.n_frames
    if n_frames <= 0:
        return 0

    # 根据文件名猜测动画状态
    state = guess_state(gif_path.stem)
    state_dir = output_dir / state
    state_dir.mkdir(parents=True, exist_ok=True)

    # 检查该状态目录已有的帧数（避免覆盖）
    existing = len(list(state_dir.glob("*.png")))
    start_index = existing

    frames_saved = 0

    # 处理每一帧
    for i in range(n_frames):
        img.seek(i)

        # 转为 RGBA（保留透明通道）
        frame = img.convert("RGBA")

        # 去除白色/浅色背景（如果不是真正的透明 GIF）
        frame = remove_background(frame)

        # 缩放到目标尺寸（保持比例，居中放置在正方形画布上）
        frame = fit_to_square(frame, target_size)

        # 保存
        frame_path = state_dir / f"{start_index + i:03d}.png"
        frame.save(frame_path, "PNG")
        frames_saved += 1

    print(f"   📁 {gif_path.name} → {state}/ ({frames_saved} 帧)")
    return frames_saved


def remove_background(img: Image.Image, threshold: int = 240) -> Image.Image:
    """
    移除接近白色的背景像素，使其变为透明。
    仅在检测到 GIF 背景不透明时使用。
    """
    data = img.getdata()

    # 先检查是否已经有透明像素
    has_transparency = any(pixel[3] < 128 for pixel in data)
    if has_transparency:
        return img  # 已经是透明背景，不处理

    # 检测四角像素是否接近白色（判断是否有白色背景）
    w, h = img.size
    corners = [
        img.getpixel((0, 0)),
        img.getpixel((w - 1, 0)),
        img.getpixel((0, h - 1)),
        img.getpixel((w - 1, h - 1)),
    ]

    is_white_bg = all(
        c[0] > threshold and c[1] > threshold and c[2] > threshold
        for c in corners
    )

    if not is_white_bg:
        return img  # 不是白色背景，不处理

    # 将接近白色的像素变为透明
    new_data = []
    for pixel in data:
        r, g, b, a = pixel
        if r > threshold and g > threshold and b > threshold:
            new_data.append((r, g, b, 0))
        else:
            new_data.append(pixel)

    img.putdata(new_data)
    return img


def fit_to_square(img: Image.Image, size: int) -> Image.Image:
    """
    将图片等比缩放并居中放置在正方形透明画布上。
    """
    # 等比缩放
    w, h = img.size
    scale = min(size / w, size / h) * 0.9  # 留 10% 边距
    new_w = int(w * scale)
    new_h = int(h * scale)
    img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # 居中放置
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset_x = (size - new_w) // 2
    offset_y = (size - new_h) // 2
    canvas.paste(img, (offset_x, offset_y), img)

    return canvas


def guess_state(filename: str) -> str:
    """
    根据文件名猜测动画状态。
    """
    for keyword, state in ANIMATION_MAPPING.items():
        if keyword.lower() in filename.lower():
            return state
    return DEFAULT_STATE


def process_spine_folder(spine_dir: Path, output_dir: Path, target_size: int):
    """
    处理 Spine 模型目录：
    - 索引找到的 .skel, .atlas, .png 文件
    - 如果有配套的 GIF（一些仓库会同时提供），直接转换
    """
    skel_files = list(spine_dir.rglob("*.skel"))
    atlas_files = list(spine_dir.rglob("*.atlas"))
    png_files = list(spine_dir.rglob("*.png"))

    if skel_files:
        print(f"\n   🦴 找到 Spine 模型文件:")
        for f in skel_files:
            print(f"      .skel: {f}")
        for f in atlas_files:
            print(f"      .atlas: {f}")
        for f in png_files[:5]:
            print(f"      .png: {f}")

        print(f"\n   ℹ️  Spine 模型需要用 Spine 编辑器导出为 PNG 序列帧。")
        print(f"   请参考以下步骤：")
        print(f"   1. 下载 Spine 编辑器试用版: http://esotericsoftware.com/spine-trial")
        print(f"   2. 或使用在线 Spine 查看器: https://naganeko.pages.dev/chibi/")
        print(f"   3. 导入 .skel + .atlas + .png 文件")
        print(f"   4. 选择动画 → 导出 → PNG 序列帧（带透明通道）")
        print(f"   5. 将导出的帧放到对应状态文件夹中")
        print(f"")
        print(f"   也可以用这个在线工具直接查看方舟小人动画：")
        print(f"   https://arknights-spine.netlify.app/")

        # 尝试解析 .skel 文件获取动画列表
        for skel in skel_files:
            animations = try_parse_skel_animations(skel)
            if animations:
                print(f"\n   📋 {skel.name} 中的动画列表:")
                for anim in animations:
                    state = guess_state(anim)
                    print(f"      {anim:20s} → {state}/")


def try_parse_skel_animations(skel_path: Path) -> list:
    """
    尝试从 .skel 二进制文件中提取动画名称列表。
    Spine 二进制格式中动画名是以字符串形式存储的。
    这是一个简单的启发式提取，不是完整的解析器。
    """
    try:
        data = skel_path.read_bytes()
        # 寻找看起来像动画名的 ASCII 字符串
        animations = []
        # 常见的明日方舟动画名模式
        patterns = [
            b"Idle", b"idle", b"Move", b"move", b"Attack", b"attack",
            b"Die", b"die", b"Skill", b"skill", b"Special", b"special",
            b"Relax", b"relax", b"Sit", b"sit", b"Sleep", b"sleep",
            b"Interact", b"interact", b"Begin", b"Start",
        ]
        for pattern in patterns:
            if pattern in data:
                animations.append(pattern.decode())

        return list(set(animations))
    except Exception:
        return []


def process_directory(input_dirs: list, output_dir: Path, target_size: int):
    """
    扫描输入目录，处理所有找到的素材文件。
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    total_frames = 0

    for input_dir in input_dirs:
        input_path = Path(input_dir)
        if not input_path.exists():
            continue

        # 处理 GIF 文件
        gif_files = list(input_path.rglob("*.gif"))
        if gif_files:
            print(f"\n   🎞️  找到 {len(gif_files)} 个 GIF 文件:")
            for gif in sorted(gif_files):
                frames = gif_to_frames(gif, output_dir, target_size)
                total_frames += frames

        # 处理已有的 PNG 序列帧（可能用户自己准备的）
        png_dirs = set()
        for png in input_path.rglob("*.png"):
            # 跳过 Spine atlas 纹理
            if any(x in png.name for x in ["atlas", "texture", "spritesheet"]):
                continue
            png_dirs.add(png.parent)

        for png_dir in png_dirs:
            pngs = sorted(png_dir.glob("*.png"))
            if len(pngs) >= 2:  # 至少2帧才算序列
                state = guess_state(png_dir.name)
                state_dir = output_dir / state
                state_dir.mkdir(parents=True, exist_ok=True)

                print(f"\n   📁 复制 PNG 序列: {png_dir.name}/ → {state}/ ({len(pngs)} 帧)")
                for i, png in enumerate(pngs):
                    img = Image.open(png).convert("RGBA")
                    img = fit_to_square(img, target_size)
                    img.save(state_dir / f"{i:03d}.png", "PNG")
                    total_frames += 1

        # 处理 Spine 文件
        if list(input_path.rglob("*.skel")):
            process_spine_folder(input_path, output_dir, target_size)

    return total_frames


def main():
    parser = argparse.ArgumentParser(description="罗小黑桌宠 - 素材转换工具")
    parser.add_argument("--input", nargs="+", required=True, help="输入目录（可以多个）")
    parser.add_argument("--output", required=True, help="输出目录")
    parser.add_argument("--size", type=int, default=256, help="输出帧尺寸（默认 256x256）")

    args = parser.parse_args()
    output_dir = Path(args.output)

    print(f"   输入目录: {', '.join(args.input)}")
    print(f"   输出目录: {output_dir}")
    print(f"   帧尺寸:   {args.size}x{args.size}")

    total = process_directory(args.input, output_dir, args.size)

    if total > 0:
        print(f"\n   ✅ 共转换 {total} 帧素材")
    else:
        print(f"\n   ℹ️  未找到可自动转换的素材文件")


if __name__ == "__main__":
    main()
