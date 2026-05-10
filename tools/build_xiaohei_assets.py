#!/usr/bin/env python3
"""
Build Luo Xiaohei desktop-pet frames from public image/GIF sources.

The source files are downloaded into a temporary directory and discarded. The
repo only keeps normalized 256x256 transparent PNG frames plus one preview GIF.
"""

from __future__ import annotations

import io
import json
import math
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import requests
from PIL import Image, ImageEnhance, ImageFilter, ImageOps, ImageSequence


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = Path(__file__).with_name("xiaohei_asset_sources.json")
OUTPUT_DIR = REPO_ROOT / "src-tauri" / "resources" / "animations"
PUBLIC_OUTPUT_DIR = REPO_ROOT / "public" / "animations"
ICON_DIR = REPO_ROOT / "src-tauri" / "icons"
SIZE = 256
TARGET_COVERAGE = 0.80
USER_AGENT = "LuoXiaoHeiPetAssetBuilder/1.0"


@dataclass(frozen=True)
class Motion:
    sprite: str
    dx: float = 0
    dy: float = 0
    scale_x: float = 1
    scale_y: float = 1
    angle: float = 0
    flip: bool = False
    opacity: float = 1
    shadow: bool = True


def request_url(url: str, **kwargs: Any) -> requests.Response:
    headers = {"User-Agent": USER_AGENT, "Accept": "*/*"}
    response = requests.get(url, headers=headers, timeout=25, **kwargs)
    response.raise_for_status()
    return response


def fandom_file_url(file_name: str) -> str:
    response = request_url(
        "https://luoxiaohei.fandom.com/api.php",
        params={
            "action": "query",
            "titles": f"File:{file_name}",
            "prop": "imageinfo",
            "iiprop": "url",
            "format": "json",
        },
    )
    pages = response.json()["query"]["pages"]
    page = next(iter(pages.values()))
    return page["imageinfo"][0]["url"]


def scrape_tenor_media_url(page_url: str) -> str | None:
    try:
        html = request_url(page_url).text
    except Exception as exc:
        print(f"   ! Tenor unavailable: {page_url} ({exc})")
        return None

    candidates = re.findall(r"https://media\.tenor\.com/[^\"'<> ]+", html)
    gif_candidates = [url.replace("\\u0026", "&") for url in candidates if ".gif" in url]
    return gif_candidates[0] if gif_candidates else None


def download_source(name: str, spec: dict[str, Any], tmp_dir: Path) -> Path | None:
    try:
        if spec["type"] == "fandom_file":
            url = fandom_file_url(spec["file"])
        elif spec["type"] == "tenor_page":
            url = scrape_tenor_media_url(spec["url"])
            if not url:
                return None
        else:
            raise ValueError(f"Unsupported source type: {spec['type']}")

        response = request_url(url)
        suffix = Path(url.split("?", 1)[0]).suffix or ".img"
        path = tmp_dir / f"{name}{suffix}"
        path.write_bytes(response.content)
        print(f"   downloaded {name}: {Image.open(path).format} {Image.open(path).size}")
        return path
    except Exception as exc:
        print(f"   ! Failed to download {name}: {exc}")
        return None


def open_image(path: Path) -> Image.Image:
    image = Image.open(path)
    image.load()
    return image


def color_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


def remove_key_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()

    sample_points = [
        (0, 0),
        (width - 1, 0),
        (0, height - 1),
        (width - 1, height - 1),
        (width // 2, 0),
        (0, height // 2),
    ]
    key_colors = [pixels[x, y][:3] for x, y in sample_points]

    def is_background_pixel(x: int, y: int) -> bool:
        r, g, b, a = pixels[x, y]
        if a == 0:
            return True
        nearest = min(color_distance((r, g, b), key) for key in key_colors)
        pale_webp_bg = r > 145 and g > 135 and b < 135 and abs(r - g) < 55
        near_white = r > 225 and g > 225 and b > 210
        return nearest < 122 or pale_webp_bg or near_white

    queue = []
    visited = set()
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.pop()
        if (x, y) in visited or x < 0 or y < 0 or x >= width or y >= height:
            continue
        visited.add((x, y))
        if not is_background_pixel(x, y):
            continue
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))

    # Contract only the transparent edge a touch to remove WebP compression halos.
    alpha = rgba.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MinFilter(3))
    rgba.putalpha(alpha)
    return trim_alpha(rgba)


