/// ALL AdMob settings live in this one file.
///
/// While developing, keep `useTestAds = true`: Google's official test ads are
/// shown and you can never get in trouble for clicking them.
///
/// Before publishing:
///  1. Create an app and 3 ad units (Banner, Interstitial, Rewarded) at
///     https://apps.admob.com
///  2. Paste the IDs into the `real...` values below.
///  3. Set `useTestAds = false`.
/// The Android build reads the app ID from this file too (see
/// android/app/build.gradle.kts), so you never edit AndroidManifest.xml.
abstract final class AdsConfig {
  static const bool useTestAds = true;

  // --- Your real IDs (replace the X's) --------------------------------------
  static const String realAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';
  static const String realBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String realInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String realRewardedId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // --- Google's official test IDs (do not change) ---------------------------
  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testBannerId = 'ca-app-pub-3940256099942544/9214589741';
  static const String testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedId = 'ca-app-pub-3940256099942544/5224354917';

  static String get bannerId => useTestAds ? testBannerId : realBannerId;
  static String get interstitialId => useTestAds ? testInterstitialId : realInterstitialId;
  static String get rewardedId => useTestAds ? testRewardedId : realRewardedId;

  // --- Ad rules --------------------------------------------------------------
  /// No interstitial ads before this level is finished.
  static const int firstInterstitialLevel = 10;

  /// At most one interstitial every this many finished levels.
  static const int levelsBetweenInterstitials = 3;
}

/// When an interstitial may be shown (only ever called between levels).
abstract final class InterstitialPolicy {
  static bool shouldShow({
    required int levelJustPlayed,
    required int levelsSinceLast,
    required bool removeAds,
  }) =>
      !removeAds &&
      levelJustPlayed >= AdsConfig.firstInterstitialLevel &&
      levelsSinceLast >= AdsConfig.levelsBetweenInterstitials;
}
