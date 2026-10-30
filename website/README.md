# Toffee Twist website

A static information page about the game (no build step). Vercel serves this
folder as it is (`cleanUrls`: `/privacy` serves `privacy.html`).

- `index.html`, `privacy.html`, `404.html`, `styles.css`
- `assets/` is generated - rerun after the game art or screenshots change:
  ```bash
  flutter test tool/website/render_art_test.dart
  python3 tool/website/build_assets.py
  ```

Preview locally: `cd website && python3 -m http.server 8090`, then open
http://localhost:8090 (clean URLs like `/privacy` only work on Vercel; locally
use `/privacy.html`).
