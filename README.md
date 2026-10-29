# Toffee Twist: Sweet Match 3

An original, cozy match-3 puzzle game for Android, made with **Flutter** and
the **Flame** game engine. Package name: `com.toffetwist.toffeetwist`.

- 6 sweets with different shapes and colors (colorblind friendly), all drawn in code
- Striped Toffee, Sweet Box and Toffee Swirl specials, plus special+special combos
- Goals: score, collect, caramel (1-2 layers), wooden crates (1-3 hits), golden nuts
- 500 levels: 30 hand-made tutorial levels + 470 generated and bot-tested levels
- Map of 25 sweet shops, lives, coins, boosters, 7-day rewards, free daily spin
- AdMob ads (test IDs), Google consent form (UMP), Google Play in-app purchases
- Works offline, no login; progress saved on the phone

## Folder structure

| Folder | What is inside |
|---|---|
| `lib/game/logic/` | The match-3 rules in plain Dart (board, matching, specials, gravity, goals, level JSON) |
| `lib/game/flame/` | The Flame board: animations, pooled particles, effects, input |
| `lib/game/render/` | Code-drawn artwork for every sweet, special and blocker |
| `lib/levels/` | Level loading, the level generator and the greedy bot simulator |
| `lib/screens/` | Home, map, game, shop, settings screens and dialogs |
| `lib/services/` | Saved progress, sounds, vibration, ads, in-app purchases |
| `lib/config/` | **Settings you edit**: `ads_config.dart`, `iap_config.dart`, `app_config.dart` |
| `assets/levels/` | `level_0001.json` ... `level_0500.json` |
| `assets/audio/` | Generated sound effects and music |
| `test/` | Unit and widget tests |
| `tool/` | Level builder, audio generator, icon/store-graphic renderers |
| `docs/` | Privacy policy (Markdown + HTML) |
| `store_assets/` | Play Store icon, feature graphic and screenshots |

## Run it

```bash
flutter pub get
```
```bash
flutter run
```
(with an Android phone connected by USB, or an emulator started from Android Studio)

Run all tests:
```bash
flutter test
```

## Things you will edit before publishing
1. `lib/config/ads_config.dart` - your real AdMob IDs, then `useTestAds = false`
2. `lib/config/iap_config.dart` - product IDs (must match Play Console)
3. `lib/config/app_config.dart` - your privacy policy URL and support e-mail
4. `docs/privacy_policy.md` / `.html` - replace `[YOUR EMAIL]`

Then follow **RELEASE_GUIDE.md** to sign and build the `.aab`.

## Levels
Each level is a JSON file. Board rows use: `.` cell, `#` hole, `c`/`C` caramel
(1/2 layers), `1`-`3` crate hits, `n` golden nut start. See the comment at the
top of `lib/game/logic/level.dart` for every field.

Rebuild or re-check levels (needs the Flutter SDK's `dart`):
```bash
python3 tool/levels/hand_levels.py
```
```bash
dart run tool/build_levels.dart all
```
`tune-hand` tunes levels 1-30, `generate` makes levels 31-500 (the bot plays
each 50 times; normal levels must have a 60-85% bot win rate, hard levels
30-50%, unsolvable ones are regenerated) and `report` writes
`levels_report.csv`.

## Other tools
| Command | What it does |
|---|---|
| `python3 tool/gen_audio.py` | Re-creates all sounds and the music (CC0) |
| `flutter test tool/branding/render_branding_test.dart` | Re-renders icon, splash and feature graphic |
| `dart run flutter_launcher_icons` | Builds the Android app icons from `branding/` |
| `dart run flutter_native_splash:create` | Builds the splash screen |
| `node tool/store/capture_screenshots.js` + `python3 tool/store/frame_screenshots.py` | Store screenshots from the web build |
| `flutter test tool/branding/render_marketing_test.dart` | Logo files and promo banners (`store_assets/logo`, `store_assets/banners`) |
| `python3 tool/store/flatten_png.py <files>` | Removes transparency (needed for the feature graphic and banners) |

The web build is only used for testing and screenshots:
`flutter build web --release --no-web-resources-cdn`. Open it with
`?level=12` to jump to a level.

See `CREDITS.md` for licenses, `STORE_LISTING.md` for the store texts and
`DATA_SAFETY.md` for the Play Console forms.
