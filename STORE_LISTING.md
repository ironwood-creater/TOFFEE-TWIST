# Google Play store listing

Copy these into **Play Console > Grow users > Store presence > Main store listing**.

## App name (max 30 characters)
```
Toffee Twist: Sweet Match 3
```
(27 characters)

## Short description (max 80 characters)
```
Swap sweets, fire striped toffees and clear 500 cozy match-3 levels!
```
(68 characters)

## Full description (max 4000 characters)
```
Welcome to Toffee Twist, a cozy sweet-shop puzzle game! Swap neighbouring sweets, line up three or more of a kind and watch them pop. Plan your moves, set off delicious chain reactions and travel through 25 charming sweet shops - from the Toffee Kitchen to the Golden Twist Palace.

SWEET AND SIMPLE TO PLAY
• Swipe or tap two neighbouring sweets to swap them
• Match 3 or more toffees, cupcakes, donuts, macarons, lollipops or chocolates
• Every sweet has its own shape and color, so they are easy to tell apart
• Clear each level's goals before you run out of moves

POWERFUL SPECIAL SWEETS
• Match 4 in a line to make a Striped Toffee that clears a whole row or column
• Match an L or T shape to make a Sweet Box that explodes twice
• Match 5 in a line to make a Toffee Swirl that clears every sweet of one kind
• Swap two specials together for giant combos - even a full-board sweep!

500 HAND-TUNED LEVELS
• Collect sweets, reach target scores and earn up to 3 stars per level
• Melt away caramel tiles, break wooden crates and bring golden nuts to the bottom
• Boards in all kinds of shapes - hearts, diamonds, arches and more
• A gentle tutorial introduces one new idea at a time
• A tough challenge every 10 levels, followed by a relaxing treat

HELPFUL BOOSTERS
• Rolling Pin: smash any one piece
• Free Swap: swap two neighbours without needing a match
• Start with a Sweet Box or 3 extra moves

DAILY TREATS
• A 7-day login calendar with bigger rewards every day
• A free daily spin for coins and boosters
• Lives refill over time, even while the game is closed

PLAY ANYWHERE
• Play offline - no account and no login needed
• Your progress is saved on your device
• Relaxing music and satisfying sound effects

Toffee Twist is free to play. It contains ads and offers optional in-app purchases (coin packs and a one-time "Remove Ads"). The daily spin is always free and can never be bought.

Ready for a sweet twist? Tap Play and start matching!
```

## Category and tags
- **App or game:** Game
- **Category:** Puzzle
- **Tags** (choose up to 5 in Play Console): Match 3, Puzzle, Casual, Offline, Single player
- **Contact email:** [YOUR EMAIL]
- **Privacy policy:** the public URL of `docs/privacy_policy.html`

## Keywords to keep in mind (Play has no keyword field - these words already appear in the description)
match 3, match three, sweet, sweets, toffee, dessert, puzzle, swap, combo,
cupcake, donut, macaron, lollipop, chocolate, bakery, sweet shop, levels,
offline puzzle, casual, relaxing, brain game, boosters, daily rewards

Do NOT use other games' names (or words like "Candy", "Crush" or "Saga") in
the title, description or keywords - that breaks Play's impersonation and
keyword-spam rules.

## Graphics (all in `store_assets/`)

### For the Play Store listing
| Asset | File | Play requirement |
|---|---|---|
| App icon | `store_assets/icon_512.png` | 512 x 512 PNG |
| Feature graphic | `store_assets/feature_graphic.png` (same as `banners/feature_graphic_1024x500.png`) | 1024 x 500 PNG/JPEG, no transparency |
| Phone screenshots (12) | `store_assets/screenshots/screenshot_01.png` ... `screenshot_12.png` | 1080 x 1920 PNG; Play accepts **2-8** per device type |
| Raw screenshots (no captions) | `store_assets/raw/` | alternative set |

Play shows at most **8 phone screenshots**. Recommended order for the phone
slot: **01** (home), **03** (combo), **09** (swirl combo), **05** (blockers),
**10** (golden nuts), **02** (map), **06** (win), **07** (daily reward).
Use the other four (04 specials, 08 spin, 11 boosters, 12 hard level) in the
7-inch / 10-inch tablet slots or on social media.

| # | Screenshot | Caption |
|---|---|---|
| 01 | Home screen | A cozy sweet-shop puzzle adventure |
| 02 | Level map | 500 levels in 25 sweet shops |
| 03 | Striped + Striped combo | Swap specials together for giant combos! |
| 04 | Board with specials | Striped Toffees, Sweet Boxes & Toffee Swirls |
| 05 | Heart board with caramel and crates | Caramel, crates, golden nuts and fun board shapes |
| 06 | Win screen | Earn stars and coins |
| 07 | Daily reward calendar | Sweet daily login rewards |
| 08 | Spin wheel | A free spin every day! |
| 09 | Swirl + Striped combo | Swirl + Striped: fire them all at once! |
| 10 | Golden nuts level | Bring the golden nuts down to the bottom |
| 11 | Rolling Pin booster | Handy boosters when you get stuck |
| 12 | Hard level start popup | A tough challenge every 10 levels |

### Logo (`store_assets/logo/`)
| File | Size | Use |
|---|---|---|
| `logo_vertical_transparent.png` | 1800 x 1450, transparent | Websites, press kit, videos |
| `logo_horizontal_transparent.png` | 2150 x 800, transparent | Website headers, wide spaces |
| `logo_on_background.png` | 1600 x 1600 | Profile pictures, square posts |
| `app_icon_1024.png` | 1024 x 1024 | App icon in high resolution |

### Promo banners (`store_assets/banners/`)
| File | Size | Use |
|---|---|---|
| `feature_graphic_1024x500.png` | 1024 x 500 | Google Play feature graphic |
| `social_share_1200x628.png` | 1200 x 628 | Link previews (Facebook, X, WhatsApp), ads |
| `square_post_1080x1080.png` | 1080 x 1080 | Instagram / Facebook posts |
| `landscape_promo_1920x1080.png` | 1920 x 1080 | YouTube video cover, website hero, trailer end card |
| `header_1500x500.png` | 1500 x 500 | X (Twitter) / profile header |
| `story_1080x1920.png` | 1080 x 1920 | Instagram / TikTok / WhatsApp stories |

All graphics are made from the game's own code-drawn art and real gameplay,
so you own them. Re-create them with:
`flutter test tool/branding/render_branding_test.dart` (icon, feature graphic),
`node tool/store/capture_screenshots.js` + `python3 tool/store/frame_screenshots.py store_assets/raw store_assets/screenshots`
(screenshots) and `flutter test tool/branding/render_marketing_test.dart`
(logo and banners). Then remove transparency from the store/banner images:
`python3 tool/store/flatten_png.py store_assets/feature_graphic.png store_assets/banners/*.png`