def trim_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if not bbox:
        return rgba
    return rgba.crop(bbox)


def normalize_sprite(image: Image.Image, coverage: float = TARGET_COVERAGE) -> Image.Image:
    image = trim_alpha(image)
    width, height = image.size
    if width <= 0 or height <= 0:
        return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    scale = min((SIZE * coverage) / width, (SIZE * coverage) / height)
    new_size = (max(1, round(width * scale)), max(1, round(height * scale)))
    resized = image.resize(new_size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    x = (SIZE - new_size[0]) // 2
    y = int((SIZE - new_size[1]) * 0.55)
    canvas.alpha_composite(resized, (x, y))
    return canvas


def extract_expression_sprites(path: Path, sprite_boxes: dict[str, list[int]]) -> dict[str, Image.Image]:
    source = open_image(path).convert("RGBA")
    sprites: dict[str, Image.Image] = {}
    for name, box in sprite_boxes.items():
        crop = source.crop(tuple(box))
        clean = remove_key_background(crop)
        sprites[name] = normalize_sprite(clean, coverage=0.78)
    return sprites


def source_gif_frames(path: Path) -> list[Image.Image]:
    source = Image.open(path)
    frames = []
    for frame in ImageSequence.Iterator(source):
        frames.append(normalize_sprite(remove_key_background(frame.convert("RGBA"))))
    return frames


def sample_frames(frames: list[Image.Image], count: int) -> list[Image.Image]:
    if not frames:
        return []
    if len(frames) == count:
        return [frame.copy() for frame in frames]
    if len(frames) > count:
        return [frames[round(i * (len(frames) - 1) / max(1, count - 1))].copy() for i in range(count)]

    sampled = []
    cursor = 0
    direction = 1
    while len(sampled) < count:
        sampled.append(frames[cursor].copy())
        if len(frames) == 1:
            continue
        cursor += direction
        if cursor >= len(frames):
            cursor = len(frames) - 2
            direction = -1
        elif cursor < 0:
            cursor = 1
            direction = 1
    return sampled


def sprite_bbox(sprite: Image.Image) -> tuple[int, int, int, int]:
    return sprite.getchannel("A").getbbox() or (0, 0, SIZE, SIZE)


def transform_sprite(sprite: Image.Image, motion: Motion) -> Image.Image:
    bbox = sprite_bbox(sprite)
    cropped = sprite.crop(bbox)
    if motion.flip:
        cropped = ImageOps.mirror(cropped)
    if motion.opacity < 1:
        alpha = cropped.getchannel("A").point(lambda value: round(value * motion.opacity))
        cropped.putalpha(alpha)

    new_w = max(1, round(cropped.width * motion.scale_x))
    new_h = max(1, round(cropped.height * motion.scale_y))
    transformed = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)
    if motion.angle:
        transformed = transformed.rotate(motion.angle, expand=True, resample=Image.Resampling.BICUBIC)

    frame = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    if motion.shadow:
        shadow = Image.new("RGBA", transformed.size, (0, 0, 0, 0))
        shadow.putalpha(transformed.getchannel("A").filter(ImageFilter.GaussianBlur(4)))
        shadow = ImageEnhance.Brightness(shadow).enhance(0)
        shadow_alpha = shadow.getchannel("A").point(lambda value: min(80, value // 2))
        shadow.putalpha(shadow_alpha)
        sx = round((SIZE - transformed.width) / 2 + motion.dx + 4)
        sy = round((SIZE - transformed.height) * 0.56 + motion.dy + 12)
        frame.alpha_composite(shadow, (sx, sy))

    x = round((SIZE - transformed.width) / 2 + motion.dx)
    y = round((SIZE - transformed.height) * 0.55 + motion.dy)
    frame.alpha_composite(transformed, (x, y))
    return frame


def make_motions(state: str, count: int) -> list[Motion]:
    motions: list[Motion] = []
    for index in range(count):
        phase = math.tau * index / count
        s = math.sin(phase)
        c = math.cos(phase)

        if state == "idle":
            sprite = "normal" if index not in (5, 6) else "shy"
            motions.append(Motion(sprite, dy=s * 3, scale_x=1 - s * 0.015, scale_y=1 + s * 0.025, angle=s * 1.5))
        elif state == "walk":
            motions.append(Motion("normal", dx=s * 8, dy=abs(s) * -6, angle=s * 7, flip=index >= count / 2))
        elif state == "sleep":
            motions.append(Motion("sad", dy=s * 2 + 8, scale_x=1.08, scale_y=0.88 + s * 0.02, angle=-8 + s * 2))
        elif state == "happy":
            motions.append(Motion("happy", dy=-abs(s) * 20, scale_x=1 + abs(s) * 0.04, scale_y=1 - abs(s) * 0.04, angle=s * 8))
        elif state == "stretch":
            p = index / max(1, count - 1)
            stretch = math.sin(p * math.pi)
            motions.append(Motion("shy", dy=stretch * 8, scale_x=1 + stretch * 0.22, scale_y=1 - stretch * 0.18, angle=-4 + stretch * 8))
        elif state == "lookAround":
            sprite = "cool" if index < count / 2 else "shy"
            motions.append(Motion(sprite, dx=s * 7, angle=s * 9, flip=index >= count / 2))
        elif state == "talking":
            sprite = "surprised" if index % 2 else "normal"
            motions.append(Motion(sprite, dy=s * 2, scale_x=1 + (index % 2) * 0.03, scale_y=1 - (index % 2) * 0.02))
        elif state == "thinking":
            sprite = "anxious" if index % 3 else "cool"
            motions.append(Motion(sprite, dx=c * 3, dy=s * 3, angle=6 + s * 3))
        elif state == "drag":
            motions.append(Motion("surprised", dy=s * 3, angle=s * 18, scale_x=0.96, scale_y=1.04))
        elif state == "fall":
            p = index / max(1, count - 1)
            sprite = "surprised" if p < 0.45 else "crying"
            motions.append(Motion(sprite, dy=p * 46 - 14, angle=(1 - p) * 35, scale_x=1 + max(0, p - 0.55) * 0.35, scale_y=1 - max(0, p - 0.55) * 0.25))
        else:
            motions.append(Motion("normal"))
    return motions


def write_frames(state: str, sprites: dict[str, Image.Image], count: int) -> list[Image.Image]:
    frames = []
    for index, motion in enumerate(make_motions(state, count)):
        sprite = sprites[motion.sprite]
        frame = transform_sprite(sprite, motion)
        path = OUTPUT_DIR / f"{state}_{index:03d}.png"
        frame.save(path, "PNG")
        frames.append(frame)
    return frames


def write_source_frames(state: str, frames: list[Image.Image], count: int) -> list[Image.Image]:
    sampled = sample_frames(frames, count)
    written = []
    for index, frame in enumerate(sampled):
        path = OUTPUT_DIR / f"{state}_{index:03d}.png"
        frame.save(path, "PNG")
        written.append(frame)
    return written


def clear_output() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PUBLIC_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for path in OUTPUT_DIR.glob("*.png"):
        path.unlink()
    for path in PUBLIC_OUTPUT_DIR.glob("*.png"):
        path.unlink()
    preview = OUTPUT_DIR / "xiaohei_idle.gif"
    if preview.exists():
        preview.unlink()
    public_preview = PUBLIC_OUTPUT_DIR / "xiaohei_idle.gif"
    if public_preview.exists():
        public_preview.unlink()


def save_preview_gif(idle_frames: list[Image.Image], duration_ms: int) -> None:
    gif_path = OUTPUT_DIR / "xiaohei_idle.gif"
    gif_frames = [rgba_to_transparent_gif_frame(frame) for frame in idle_frames]
    gif_frames[0].save(
        gif_path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=duration_ms,
        loop=0,
        disposal=2,
        transparency=0,
    )
    shutil.copy2(gif_path, PUBLIC_OUTPUT_DIR / gif_path.name)


def rgba_to_transparent_gif_frame(frame: Image.Image) -> Image.Image:
    rgba = frame.convert("RGBA")
    alpha = rgba.getchannel("A")
    quantized = rgba.convert("RGB").quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    shifted = quantized.point(lambda value: value + 1)
    palette = quantized.getpalette() or []
    shifted.putpalette([0, 255, 0] + palette[: 255 * 3] + [0] * max(0, 768 - 3 - len(palette[: 255 * 3])))
    transparent_mask = alpha.point(lambda value: 255 if value < 24 else 0)
    shifted.paste(0, mask=transparent_mask)
    shifted.info["transparency"] = 0
    shifted.info["disposal"] = 2
    return shifted


def icon_canvas(source: Image.Image, size: int) -> Image.Image:
    sprite = trim_alpha(source.convert("RGBA"))
    scale = min(size * 0.86 / sprite.width, size * 0.86 / sprite.height)
    sprite = sprite.resize((round(sprite.width * scale), round(sprite.height * scale)), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = (size - sprite.width) // 2
    y = (size - sprite.height) // 2
    canvas.alpha_composite(sprite, (x, y))
    return canvas


def write_app_icons(source: Image.Image) -> None:
    ICON_DIR.mkdir(parents=True, exist_ok=True)

    for size, name in [(16, "16x16.png"), (32, "32x32.png"), (128, "128x128.png"), (256, "128x128@2x.png")]:
        icon_canvas(source, size).save(ICON_DIR / name, "PNG")
    icon_canvas(source, 32).save(ICON_DIR / "tray-icon.png", "PNG")

    ico_sizes = [16, 32, 48, 64, 128, 256]
    icon_canvas(source, 256).save(ICON_DIR / "icon.ico", sizes=[(size, size) for size in ico_sizes])

    with tempfile.TemporaryDirectory(prefix="xiaohei-iconset-") as tmp:
        iconset = Path(tmp) / "icon.iconset"
        iconset.mkdir()
        icon_specs = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]
        for size, name in icon_specs:
            icon_canvas(source, size).save(iconset / name, "PNG")
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ICON_DIR / "icon.icns")], check=True)


