// Captures raw store screenshots from the web build (see STORE_ASSETS.md).
//   flutter build web --release --no-web-resources-cdn
//   (cd build/web && python3 -m http.server 8080) &
//   node tool/store/capture_screenshots.js http://localhost:8080 store_assets/raw
// Needs Node.js with Playwright (Chromium).
const { chromium } = require('playwright');
const path = require('path');

const [base = 'http://localhost:8080', outDir = 'store_assets/raw', ...only] = process.argv.slice(2);
const W = 432, H = 768, SCALE = 2.5; // -> 1080 x 1920

function day(offset) {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  return d.toISOString().slice(0, 10);
}

function progress({ levels = 0, dailyIndex = 0, lastDaily = day(0), coins = 1480, spin = day(-1) } = {}) {
  const stars = [];
  for (let i = 0; i < levels; i++) stars.push([3, 3, 2, 3, 2, 3, 1, 3][i % 8]);
  return {
    stars, best: stars.map(s => s * 4000), coins, lives: 5, lifeTimer: Date.now(),
    boosters: { rollingPin: 3, freeSwap: 2, startBox: 1, extraMoves: 2 },
    dailyIndex, lastDaily, lastFreeSpin: spin, lastAdSpin: '', music: true, sound: true,
    vibration: true, removeAds: false, tutorials: ['level_1', 'level_4', 'level_9', 'level_27', 'level_57'],
    sinceAd: 0, finished: levels, delivered: [],
  };
}

async function shot(browser, name, url, save, actions = []) {
  if (only.length && !only.some((o) => name.startsWith(o))) return;
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: SCALE });
  await ctx.addInitScript(([key, value]) => {
    window.localStorage.setItem(key, value);
  }, ['flutter.toffee_twist_progress_v1', JSON.stringify(JSON.stringify(save))]);
  const page = await ctx.newPage();
  await page.goto(base + url);
  await page.waitForTimeout(5000);
  for (const a of actions) {
    if (a.click) await page.mouse.click(a.click[0], a.click[1]);
    if (a.drag) {
      const [x1, y1, x2, y2] = a.drag;
      await page.mouse.move(x1, y1);
      await page.mouse.down();
      for (let i = 1; i <= 6; i++) await page.mouse.move(x1 + (x2 - x1) * i / 6, y1 + (y2 - y1) * i / 6);
      await page.mouse.up();
    }
    if (a.wait) await page.waitForTimeout(a.wait);
    if (a.shot) await page.screenshot({ path: path.join(outDir, a.shot) });
  }
  if (name) await page.screenshot({ path: path.join(outDir, name) });
  await ctx.close();
}

(async () => {
  require('fs').mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  // 1 Home
  await shot(browser, '1_home.png', '/', progress({ levels: 36 }));
  // 2 Map with stars
  await shot(browser, '2_map.png', '/', progress({ levels: 36 }), [{ click: [W / 2, 0] }, { wait: 300 }, { click: [216, 595] }, { wait: 2500 }]);
  // 3 Combo in slow motion: two Striped Toffees swapped together
  await shot(browser, '3_combo.png', '/?level=9&seed=4&slowmo=0.08', progress({ levels: 8 }), [
    { drag: [190, 433, 241, 433] }, { wait: 650 },
  ]);
  // 4 Board with a Toffee Swirl and a Striped Toffee, hint glowing
  await shot(browser, '4_board.png', '/?level=24&seed=11', { ...progress({ levels: 23 }), tutorials: ['level_24'] }, [{ wait: 6500 }]);
  // 5 Blockers: caramel, crates, nut on a heart board
  await shot(browser, '5_blockers.png', '/?level=27&seed=2', progress({ levels: 26 }));
  // 6 Win
  await shot(browser, '6_win.png', '/?test=win&seed=5', progress({ levels: 6 }), [{ drag: [281, 450, 230, 450] }, { wait: 6500 }]);
  // 7 Daily reward (day 4 ready)
  await shot(browser, '7_daily.png', '/', progress({ levels: 36, dailyIndex: 3, lastDaily: day(-1) }));
  // 8 Spin wheel
  await shot(browser, '8_spin.png', '/', progress({ levels: 36 }), [{ click: [167, 705] }, { wait: 1200 }]);
  // 9 Toffee Swirl + Striped Toffee: every cupcake turns striped and fires (slow motion)
  await shot(browser, '9_swirl_combo.png', '/?level=24&seed=11&slowmo=0.08', { ...progress({ levels: 23 }), tutorials: ['level_24'] }, [
    { drag: [171, 408, 216, 408] }, { wait: 5200 },
  ]);
  // 10 Golden nuts and crates on a plus-shaped board
  await shot(browser, '10_nuts.png', '/?level=28&seed=6', progress({ levels: 27 }));
  // 11 Rolling Pin booster selected during play
  await shot(browser, '11_booster.png', '/?level=30&seed=3', progress({ levels: 29 }), [{ click: [44, 728] }, { wait: 900 }]);
  // 12 Start-of-level popup for a hard level with start boosters
  await shot(browser, '12_hard_level.png', '/', progress({ levels: 39 }), [{ click: [216, 528] }, { wait: 2800 }]);
  await browser.close();
})();
