# Release guide: from this project to Google Play

Follow these steps in order. Commands go in a terminal (macOS/Linux:
Terminal; Windows: PowerShell) opened **in the project folder**.

---

## Step 1 - Install the tools (once)

1. **Android Studio** (includes the Android SDK and Java):
   https://developer.android.com/studio - install it, open it once and let it
   download the SDK. In *Settings > Languages & Frameworks > Android SDK*, make
   sure **Android 16 (API 36)** and **Android SDK Command-line Tools** are installed.
2. **Flutter** (stable channel, 3.47 or newer): https://docs.flutter.dev/get-started/install
3. Check everything:
   ```bash
   flutter doctor
   ```
   Fix anything marked with a red cross. Accept the Android licenses:
   ```bash
   flutter doctor --android-licenses
   ```

## Step 2 - Get the code and test it

```bash
git clone https://github.com/ironwood-creater/TOFFEE-TWIST.git
```
```bash
cd TOFFEE-TWIST
```
```bash
flutter pub get
```
```bash
flutter test
```
All tests should pass.

## Step 3 - Play it on your phone

1. On the phone: *Settings > About phone* > tap **Build number** 7 times, then
   *Settings > System > Developer options* > turn on **USB debugging**.
2. Connect the phone with a USB cable and allow the computer.
3. Run:
   ```bash
   flutter run
   ```
You will see **Google's test ads** (labelled "Test Ad") - that is correct.
Purchases only work after the game is installed from Google Play (Step 8).

## Step 4 - Fill in your own details

| File | What to change |
|---|---|
| `lib/config/app_config.dart` | `supportEmail` (the privacy policy address is already set - Step 5) |
| `website/privacy.html` | Optional: add your support e-mail in section 11 (Contact) |
| `lib/config/iap_config.dart` | Keep the IDs, or change them to the IDs you create in Play Console |
| `lib/config/ads_config.dart` | Your real AdMob IDs and `useTestAds = false` (Step 9 - do this last) |
| `pubspec.yaml` | `version: 1.0.0+1` - increase the number after `+` for every upload |

The package name is **com.toffeetwist** (set in `android/app/build.gradle.kts`,
and the one registered for the game in Play Console). It can never change after
your first upload.

## Step 5 - The privacy policy

Google needs a public web address for it. It is already online on the game's
website, and the game links to it:

**https://toffee-twist.vercel.app/privacy**

The website lives in the `website/` folder and is hosted on Vercel (project
`toffee-twist`). Every push to GitHub updates it automatically. If you change
the policy, edit `website/privacy.html` (and `docs/privacy_policy.md` to keep
the copy in sync).

## Step 6 - Create your upload key (once!)

This key proves that updates come from you.

- macOS / Linux:
  ```bash
  bash tool/release/create_upload_key.sh
  ```
- Windows:
  ```powershell
  powershell -ExecutionPolicy Bypass -File tool\release\create_upload_key.ps1
  ```

It asks for a password and your name, then creates:
- `toffee-twist-upload.jks` in your home folder (the key), and
- `android/key.properties` (tells the build where the key is).

**Back up the `.jks` file and the password** (USB stick + password manager).
Never upload them to GitHub (`key.properties`, `.jks` and `.keystore` files are
already in `.gitignore`). If you ever lose the upload key, Google Play support
can reset it because the game uses *Play App Signing* (Step 8).

## Step 7 - Build the release bundle (.aab)

```bash
flutter build appbundle --release
```
The file is created at:
```
build/app/outputs/bundle/release/app-release.aab
```
If the build says it is signed with the debug key, `android/key.properties`
is missing - redo Step 6.

**No Android Studio? Let GitHub build it.** Every push to GitHub builds the
game automatically (or start it yourself: **Actions** tab > **Build Android
app** > **Run workflow**). About 25 minutes later the repository's
**Releases** page has a **Latest build** with `toffee-twist.apk` (open it on
your phone to install) and `toffee-twist.aab` (for Google Play). To have the
`.aab` signed with your upload key, add the two secrets described at the top
of `.github/workflows/build-android.yml`.