def build_assets() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text())
    clear_output()

    tmp_dir = Path(tempfile.mkdtemp(prefix="xiaohei-assets-"))
    try:
        downloaded: dict[str, Path] = {}
        for name, spec in manifest["sources"].items():
            path = download_source(name, spec, tmp_dir)
            if path:
                downloaded[name] = path

        expression_spec = manifest["sources"]["expression_diagram"]
        expression_path = downloaded.get("expression_diagram")
        if not expression_path:
            raise RuntimeError("expression_diagram source is required to build normalized sprites")

        sprites = extract_expression_sprites(expression_path, expression_spec["sprites"])

        source_frames: dict[str, list[Image.Image]] = {}
        for source_name, path in downloaded.items():
            try:
                frames = source_gif_frames(path)
            except Exception:
                continue
            if len(frames) > 1:
                source_frames[source_name] = frames

        idle_frames: list[Image.Image] | None = None
        counts: dict[str, int] = {}
        for state, spec in manifest["states"].items():
            source_name = spec.get("source")
            if source_name in source_frames:
                frames = write_source_frames(state, source_frames[source_name], int(spec["frames"]))
            else:
                fallback = dict(spec)
                fallback["sprite"] = fallback.get("fallback_sprite", "normal")
                frames = write_frames(state, sprites, int(fallback["frames"]))
            counts[state] = len(frames)
            if state == "idle":
                idle_frames = frames
            print(f"   wrote {state}: {len(frames)} frames")

        if idle_frames is None:
            raise RuntimeError("idle frames were not generated")
        save_preview_gif(idle_frames, int(manifest["states"]["idle"]["duration_ms"]))
        write_app_icons(idle_frames[0])

        for path in OUTPUT_DIR.glob("*.png"):
            shutil.copy2(path, PUBLIC_OUTPUT_DIR / path.name)

        too_short = [state for state, count in counts.items() if count < 6]
        if counts.get("idle", 0) < 10 or too_short:
            raise RuntimeError(f"Generated frame counts are too low: {counts}")

        print(f"Done. Generated {sum(counts.values())} PNG frames, xiaohei_idle.gif, and app icons.")
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    build_assets()
