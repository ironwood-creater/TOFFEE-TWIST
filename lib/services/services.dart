import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../levels/level_repository.dart';
import 'admob_service.dart';
import 'ads_service.dart';
import 'audio_service.dart';
import 'haptics.dart';
import 'iap_service.dart';
import 'play_billing_service.dart';
import 'progress_service.dart';

export 'ads_service.dart' show RewardedPurpose;
export 'audio_service.dart' show Sfx;
export 'progress_service.dart' show Booster, Reward;

/// One place to reach the app's services from anywhere.
abstract final class Services {
  static late ProgressService progress;
  static late AudioService audio;
  static late Haptics haptics;
  static late LevelRepository levels;
  static AdsService ads = NoAdsService();
  static IapService iap = NoIapService(placeholderProducts());

  static bool _ready = false;
  static bool get ready => _ready;

  static Future<void> init({DateTime Function()? clock}) async {
    final prefs = await SharedPreferences.getInstance();
    progress = ProgressService(prefs, clock: clock);
    audio = AudioService(progress);
    haptics = Haptics(progress);
    levels = LevelRepository();
    if (_isAndroid) {
      ads = AdmobAdsService(progress, audio);
      iap = PlayBillingService(progress);
    } else {
      ads = NoAdsService();
      iap = NoIapService(placeholderProducts());
    }
    _ready = true;
    await audio.init();
  }

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Starts the store and the ads (consent form first). Called once the first
  /// screen is visible, so Google's consent form can be shown.
  static Future<void> startStoreAndAds() async {
    final i = iap;
    if (i is PlayBillingService) {
      try {
        await i.start();
      } catch (e) {
        debugPrint('Store not available: $e');
      }
    }
    final a = ads;
    if (a is AdmobAdsService) {
      try {
        await a.start();
      } catch (e) {
        debugPrint('Ads not available: $e');
      }
    }
  }
}
