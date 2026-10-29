#!/usr/bin/env python3
"""Removes the alpha channel from PNGs (Google Play wants the feature graphic
and screenshots without transparency).

Run: python3 tool/store/flatten_png.py store_assets/feature_graphic.png store_assets/banners/*.png
"""
import sys

from PIL import Image

for path in sys.argv[1:]:
    im = Image.open(path)
    if im.mode != 'RGB':
        im.convert('RGB').save(path, optimize=True)
        print('flattened', path)
