# Play Console guide: Data safety and other "App content" answers

This is what to answer in Google Play Console for **Toffee Twist: Sweet Match 3**
as the game is built today (AdMob ads + Google Play purchases + progress saved
only on the phone). Find these under **Play Console > your app > Policy and
programs > App content**.

> Check before you submit: Google updates the AdMob disclosure from time to
> time. Compare with the official page
> "Data disclosure for the Google Mobile Ads SDK":
> https://developers.google.com/admob/android/privacy/play-data-disclosure
> If you later add other SDKs (analytics, crash reporting...), you must add
> their data too.

---

## 1. Data safety form

### Step "Data collection and security"

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** (the Google Mobile Ads SDK does) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** |
| Which of the following methods of account creation does your app support? | **My app does not allow users to create an account** |
| Do you provide a way for users to request that their data is deleted? | **No** (there are no accounts and we hold no data; local data is deleted with Settings > Reset progress or by uninstalling) |

### Step "Data types" - tick ONLY these

| Category | Data type to tick |
|---|---|
| **Location** | Approximate location |
| **App activity** | App interactions |
| **App info and performance** | Crash logs, Diagnostics |
| **Device or other IDs** | Device or other IDs |

Do **not** tick: Personal info, Financial info, Health and fitness, Messages,
Photos and videos, Audio, Files and docs, Calendar, Contacts, Web browsing,
Search history, Installed apps, Other user-generated content, Purchase history.

Why not "Purchase history" / "Financial info"? Payments are handled by Google
Play. The game only keeps purchase IDs on the phone (never sent anywhere), and
data that never leaves the device does not count as "collected".

### Step "Data usage and handling" - for EACH of the 5 ticked data types

| Question | Answer |
|---|---|
| Is this data collected, shared, or both? | **Collected** and **Shared** (tick both) |
| Is this data processed ephemerally? | **No** |
| Is this data required for your app, or can users choose whether it's collected? | **Data collection is required (users can't turn off this data collection)** |
| Why is this user data collected? (purposes) | **Advertising or marketing**, **Analytics**, **Fraud prevention, security, and compliance** |
| Why is this user data shared? (purposes) | **Advertising or marketing**, **Analytics**, **Fraud prevention, security, and compliance** |

(Crash logs and Diagnostics: if the form only offers some purposes, choose
Analytics and Fraud prevention, security, and compliance.)

### Preview
The summary should say something like: "This app may share these data types
with third parties: Location, App activity, App info and performance, Device or
other IDs" and "No data collected" is NOT correct for this app.

---

## 2. Other "App content" declarations

| Section | Answer |
|---|---|
| **Privacy policy** | `https://toffee-twist.vercel.app/privacy` (already set in `lib/config/app_config.dart`). |
| **App access** | All functionality is available without special access |
| **Ads** | **Yes, my app contains ads** |
| **Content rating** | Fill the IARC questionnaire (see below) |
| **Target audience and content** | Ages **13-15, 16-17 and 18 and over** only. Do NOT select any age under 13. |
| "Could your store listing unintentionally appeal to children?" (if asked) | No - the game is a casual puzzle for teens and adults; it is not designed for children and ads are rated T. (Google may still review this because of the cartoon sweets; keep screenshots and text aimed at a general 13+ audience.) |
| **News app** | No |
| **COVID-19 apps** | Not a COVID-19 app |
| **Data safety** | As in section 1 |
| **Government apps** | No |
| **Financial features** | My app doesn't provide any financial features |
| **Health** | My app does not have any health features |
| **Advertising ID** | **Yes**, the app uses an advertising ID. Purposes: **Advertising or marketing**, **Analytics**, **Fraud prevention, security, and compliance**. (The AdMob SDK adds the `AD_ID` permission automatically.) |

### Content rating questionnaire (IARC) - expected answers
- Category: **Game** (Puzzle / casual).
- Violence, fear, sexuality, language, drugs, crude humor: **No** to all.
- **Gambling / simulated gambling:** **No.** The daily spin wheel is free, gives
  only in-game coins and boosters, and can never be bought with real money or coins.
- Does the app contain **ads**? **Yes**.
- Can users **interact or exchange content**? **No** (no chat, no user content).
- Does the app **share the user's location** with other users? **No**.
- **Digital purchases**: **Yes** (in-app purchases).
- Expected result: **Everyone / PEGI 3** (with "In-App Purchases" notice).

### Monetization setup
- **Products** (Monetize > Products > In-app products): create
  `remove_ads` (managed product, one-time), `coins_small`, `coins_medium`,
  `coins_large` (consumable coin packs). The IDs must match
  `lib/config/iap_config.dart`. You need a Google Payments merchant account.
- **AdMob**: in https://apps.admob.com add the app, create Banner,
  Interstitial and Rewarded ad units, and under **Privacy & messaging** create
  a **GDPR (European regulations) message** - this is the consent form the game
  shows in the EEA/UK. Then put the IDs in `lib/config/ads_config.dart` and set
  `useTestAds = false`. Also add an `app-ads.txt` file to your developer website
  as AdMob explains.
