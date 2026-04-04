#!/usr/bin/env python3
"""
Generate high-quality LuoXiaoHei (罗小黑) desktop pet sprite frames.
Based on the cat form from the animation 罗小黑战记.

Key features:
- Large round head with huge cream/white eyes
- Green triangular forehead mark
- Small pointed ears
- Compact black body with short legs
- Long black tail
"""

import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Canvas size
SIZE = 256
CENTER_X = SIZE // 2
CENTER_Y = SIZE // 2

# Colors
BLACK = (30, 30, 30, 255)
DARK_OUTLINE = (15, 15, 15, 255)
EYE_WHITE = (235, 230, 215, 255)  # Slightly cream/warm white
EYE_OUTLINE = (45, 40, 35, 255)
PUPIL = (25, 25, 25, 255)
PUPIL_HIGHLIGHT = (255, 255, 255, 230)
GREEN_MARK = (120, 190, 140, 255)  # Forehead triangle
GREEN_DARK = (80, 150, 100, 255)
INNER_EAR = (80, 70, 65, 255)
NOSE = (70, 65, 60, 255)
MOUTH_LINE = (60, 55, 50, 255)
BLUSH = (180, 100, 100, 80)  # Semi-transparent pink
TAIL_COLOR = (35, 35, 35, 255)
TRANSPARENT = (0, 0, 0, 0)


def draw_ellipse_smooth(draw, bbox, fill=None, outline=None, width=1):
    """Draw a smoother ellipse using anti-aliasing trick."""
    draw.ellipse(bbox, fill=fill, outline=outline, width=width)


def draw_rounded_polygon(img, points, fill, outline=None, outline_width=2):
    """Draw a polygon then slightly blur edges for smoothness."""
    draw = ImageDraw.Draw(img)
    draw.polygon(points, fill=fill, outline=outline)


def lerp(a, b, t):
    """Linear interpolation."""
    return a + (b - a) * t


def ease_in_out(t):
    """Smooth easing function."""
    return t * t * (3 - 2 * t)


