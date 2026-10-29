import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toffeetwist/services/progress_service.dart';

void main() {
  late DateTime now;
  late SharedPreferences prefs;

  Future<ProgressService> fresh() async {
    prefs = await SharedPreferences.getInstance();
    return ProgressService(prefs, clock: () => now);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 3, 10, 12);
  });

  test('new players start with full lives, coins and one of each booster', () async {
    final p = await fresh();
    expect(p.lives, ProgressService.maxLives);
    expect(p.coins, ProgressService.startCoins);
    expect(p.currentLevel, 1);
    for (final b in Booster.values) {
      expect(p.boosterCount(b), 1);
    }
  });

  test('a life comes back every 30 minutes, also while the app is closed', () async {
    var p = await fresh();
    p.loseLife();
    p.loseLife();
    p.loseLife();
    expect(p.lives, 2);
    expect(p.nextLifeIn, const Duration(minutes: 30));
    now = now.add(const Duration(minutes: 31));
    expect(p.lives, 3);
    // "Close the app" (new service reading the saved data) and come back later.
    now = now.add(const Duration(minutes: 65));
    p = ProgressService(prefs, clock: () => now);
    expect(p.lives, 5);
    expect(p.nextLifeIn, isNull);
  });

  test('lives never go below 0 or above 5', () async {
    final p = await fresh();
    for (var i = 0; i < 8; i++) {
      p.loseLife();
    }
    expect(p.lives, 0);
    expect(p.hasLife, isFalse);
    p.addLives(10);
    expect(p.lives, 5);
  });

  test('refilling lives costs coins', () async {
    final p = await fresh();
    p.loseLife();
    p.addCoins(1000);
    final before = p.coins;
    expect(p.refillLives(), isTrue);
    expect(p.lives, 5);
    expect(p.coins, before - ProgressService.refillLivesPrice);
    expect(p.refillLives(), isFalse, reason: 'already full');
  });

  test('winning unlocks the next level, keeps the best stars and pays coins', () async {
    final p = await fresh();
    final coins = p.recordWin(1, 2, 5000);
    expect(coins, ProgressService.coinsForWin(2, firstTime: true));
    expect(p.currentLevel, 2);
    p.recordWin(1, 1, 3000);
    expect(p.starsFor(1), 2);
    expect(p.bestScore(1), 5000);
    p.recordWin(1, 3, 9000);
    expect(p.starsFor(1), 3);
    expect(p.totalStars, 3);
  });

  test('boosters can be bought with coins and used', () async {
    final p = await fresh();
    expect(p.useBooster(Booster.rollingPin), isTrue);
    expect(p.useBooster(Booster.rollingPin), isFalse);
    expect(p.buyBooster(Booster.rollingPin), isTrue);
    expect(p.coins, ProgressService.startCoins - Booster.rollingPin.price);
    expect(p.boosterCount(Booster.rollingPin), 1);
    p.spendCoins(p.coins);
    expect(p.buyBooster(Booster.freeSwap), isFalse);
  });

  test('daily calendar advances day by day and restarts after a missed day', () async {
    final p = await fresh();
    expect(p.canClaimDaily, isTrue);
    expect(p.dailyDay, 0);
    expect(p.claimDaily(), isNotNull);
    expect(p.canClaimDaily, isFalse);
    expect(p.claimDaily(), isNull, reason: 'once per day');
    now = now.add(const Duration(days: 1));
    expect(p.dailyDay, 1);
    p.claimDaily();
    now = now.add(const Duration(days: 1));
    expect(p.dailyDay, 2);
    p.claimDaily();
    now = now.add(const Duration(days: 2)); // missed a day
    expect(p.dailyDay, 0);
  });

  test('day 7 reward is the biggest and the calendar loops', () async {
    final p = await fresh();
    for (var d = 0; d < 7; d++) {
      expect(p.dailyDay, d);
      p.claimDaily();
      now = now.add(const Duration(days: 1));
    }
    expect(p.dailyDay, 0);
    expect(ProgressService.dailyRewards.last.coins, greaterThanOrEqualTo(300));
  });

  test('one free spin a day, then one extra spin for a video', () async {
    final p = await fresh();
    expect(p.canFreeSpin, isTrue);
    expect(p.canAdSpin, isFalse);
    p.markFreeSpin();
    expect(p.canFreeSpin, isFalse);
    expect(p.canAdSpin, isTrue);
    p.markAdSpin();
    expect(p.canAdSpin, isFalse);
    now = now.add(const Duration(days: 1));
    expect(p.canFreeSpin, isTrue);
  });

  test('spin wheel only gives coins and boosters, with sensible odds', () {
    for (final (reward, weight) in ProgressService.spinRewards) {
      expect(reward.coins > 0 || reward.boosters.isNotEmpty, isTrue);
      expect(reward.lives, 0);
      expect(weight, greaterThan(0));
    }
    expect(ProgressService.pickSpin(0), 0);
    expect(ProgressService.pickSpin(0.9999), ProgressService.spinRewards.length - 1);
  });

  test('settings and progress are saved; reset keeps purchases', () async {
    var p = await fresh();
    p.setSetting(music: false, vibration: false);
    p.recordWin(1, 3, 1000);
    p.removeAds = true;
    p = ProgressService(prefs, clock: () => now);
    expect(p.music, isFalse);
    expect(p.vibration, isFalse);
    expect(p.currentLevel, 2);
    await p.reset();
    expect(p.currentLevel, 1);
    expect(p.music, isTrue);
    expect(p.removeAds, isTrue);
  });

  test('interstitial counter counts finished levels', () async {
    final p = await fresh();
    p.recordWin(1, 1, 100);
    p.recordLoss();
    expect(p.levelsSinceInterstitial, 2);
    p.interstitialShown();
    expect(p.levelsSinceInterstitial, 0);
  });
}
