"""Prepares the website's images and fonts from the game's store assets.

    flutter test tool/website/render_art_test.dart   # sweets and blockers
    python3 tool/website/build_assets.py

Writes small WebP/PNG/WOFF files into website/assets/.
"""
import pathlib

from fontTools.ttLib import TTFont
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
STORE = ROOT / "store_assets"
OUT = ROOT / "website" / "assets"

SHOTS = [
    "1_home", "2_map", "3_combo", "4_board", "5_blockers", "6_win",
    "7_daily", "8_spin", "9_swirl_combo", "10_nuts", "11_booster", "12_hard_level",
]


def webp(src, dst, width=None, quality=82):
    im = Image.open(src)
    im = im.convert("RGBA" if im.mode in ("RGBA", "LA", "P") else "RGB")
    if width and im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "WEBP", quality=quality, method=6)


def png(src, dst, size):
    im = Image.open(src).convert("RGBA").resize((size, size), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "PNG", optimize=True)


def main():
    for name in SHOTS:
        webp(STORE / "raw" / f"{name}.png", OUT / "shots" / f"{name}.webp", width=540, quality=80)
    webp(STORE / "logo" / "logo_vertical_transparent.png", OUT / "logo.webp", width=720, quality=88)
    webp(STORE / "logo" / "logo_horizontal_transparent.png", OUT / "logo-wide.webp", width=480, quality=88)

    icon = STORE / "logo" / "app_icon_1024.png"
    png(icon, OUT / "icon-32.png", 32)
    png(icon, OUT / "icon-180.png", 180)
    png(icon, OUT / "icon-192.png", 192)
    png(icon, OUT / "icon-512.png", 512)
    webp(icon, OUT / "icon-96.webp", width=96, quality=90)

    Image.open(STORE / "banners" / "social_share_1200x628.png").convert("RGB").save(
        OUT / "og-image.jpg", "JPEG", quality=86, optimize=True, progressive=True)

    for art in sorted((OUT / "art").glob("*.png")):
        webp(art, art.with_suffix(".webp"), quality=90)
        art.unlink()

    fonts = OUT / "fonts"
    fonts.mkdir(parents=True, exist_ok=True)
    for name in ["Baloo2-ExtraBold", "Nunito-Regular", "Nunito-Bold", "Nunito-ExtraBold"]:
        f = TTFont(ROOT / "assets" / "fonts" / f"{name}.ttf")
        f.flavor = "woff"
        f.save(fonts / f"{name}.woff")
    for lic in ["Baloo2-OFL.txt", "Nunito-OFL.txt"]:
        (fonts / lic).write_text((ROOT / "assets" / "fonts" / lic).read_text())

    total = sum(p.stat().st_size for p in OUT.rglob("*") if p.is_file())
    print(f"website assets: {total / 1024:.0f} KB")


if __name__ == "__main__":
    main()
