import 'package:flutter/widgets.dart';

/// What a rewarded video gives.
enum RewardedPurpose { extraMoves, tripleCoins, extraSpin, freeLife }

/// Ads used by the game. The real one (AdMob) is in admob_service.dart; this
/// interface lets the web build and the tests run without ads.
abstract class AdsService extends ChangeNotifier {
  /// True when a rewarded video can be shown right now.
  bool get rewardedReady;

  /// Shows a rewarded video. Returns true if the player earned the reward.
  Future<bool> showRewarded(RewardedPurpose purpose);

  /// Called between levels (never during play). Shows an interstitial only
  /// if the rules allow it (after level 10, max once every 3 levels).
  Future<void> betweenLevels(int levelJustPlayed);

  /// Banner for the map screen (null when there is none).
  Widget? banner();

  /// True if the privacy options (consent) button must be shown in Settings.
  bool get privacyOptionsRequired => false;
  Future<void> showPrivacyOptions() async {}
}

/// Used on platforms without ads (web, tests) and after "Remove Ads".
class NoAdsService extends AdsService {
  @override
  bool get rewardedReady => false;

  @override
  Future<bool> showRewarded(RewardedPurpose purpose) async => false;

  @override
  Future<void> betweenLevels(int levelJustPlayed) async {}

  @override
  Widget? banner() => null;
}