def draw_xiaohei(img, params):
    """
    Draw 罗小黑 cat form with given parameters.
    """
    draw = ImageDraw.Draw(img)

    x = params.get('x', CENTER_X)
    y = params.get('y', CENTER_Y + 20)
    s = params.get('scale', 1.15)  # Bigger default scale
    head_tilt = params.get('head_tilt', 0)
    eye_state = params.get('eye_state', 'open')
    pupil_dx = params.get('pupil_dx', 0)
    pupil_dy = params.get('pupil_dy', 0)
    mouth_state = params.get('mouth_state', 'normal')
    body_squash = params.get('body_squash', 1.0)
    body_stretch = params.get('body_stretch', 1.0)
    tail_phase = params.get('tail_phase', 0)
    tail_up = params.get('tail_up', 0.3)
    leg_phase = params.get('leg_phase', 0)
    walking = params.get('walking', False)
    sleeping = params.get('sleeping', False)
    blush = params.get('blush', False)
    z_bubbles = params.get('z_bubbles', [])

    # Key dimensions (relative to scale)
    head_r = int(46 * s)  # Head radius - BIGGER
    body_w = int(36 * s * body_stretch)
    body_h = int(25 * s * body_squash)

    # Positions
    body_cy = y + int(22 * s)
    head_cy = y - int(5 * s)

    if sleeping:
        # Sleeping: curled up - body flatter, head resting to the side
        body_cy = y + int(18 * s)
        head_cy = y + int(2 * s)
        head_r = int(42 * s)
        body_w = int(48 * s)
        body_h = int(18 * s)
        x_shift = int(-10 * s)  # Head shifted left
    else:
        x_shift = 0

    # === TAIL (draw first, behind body) ===
    tail_base_x = x + int(body_w * 0.8)
    tail_base_y = body_cy

    points = []
    tail_len = 20
    for i in range(tail_len):
        t = i / (tail_len - 1)
        tx = tail_base_x + int(t * 45 * s)
        wave = math.sin(t * math.pi * 1.5 + tail_phase) * 10 * s
        ty = tail_base_y - int(t * tail_up * 45 * s) + int(wave)
        points.append((tx, ty))

    # Draw tail: outline first, then fill
    for i in range(len(points) - 1):
        thickness = int((1.0 - i / len(points)) * 14 * s) + int(4 * s)
        draw.line([points[i], points[i + 1]], fill=DARK_OUTLINE, width=max(thickness, 3))
    for i in range(len(points) - 1):
        thickness = int((1.0 - i / len(points)) * 11 * s) + int(3 * s)
        draw.line([points[i], points[i + 1]], fill=BLACK, width=max(thickness, 2))
    # Rounded tail tip
    if points:
        tip = points[-1]
        tip_r = int(3 * s)
        draw.ellipse([tip[0] - tip_r, tip[1] - tip_r, tip[0] + tip_r, tip[1] + tip_r], fill=BLACK)

    # === LEGS ===
    leg_w = int(12 * s)
    leg_h = int(18 * s)

    if sleeping:
        # Sleeping: tiny paws peeking out from under body
        for px_off in [-20, -8]:
            px = x + int(px_off * s)
            py = body_cy + int(body_h * 0.5)
            draw.ellipse([px - int(6*s), py, px + int(6*s), py + int(8*s)],
                         fill=BLACK, outline=DARK_OUTLINE)
    elif walking:
        for i, lx_offset in enumerate([-20, -8, 8, 20]):
            phase_offset = i * math.pi / 2
            leg_dy = int(math.sin(leg_phase + phase_offset) * 6 * s)
            leg_x = x + int(lx_offset * s)
            leg_y = body_cy + int(body_h * 0.4)
            draw.ellipse([
                leg_x - leg_w // 2, leg_y + leg_dy,
                leg_x + leg_w // 2, leg_y + leg_h + leg_dy
            ], fill=BLACK, outline=DARK_OUTLINE)
    else:
        # Standing: 4 short stubby legs
        for lx_offset in [-20, -8, 8, 20]:
            leg_x = x + int(lx_offset * s)
            leg_y = body_cy + int(body_h * 0.4)
            # Outline
            draw.ellipse([
                leg_x - leg_w//2 - 1, leg_y - 1,
                leg_x + leg_w//2 + 1, leg_y + leg_h + 1
            ], fill=DARK_OUTLINE)
            draw.ellipse([
                leg_x - leg_w // 2, leg_y,
                leg_x + leg_w // 2, leg_y + leg_h
            ], fill=BLACK)

    # === BODY ===
    body_bbox = [
        x - body_w, body_cy - body_h,
        x + body_w, body_cy + body_h
    ]
    draw.ellipse([b - 2 for b in body_bbox[:2]] + [b + 2 for b in body_bbox[2:]],
                 fill=DARK_OUTLINE)
    draw.ellipse(body_bbox, fill=BLACK)

    # === HEAD ===
    head_cx = x + x_shift + int(head_tilt * 0.3 * s)

    # Head outline
    draw.ellipse([
        head_cx - head_r - 3, head_cy - head_r - 3,
        head_cx + head_r + 3, head_cy + head_r + 3
    ], fill=DARK_OUTLINE)
    draw.ellipse([
        head_cx - head_r, head_cy - head_r,
        head_cx + head_r, head_cy + head_r
    ], fill=BLACK)

    # === EARS (bigger, more prominent, on top of head) ===
    ear_h = int(26 * s)  # Taller ears
    ear_w = int(16 * s)

    # Left ear - tall triangle pointing up-left
    lex = head_cx - int(24 * s)
    ley_base = head_cy - int(30 * s)  # Base at top of head
    ley_tip = ley_base - ear_h  # Tip extends above
    ear_l = [
        (lex - int(3 * s), ley_tip),              # Tip
        (lex + ear_w, ley_base + int(8 * s)),      # Bottom-right
        (lex - int(ear_w * 0.6), ley_base + int(5 * s))  # Bottom-left
    ]
    draw.polygon(ear_l, fill=BLACK, outline=DARK_OUTLINE)
    # Green inner ear (left) - 罗小黑's ears have green inside
    inner_l = [
        (lex - int(1 * s), ley_tip + int(6 * s)),
        (lex + int(ear_w * 0.6), ley_base + int(6 * s)),
        (lex - int(ear_w * 0.3), ley_base + int(4 * s))
    ]
    draw.polygon(inner_l, fill=GREEN_MARK)

    # Right ear - tall triangle pointing up-right
    rex = head_cx + int(24 * s)
    rey_base = head_cy - int(30 * s)
    rey_tip = rey_base - ear_h
    ear_r = [
        (rex + int(3 * s), rey_tip),
        (rex - ear_w, rey_base + int(8 * s)),
        (rex + int(ear_w * 0.6), rey_base + int(5 * s))
    ]
    draw.polygon(ear_r, fill=BLACK, outline=DARK_OUTLINE)
    # Green inner ear (right)
    inner_r = [
        (rex + int(1 * s), rey_tip + int(6 * s)),
        (rex - int(ear_w * 0.6), rey_base + int(6 * s)),
        (rex + int(ear_w * 0.3), rey_base + int(4 * s))
    ]
    draw.polygon(inner_r, fill=GREEN_MARK)

    # Redraw head top portion over ear bases for clean overlap
    # Use a clipped ellipse by drawing the head again
    draw.ellipse([
        head_cx - head_r, head_cy - head_r,
        head_cx + head_r, head_cy + head_r
    ], fill=BLACK)

    # Re-draw ear tips above head (they should stick out)
    # Only the parts above the head circle need redrawing
    draw.polygon(ear_l, fill=BLACK, outline=DARK_OUTLINE)
    draw.polygon(inner_l, fill=GREEN_MARK)
    draw.polygon(ear_r, fill=BLACK, outline=DARK_OUTLINE)
    draw.polygon(inner_r, fill=GREEN_MARK)

    # Now redraw the top half of the head to cover ear bases
    # We'll use a chord/pie approach - draw a filled arc for the top of head
    head_cover_top = head_cy - int(head_r * 0.3)
    draw.ellipse([
        head_cx - head_r, head_cy - head_r,
        head_cx + head_r, head_cy + head_r
    ], fill=BLACK)
    # The ears are drawn OVER the head, so we need to re-expose them
    # Draw ears again but only the tips that are above head boundary
    for ear_pts, inner_pts in [(ear_l, inner_l), (ear_r, inner_r)]:
        draw.polygon(ear_pts, fill=BLACK)
        draw.polygon(inner_pts, fill=GREEN_MARK)
        # Outline just the ear edges
        draw.line([ear_pts[0], ear_pts[1]], fill=DARK_OUTLINE, width=2)
        draw.line([ear_pts[0], ear_pts[2]], fill=DARK_OUTLINE, width=2)

    # === GREEN FOREHEAD MARK (diamond/triangle) ===
    mark_cx = head_cx + int(head_tilt * 0.2)
    mark_cy = head_cy - int(14 * s)
    mark_h = int(12 * s)
    mark_w = int(8 * s)

    # Diamond shape (more like the original)
    mark_points = [
        (mark_cx, mark_cy - mark_h // 2),           # Top
        (mark_cx + mark_w // 2, mark_cy + int(2 * s)),  # Right
        (mark_cx, mark_cy + mark_h // 2),            # Bottom
        (mark_cx - mark_w // 2, mark_cy + int(2 * s))   # Left
    ]
    draw.polygon(mark_points, fill=GREEN_MARK, outline=GREEN_DARK)

    # === EYES ===
    eye_y = head_cy + int(5 * s)
    eye_lx = head_cx - int(18 * s) + int(head_tilt * 0.15)
    eye_rx = head_cx + int(18 * s) + int(head_tilt * 0.15)
    eye_w = int(16 * s)  # Eye half-width - BIGGER
    eye_h = int(18 * s)  # Eye half-height - BIGGER

    if eye_state == 'open':
        for ex in [eye_lx, eye_rx]:
            # Eye outline (dark rim)
            draw.ellipse([
                ex - eye_w - 3, eye_y - eye_h - 3,
                ex + eye_w + 3, eye_y + eye_h + 3
            ], fill=EYE_OUTLINE)
            # White of eye
            draw.ellipse([
                ex - eye_w, eye_y - eye_h,
                ex + eye_w, eye_y + eye_h
            ], fill=EYE_WHITE)
            # Pupil (bigger)
            pupil_r = int(7 * s)
            px = ex + int(pupil_dx * 6 * s)
            py = eye_y + int(pupil_dy * 5 * s) + int(2 * s)
            draw.ellipse([
                px - pupil_r, py - pupil_r,
                px + pupil_r, py + pupil_r
            ], fill=PUPIL)
            # Highlight (two spots for cute look)
            hl_r = int(3.5 * s)
            draw.ellipse([
                px - pupil_r + 1, py - pupil_r + 1,
                px - pupil_r + 1 + int(hl_r), py - pupil_r + 1 + int(hl_r)
            ], fill=PUPIL_HIGHLIGHT)
            hl_r2 = int(2 * s)
            draw.ellipse([
                px + int(2 * s), py + int(2 * s),
                px + int(2 * s) + hl_r2, py + int(2 * s) + hl_r2
            ], fill=(255, 255, 255, 150))

    elif eye_state == 'closed':
        for ex in [eye_lx, eye_rx]:
            # Closed eyes: gentle curved lines
            ey = eye_y + int(2 * s)
            draw.arc([
                ex - eye_w, ey - int(6 * s),
                ex + eye_w, ey + int(6 * s)
            ], start=200, end=340, fill=EYE_WHITE, width=int(3 * s))

    elif eye_state == 'happy':
        for ex in [eye_lx, eye_rx]:
            # Happy squint eyes (upside-down U)
            ey = eye_y
            draw.arc([
                ex - int(eye_w * 0.8), ey - int(eye_h * 0.6),
                ex + int(eye_w * 0.8), ey + int(6 * s)
            ], start=15, end=165, fill=EYE_WHITE, width=int(3.5 * s))

    elif eye_state == 'half':
        for ex in [eye_lx, eye_rx]:
            half_h = int(eye_h * 0.5)
            draw.ellipse([
                ex - eye_w - 2, eye_y + int(2*s) - 2,
                ex + eye_w + 2, eye_y + int(2*s) + half_h + 2
            ], fill=EYE_OUTLINE)
            draw.ellipse([
                ex - eye_w, eye_y + int(2*s),
                ex + eye_w, eye_y + int(2*s) + half_h
            ], fill=EYE_WHITE)
            pupil_r = int(5 * s)
            draw.ellipse([
                ex - pupil_r, eye_y + int(4*s),
                ex + pupil_r, eye_y + int(4*s) + pupil_r
            ], fill=PUPIL)

    # === BLUSH ===
    if blush:
        blush_r = int(9 * s)
        for bx_off in [-24, 24]:
            bx = head_cx + int(bx_off * s)
            by = eye_y + int(16 * s)
            draw.ellipse([
                bx - blush_r, by - blush_r // 2,
                bx + blush_r, by + blush_r // 2
            ], fill=BLUSH)

    # === NOSE & MOUTH ===
    nose_y = eye_y + int(18 * s)
    nose_x = head_cx + int(head_tilt * 0.1)

    if mouth_state == 'normal':
        nr = int(3 * s)
        draw.polygon([
            (nose_x, nose_y - nr),
            (nose_x - nr, nose_y + nr // 2),
            (nose_x + nr, nose_y + nr // 2)
        ], fill=NOSE)
        # Vertical line from nose
        draw.line([
            (nose_x, nose_y + nr // 2),
            (nose_x, nose_y + int(5 * s))
        ], fill=MOUTH_LINE, width=max(int(1.5 * s), 1))
        # W mouth
        mw = int(7 * s)
        my = nose_y + int(5 * s)
        draw.line([
            (nose_x - mw, my),
            (nose_x - mw // 3, my + int(3 * s)),
            (nose_x, my),
            (nose_x + mw // 3, my + int(3 * s)),
            (nose_x + mw, my)
        ], fill=MOUTH_LINE, width=max(int(1.5 * s), 1))

    elif mouth_state in ('open', 'meow'):
        nr = int(3 * s)
        draw.polygon([
            (nose_x, nose_y - nr),
            (nose_x - nr, nose_y + nr // 2),
            (nose_x + nr, nose_y + nr // 2)
        ], fill=NOSE)
        mouth_w = int(9 * s) if mouth_state == 'meow' else int(7 * s)
        mouth_h = int(7 * s) if mouth_state == 'meow' else int(5 * s)
        my = nose_y + int(7 * s)
        draw.ellipse([
            nose_x - mouth_w, my - mouth_h,
            nose_x + mouth_w, my + mouth_h
        ], fill=(60, 30, 30, 255), outline=MOUTH_LINE, width=2)

    elif mouth_state == 'smile':
        nr = int(3 * s)
        draw.polygon([
            (nose_x, nose_y - nr),
            (nose_x - nr, nose_y + nr // 2),
            (nose_x + nr, nose_y + nr // 2)
        ], fill=NOSE)
        sw = int(10 * s)
        my = nose_y + int(3 * s)
        draw.arc([
            nose_x - sw, my - int(5 * s),
            nose_x + sw, my + int(5 * s)
        ], start=10, end=170, fill=MOUTH_LINE, width=int(2 * s))

    # === SLEEP Z BUBBLES ===
    for zx, zy, zs in z_bubbles:
        zx_abs = head_cx + int(zx * s)
        zy_abs = head_cy + int(zy * s)
        fs = max(int(zs * s * 0.8), 10)
        # Draw styled Z
        draw.text((zx_abs, zy_abs), "Z", fill=(180, 200, 230, int(200 - zs * 3)))


def generate_idle_frames(output_dir, count=12):
    """Idle: subtle breathing + tail sway + occasional blink."""
    for i in range(count):
        img = Image.new('RGBA', (SIZE, SIZE), TRANSPARENT)
        t = i / count
        phase = t * math.pi * 2

        # Breathing: slight body squash
        breath = 1.0 + math.sin(phase) * 0.02

        # Tail sway
        tail_phase = phase * 0.5

        # Blink on frames 5-6
        eye = 'open'
        if i == 5:
            eye = 'half'
        elif i == 6:
            eye = 'closed'

        draw_xiaohei(img, {
            'body_squash': breath,
            'body_stretch': 1.0 + math.sin(phase) * 0.01,
            'tail_phase': tail_phase,
            'tail_up': 0.4 + math.sin(phase * 0.3) * 0.1,
            'eye_state': eye,
            'mouth_state': 'normal',
            'pupil_dx': math.sin(phase * 0.2) * 0.2,
            'pupil_dy': 0,
        })

        img.save(os.path.join(output_dir, f'idle_{i:03d}.png'))


def generate_walk_frames(output_dir, count=8):
    """Walking: body sways, legs alternate, tail bounces."""
    for i in range(count):
        img = Image.new('RGBA', (SIZE, SIZE), TRANSPARENT)
        t = i / count
        phase = t * math.pi * 2

        # Body bob
        bob_y = math.sin(phase * 2) * 3

        draw_xiaohei(img, {
            'y': CENTER_Y + 15 + int(bob_y),
            'body_squash': 0.95 + math.sin(phase * 2) * 0.05,
            'tail_phase': phase,
            'tail_up': 0.5 + math.sin(phase) * 0.2,
            'eye_state': 'open',
            'mouth_state': 'normal',
            'walking': True,
            'leg_phase': phase,
            'head_tilt': math.sin(phase) * 3,
            'pupil_dx': 0.3,  # Looking forward
        })

        img.save(os.path.join(output_dir, f'walk_{i:03d}.png'))


def generate_sleep_frames(output_dir, count=10):
    """Sleeping: closed eyes, slow breathing, z bubbles float up."""
    for i in range(count):
        img = Image.new('RGBA', (SIZE, SIZE), TRANSPARENT)
        t = i / count
        phase = t * math.pi * 2

        # Very slow breathing
        breath = 1.0 + math.sin(phase * 0.5) * 0.03

        # Z bubbles floating upward
        z_list = []
        for zi in range(3):
            zt = (t + zi * 0.33) % 1.0
            zx = 35 + zi * 8 + math.sin(zt * math.pi * 2) * 5
            zy = -20 - zt * 50
            zs = 10 + zi * 4
            z_list.append((zx, zy, zs))

        draw_xiaohei(img, {
            'sleeping': True,
            'body_squash': breath,
            'tail_phase': phase * 0.2,
            'tail_up': 0.1,
            'eye_state': 'closed',
            'mouth_state': 'normal',
            'z_bubbles': z_list,
        })

        img.save(os.path.join(output_dir, f'sleep_{i:03d}.png'))


def generate_happy_frames(output_dir, count=10):
    """Happy: bouncing, happy eyes, blushing."""
    for i in range(count):
        img = Image.new('RGBA', (SIZE, SIZE), TRANSPARENT)
        t = i / count
        phase = t * math.pi * 2

        # Bouncing
        bounce = abs(math.sin(phase)) * 10
        # Squash & stretch
        if math.sin(phase) > 0:
            squash = 0.9
            stretch = 1.1
        else:
            squash = 1.1
            stretch = 0.9

        draw_xiaohei(img, {
            'y': CENTER_Y + 15 - int(bounce),
            'body_squash': squash,
            'body_stretch': stretch,
            'tail_phase': phase * 2,
            'tail_up': 0.7,
            'eye_state': 'happy',
            'mouth_state': 'smile',
            'blush': True,
            'head_tilt': math.sin(phase) * 5,
        })

        img.save(os.path.join(output_dir, f'happy_{i:03d}.png'))


def generate_stretch_frames(output_dir, count=12):
    """Stretch: cat stretch animation."""
    for i in range(count):
        img = Image.new('RGBA', (SIZE, SIZE), TRANSPARENT)
        t = i / count

        if t < 0.3:
            # Crouch down
            progress = t / 0.3
            squash = 1.0 + progress * 0.2
            stretch = 1.0 - progress * 0.1
            eye = 'half'
        elif t < 0.6:
            # Stretch up
            progress = (t - 0.3) / 0.3
            squash = 1.2 - progress * 0.5
            stretch = 0.9 + progress * 0.2
            eye = 'closed'
        else:
            # Return to normal
            progress = (t - 0.6) / 0.4
            squash = lerp(0.7, 1.0, ease_in_out(progress))
            stretch = lerp(1.1, 1.0, ease_in_out(progress))
            eye = 'open' if progress > 0.5 else 'half'

        draw_xiaohei(img, {
            'body_squash': squash,
            'body_stretch': stretch,
            'tail_phase': t * math.pi,
            'tail_up': 0.3 + t * 0.3,
            'eye_state': eye,
            'mouth_state': 'open' if 0.2 < t < 0.5 else 'normal',
        })

        img.save(os.path.join(output_dir, f'stretch_{i:03d}.png'))


def generate_look_around_frames(output_dir, count=12):
    """Look around: head turns, eyes follow, ears perk."""
    for i in range(count):
        img = Image.new('RGBA', (SIZE, SIZE), TRANSPARENT)
        t = i / count
        phase = t * math.pi * 2

        # Head turns left then right
        head_tilt = math.sin(phase) * 15
        # Eyes track with head
        pupil_dx = math.sin(phase) * 0.8
        pupil_dy = math.cos(phase * 0.5) * 0.3

        draw_xiaohei(img, {
            'head_tilt': head_tilt,
            'pupil_dx': pupil_dx,
            'pupil_dy': pupil_dy,
            'tail_phase': phase * 0.3,
            'tail_up': 0.5,
            'eye_state': 'open',
            'mouth_state': 'normal',
        })

        img.save(os.path.join(output_dir, f'lookAround_{i:03d}.png'))


def generate_talking_frames(output_dir, count=8):
    """Talking: mouth opens and closes, body sways slightly."""
    for i in range(count):
        img = Image.new('RGBA', (SIZE, SIZE), TRANSPARENT)
        t = i / count
        phase = t * math.pi * 2

        # Mouth alternates open/closed
        mouth = 'meow' if i % 3 != 0 else 'normal'

        draw_xiaohei(img, {
            'body_squash': 1.0 + math.sin(phase) * 0.02,
            'tail_phase': phase * 0.5,
            'tail_up': 0.4,
            'eye_state': 'open',
            'mouth_state': mouth,
            'head_tilt': math.sin(phase * 0.5) * 3,
            'pupil_dx': -0.2,  # Looking at user
            'pupil_dy': -0.1,
        })

        img.save(os.path.join(output_dir, f'talking_{i:03d}.png'))


def generate_thinking_frames(output_dir, count=10):
    """Thinking: head tilts, eyes look up, dots appear."""
    for i in range(count):
        img = Image.new('RGBA', (SIZE, SIZE), TRANSPARENT)
        draw = ImageDraw.Draw(img)
        t = i / count
        phase = t * math.pi * 2

        draw_xiaohei(img, {
            'head_tilt': 8 + math.sin(phase) * 3,
            'pupil_dx': 0.5,
            'pupil_dy': -0.6,
            'tail_phase': phase * 0.3,
            'tail_up': 0.3,
            'eye_state': 'open',
            'mouth_state': 'normal',
            'body_squash': 1.0 + math.sin(phase) * 0.01,
        })

        # Thinking dots above head
        dot_count = (i % 4)  # 0, 1, 2, 3 dots cycling
        dot_x_base = CENTER_X + 30
        dot_y_base = CENTER_Y - 55
        for d in range(min(dot_count, 3)):
            dx = dot_x_base + d * 10
            dy = dot_y_base + int(math.sin(phase + d) * 3)
            draw.ellipse([dx - 3, dy - 3, dx + 3, dy + 3], fill=(200, 200, 200, 200))

        img.save(os.path.join(output_dir, f'thinking_{i:03d}.png'))


def generate_fall_frames(output_dir, count=8):
    """Fall: spinning/tumbling down, then landing."""
    for i in range(count):
        img = Image.new('RGBA', (SIZE, SIZE), TRANSPARENT)
        t = i / count

        if t < 0.6:
            # Falling with spin
            progress = t / 0.6
            fall_y = progress * 40
            tilt = progress * 30
            eye = 'open'  # Surprised
            squash = 1.0
        elif t < 0.75:
            # Impact squash
            progress = (t - 0.6) / 0.15
            fall_y = 40
            tilt = lerp(30, 0, progress)
            squash = 1.3
            eye = 'closed'
        else:
            # Recover
            progress = (t - 0.75) / 0.25
            fall_y = lerp(40, 0, ease_in_out(progress))
            tilt = 0
            squash = lerp(1.3, 1.0, ease_in_out(progress))
            eye = 'half' if progress < 0.5 else 'open'

        draw_xiaohei(img, {
            'y': CENTER_Y + 15 + int(fall_y),
            'head_tilt': tilt,
            'body_squash': squash,
            'body_stretch': 2.0 - squash,
            'tail_phase': t * math.pi * 4,
            'tail_up': 0.8 - t * 0.5,
            'eye_state': eye,
            'mouth_state': 'open' if t < 0.75 else 'normal',
        })

        img.save(os.path.join(output_dir, f'fall_{i:03d}.png'))


def main():
    """Generate all animation frames."""
    # Output directory
    output_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                              'Xiaohei', 'Xiaohei', 'AnimationFrames')

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    print(f"Generating frames to: {output_dir}")

    # Note: overwriting existing files (not deleting first)

    generators = [
        ("idle", generate_idle_frames, 12),
        ("walk", generate_walk_frames, 8),
        ("sleep", generate_sleep_frames, 10),
        ("happy", generate_happy_frames, 10),
        ("stretch", generate_stretch_frames, 12),
        ("lookAround", generate_look_around_frames, 12),
        ("talking", generate_talking_frames, 8),
        ("thinking", generate_thinking_frames, 10),
        ("fall", generate_fall_frames, 8),
    ]

    total = 0
    for name, gen_func, count in generators:
        print(f"  Generating {name} ({count} frames)...")
        gen_func(output_dir, count)
        total += count

    print(f"\nDone! Generated {total} frames total.")
    print(f"Output: {output_dir}")


if __name__ == '__main__':
    main()