## Step 8 - Upload to Google Play

1. Create a developer account at https://play.google.com/console
   (one-time fee). Complete identity verification.
2. **Create app**: name *Toffee Twist: Sweet Match 3*, language English, type
   **Game**, **Free**, accept the declarations.
3. **Testing > Internal testing > Create new release**. When asked about
   **Play App Signing**, keep the default (*Google generates and protects the
   app signing key*). Upload `app-release.aab`, add release notes, save,
   then *Review release* and *Start rollout to Internal testing*. Add yourself
   as a tester and install the game from the opt-in link.
4. **Monetize > Products > In-app products** (available after the first
   upload): create `remove_ads` (one-time), `coins_small`, `coins_medium`,
   `coins_large` with titles, descriptions and prices. Activate them. Test the
   purchases with a *licence tester* account (*Settings > License testing*).
5. **Policy and programs > App content**: answer everything as described in
   **DATA_SAFETY.md** (privacy policy, ads, target audience 13+, data safety,
   advertising ID, content rating).
6. **Grow users > Store presence > Main store listing**: copy the texts from
   **STORE_LISTING.md** and upload the graphics from `store_assets/`
   (icon_512.png, feature_graphic.png, screenshots/screenshot_1..8.png).
7. **Closed testing first (new personal accounts):** at the time of writing,
   Google requires personal developer accounts created after November 2023 to
   run a **closed test with at least 12 testers for 14 days** before you can
   publish to production (Play Console shows the current rule on your
   Dashboard).
   Create a closed testing track, invite friends, keep them testing for 14 days,
   then apply for production access.
8. **Production > Create new release** > add the same (or a newer) bundle >
   *Review* > *Start rollout to Production*. Google reviews the app (usually a
   few days).

## Step 9 - Switch to real ads (right before production)

1. Sign in to https://apps.admob.com, **Add app** (Android, link it to your
   Play listing when it is live), then create 3 ad units: **Banner**,
   **Interstitial**, **Rewarded**.
2. In AdMob *Privacy & messaging*, create and publish a **European
   regulations (GDPR)** message - this is the consent form the game shows.
3. Put the IDs in `lib/config/ads_config.dart` (`realAppId`,
   `realBannerId`, `realInterstitialId`, `realRewardedId`) and set
   `useTestAds = false`. (The build stops with a clear message if the real app
   ID is still `XXXX`.)
4. Never click your own real ads. To keep testing safely, add your phone as a
   test device in AdMob (*Settings > Test devices*).
5. Increase the version (e.g. `1.0.0+2`), rebuild (Step 7) and upload.

## Updating the game later

1. Change the version in `pubspec.yaml` (e.g. `1.0.1+3` - the number after
   `+` must always go up).
2. `flutter build appbundle --release`
3. Upload the new `.aab` in Play Console (testing track first, then production).

## Technical notes

- **Minimum Android version: 7.0 (API 24).** The latest Google Mobile Ads
  plugin (google_mobile_ads 9) requires API 24, so API 23 is not possible
  with current ad libraries. **Target API: 36** (what Google Play requires
  for new apps and updates in 2026).
- Release signing is configured in `android/app/build.gradle.kts`; it reads
  `android/key.properties`.
- Release builds are not shrunk with R8 (`isMinifyEnabled = false`): R8 broke
  WorkManager, which the ads SDK uses, and the game crashed on start. Every
  GitHub build is opened on Android 7, 9, 12, 14 and 16 emulators before it is
  published, so a crash like that cannot slip through again.
- The AdMob app ID is copied into the Android manifest at build time from
  `lib/config/ads_config.dart`, so all ad IDs live in one file.
- Purchases are checked by Google Play only (there is no server). That is
  normal for an offline game, but it means very determined cheaters could
  give themselves coins; it does not affect your income from real purchases.
