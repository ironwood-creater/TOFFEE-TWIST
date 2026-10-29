#!/usr/bin/env python3
"""Adds a caption band to the raw screenshots for the Play Store.

Run: python3 tool/store/frame_screenshots.py store_assets/raw store_assets/screenshots
Output: 1080x1920 24-bit PNGs (no transparency), as Google Play wants.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
FONT = os.path.join(ROOT, 'assets', 'fonts', 'Baloo2-ExtraBold.ttf')

CAPTIONS = {
    '1_home.png': 'A cozy sweet-shop\npuzzle adventure',
    '2_map.png': '500 levels in\n25 sweet shops',
    '3_combo.png': 'Swap specials together\nfor giant combos!',
    '4_board.png': 'Striped Toffees, Sweet Boxes\n& Toffee Swirls',
    '5_blockers.png': 'Caramel, crates, golden nuts\nand fun board shapes',
    '6_win.png': 'Earn stars\nand coins',
    '7_daily.png': 'Sweet daily\nlogin rewards',
    '8_spin.png': 'A free spin\nevery day!',
}

W, H = 1080, 1920
BAND = 330


def background():
    img = Image.new('RGB', (W, H))
    top, bottom = (255, 227, 179), (232, 162, 59)
    d = ImageDraw.Draw(img)
    for y in range(H):
        k = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3)))
    dots = ImageDraw.Draw(img, 'RGBA')
    step = 90
    for row, y in enumerate(range(30, H, step)):
        for x in range(30 if row % 2 == 0 else 75, W, step):
            dots.ellipse((x - 9, y - 9, x + 9, y + 9), fill=(255, 255, 255, 46))
    return img


def caption(img, text):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, 84)
    lines = text.split('\n')
    y = 46 if len(lines) == 2 else 110
    for line in lines:
        w = d.textlength(line, font=font)
        while w > W - 80:
            font = ImageFont.truetype(FONT, font.size - 4)
            w = d.textlength(line, font=font)
        x = (W - w) / 2
        d.text((x, y), line, font=font, fill=(255, 236, 160), stroke_width=10, stroke_fill=(59, 31, 18))
        y += 120


def frame(raw_path, out_path, text):
    shot = Image.open(raw_path).convert('RGB')
    img = background()
    caption(img, text)
    avail_h = H - BAND - 50
    scale = avail_h / shot.height
    sw, sh = int(shot.width * scale), int(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    x, y = (W - sw) // 2, BAND
    radius = 48
    # shadow
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x - 8, y + 6, x + sw + 8, y + sh + 22), radius + 8, fill=(0, 0, 0, 110))
    img = Image.alpha_composite(img.convert('RGBA'), shadow.filter(ImageFilter.GaussianBlur(14)))
    # chocolate frame
    ImageDraw.Draw(img).rounded_rectangle((x - 12, y - 12, x + sw + 12, y + sh + 12), radius + 12, fill=(59, 31, 18))
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), radius, fill=255)
    img.paste(shot, (x, y), mask)
    img.convert('RGB').save(out_path, optimize=True)


def main():
    raw_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    for i, (name, text) in enumerate(CAPTIONS.items(), start=1):
        src = os.path.join(raw_dir, name)
        if not os.path.exists(src):
            print('missing', src)
            continue
        frame(src, os.path.join(out_dir, f'screenshot_{i}.png'), text)
    print('framed screenshots in', out_dir)


if __name__ == '__main__':
    main()
