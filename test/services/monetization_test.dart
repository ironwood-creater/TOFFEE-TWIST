import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toffeetwist/config/ads_config.dart';
import 'package:toffeetwist/config/iap_config.dart';
import 'package:toffeetwist/services/iap_service.dart';
import 'package:toffeetwist/services/progress_service.dart';

void main() {
  group('interstitial rules', () {
    bool show(int level, int since, {bool removeAds = false}) =>
        InterstitialPolicy.shouldShow(levelJustPlayed: level, levelsSinceLast: since, removeAds: removeAds);

    test('never before level 10', () {
      for (var level = 1; level < 10; level++) {
        expect(show(level, 99), isFalse, reason: 'level $level');
      }
      expect(show(10, 3), isTrue);
    });

    test('at most once every 3 levels', () {
      expect(show(15, 0), isFalse);
      expect(show(15, 2), isFalse);
      expect(show(15, 3), isTrue);
    });

    test('never after buying Remove Ads', () {
      expect(show(50, 10, removeAds: true), isFalse);
    });

    test('simulated play: one interstitial per 3 finished levels after level 10', () async {
      SharedPreferences.setMockInitialValues({});
      final p = ProgressService(await SharedPreferences.getInstance());
      final shownAfter = <int>[];
      for (var level = 1; level <= 30; level++) {
        p.recordWin(level, 1, 100);
        if (show(level, p.levelsSinceInterstitial)) {
          p.interstitialShown();
          shownAfter.add(level);
        }
      }
      expect(shownAfter.first, 10);
      for (var i = 1; i < shownAfter.length; i++) {
        expect(shownAfter[i] - shownAfter[i - 1], greaterThanOrEqualTo(3));
      }
    });
  });

  group('ad and product config', () {
    test('test ad IDs are Google\'s official test IDs', () {
      expect(AdsConfig.useTestAds, isTrue, reason: 'switch only when publishing');
      expect(AdsConfig.testAppId, startsWith('ca-app-pub-3940256099942544~'));
      for (final id in [AdsConfig.testBannerId, AdsConfig.testInterstitialId, AdsConfig.testRewardedId]) {
        expect(id, startsWith('ca-app-pub-3940256099942544/'));
      }
    });

    test('shop shows 3 coin packs and Remove Ads', () {
      final products = placeholderProducts();
      expect(products.where((p) => p.coins > 0), hasLength(3));
      expect(products.where((p) => p.removeAds), hasLength(1));
      expect(IapConfig.allIds, hasLength(4));
    });

    test('a coin purchase is delivered only once', () async {
      SharedPreferences.setMockInitialValues({});
      final p = ProgressService(await SharedPreferences.getInstance());
      expect(p.markPurchaseDelivered('GPA.1234'), isTrue);
      expect(p.markPurchaseDelivered('GPA.1234'), isFalse);
      await p.reset();
      expect(p.markPurchaseDelivered('GPA.1234'), isFalse, reason: 'reset keeps purchase history');
    });
  });
}
