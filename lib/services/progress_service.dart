import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The four boosters.
enum Booster {
  rollingPin('Rolling Pin', 'Smash any one piece.', 120),
  freeSwap('Free Swap', 'Swap two neighbours, no match needed.', 100),
  startBox('Sweet Box Start', 'Start the level with a Sweet Box.', 150),
  extraMoves('+3 Moves', 'Start the level with 3 extra moves.', 90);

  const Booster(this.label, this.description, this.price);
  final String label;
  final String description;

  /// Price in coins.
  final int price;
}

/// A reward from the daily calendar or the spin wheel.
class Reward {
  const Reward({this.coins = 0, this.boosters = const {}, this.lives = 0});
  final int coins;
  final Map<Booster, int> boosters;
  final int lives;

  String get label {
    final parts = <String>[
      if (coins > 0) '$coins coins',
      for (final e in boosters.entries) '${e.value}x ${e.key.label}',
      if (lives > 0) '$lives ${lives == 1 ? 'life' : 'lives'}',
    ];
    return parts.join(' + ');
  }
}

/// Everything saved on the phone: level stars, coins, lives, boosters,
/// daily reward, settings. Stored offline with shared_preferences as one
/// JSON value, so there is no login and no server.
class ProgressService extends ChangeNotifier {
  ProgressService(this._prefs, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _load();
  }

  static const _key = 'toffee_twist_progress_v1';
  static const maxLives = 5;
  static const lifeRegen = Duration(minutes: 30);
  static const continueMovesPrice = 120;
  static const startCoins = 300;

  /// The 7-day login calendar.
  static const dailyRewards = <Reward>[
    Reward(coins: 50),
    Reward(boosters: {Booster.rollingPin: 1}),
    Reward(coins: 100),
    Reward(boosters: {Booster.freeSwap: 1}),
    Reward(coins: 150),
    Reward(boosters: {Booster.startBox: 1, Booster.extraMoves: 1}),
    Reward(coins: 300, boosters: {Booster.rollingPin: 1, Booster.freeSwap: 1}),
  ];

  /// Daily spin wheel prizes (coins and boosters only) and how likely each
  /// one is. Spins are free once a day (+1 for watching a video) and can
  /// never be bought.
  static const spinRewards = <(Reward, int)>[
    (Reward(coins: 25), 22),
    (Reward(boosters: {Booster.rollingPin: 1}), 12),
    (Reward(coins: 50), 18),
    (Reward(boosters: {Booster.extraMoves: 1}), 12),
    (Reward(coins: 100), 12),
    (Reward(boosters: {Booster.freeSwap: 1}), 12),
    (Reward(coins: 250), 4),
    (Reward(boosters: {Booster.startBox: 1}), 8),
  ];

  /// Picks a spin wheel segment index using [roll] in [0, 1).
  static int pickSpin(double roll) {
    final total = spinRewards.fold(0, (a, r) => a + r.$2);
    var x = roll * total;
    for (var i = 0; i < spinRewards.length; i++) {
      x -= spinRewards[i].$2;
      if (x < 0) return i;
    }
    return 0;
  }

  static const refillLivesPrice = 600;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  // Saved values.
  List<int> _stars = [];
  List<int> _best = [];
  int _coins = startCoins;
  int _lives = maxLives;
  int _lifeTimerMs = 0;
  final Map<Booster, int> _boosters = {for (final b in Booster.values) b: 1};
  int _dailyIndex = 0;
  String _lastDaily = '';
  String _lastFreeSpin = '';
  String _lastAdSpin = '';
  bool music = true;
  bool sound = true;
  bool vibration = true;
  bool _removeAds = false;
  final Set<String> _tutorials = {};
  int _levelsSinceInterstitial = 0;
  int _levelsFinished = 0;
  final List<String> _delivered = [];

  DateTime get now => _clock();

  // ---------------------------------------------------------------------------
  // Levels
  // ---------------------------------------------------------------------------

  /// Highest level the player may play (1-based).
  int get currentLevel => _stars.length + 1;
  int get levelsCompleted => _stars.length;
  int starsFor(int level) => level <= _stars.length ? _stars[level - 1] : 0;
  int bestScore(int level) => level <= _best.length ? _best[level - 1] : 0;
  int get totalStars => _stars.fold(0, (a, b) => a + b);
  bool isUnlocked(int level) => level <= currentLevel;

  /// Records a win; returns coins earned.
  int recordWin(int level, int stars, int score) {
    final first = level > _stars.length;
    if (first) {
      while (_stars.length < level) {
        _stars.add(0);
        _best.add(0);
      }
    }
    _stars[level - 1] = math.max(_stars[level - 1], stars);
    _best[level - 1] = math.max(_best[level - 1], score);
    final coins = coinsForWin(stars, firstTime: first);
    _coins += coins;
    _finishLevel();
    return coins;
  }

  static int coinsForWin(int stars, {required bool firstTime}) => 10 + stars * 10 + (firstTime ? 10 : 0);

  void recordLoss() {
    loseLife();
    _finishLevel();
  }

  void _finishLevel() {
    _levelsFinished++;
    _levelsSinceInterstitial++;
    _save();
  }

  int get levelsSinceInterstitial => _levelsSinceInterstitial;
  int get levelsFinished => _levelsFinished;
  void interstitialShown() {
    _levelsSinceInterstitial = 0;
    _save();
  }

  // ---------------------------------------------------------------------------
  // Coins and boosters
  // ---------------------------------------------------------------------------

  int get coins => _coins;

  void addCoins(int n) {
    _coins += n;
    _save();
  }

  bool spendCoins(int n) {
    if (_coins < n) return false;
    _coins -= n;
    _save();
    return true;
  }

  int boosterCount(Booster b) => _boosters[b] ?? 0;

  void addBooster(Booster b, [int n = 1]) {
    _boosters[b] = boosterCount(b) + n;
    _save();
  }

  bool useBooster(Booster b) {
    if (boosterCount(b) <= 0) return false;
    _boosters[b] = boosterCount(b) - 1;
    _save();
    return true;
  }

  bool buyBooster(Booster b) {
    if (!spendCoins(b.price)) return false;
    addBooster(b);
    return true;
  }

  void grant(Reward r) {
    _coins += r.coins;
    for (final e in r.boosters.entries) {
      _boosters[e.key] = boosterCount(e.key) + e.value;
    }
    if (r.lives > 0) addLives(r.lives);
    _save();
  }

  // ---------------------------------------------------------------------------
  // Lives: 5 max, one comes back every 30 minutes (also while the app is closed,
  // because we store the time and catch up when the app opens again).
  // ---------------------------------------------------------------------------

  int get lives {
    _regenerate();
    return _lives;
  }

  bool get hasLife => lives > 0;

  /// Time until the next life, or null when lives are full.
  Duration? get nextLifeIn {
    _regenerate();
    if (_lives >= maxLives) return null;
    final ms = lifeRegen.inMilliseconds - (now.millisecondsSinceEpoch - _lifeTimerMs);
    return Duration(milliseconds: ms.clamp(0, lifeRegen.inMilliseconds));
  }

  void loseLife() {
    _regenerate();
    if (_lives >= maxLives) _lifeTimerMs = now.millisecondsSinceEpoch;
    _lives = math.max(0, _lives - 1);
    _save();
  }

  void addLives(int n) {
    _regenerate();
    _lives = math.min(maxLives, _lives + n);
    _save();
  }

  /// Refill all lives with coins.
  bool refillLives() {
    if (lives >= maxLives || !spendCoins(refillLivesPrice)) return false;
    addLives(maxLives);
    return true;
  }

  void _regenerate() {
    if (_lives >= maxLives) return;
    final nowMs = now.millisecondsSinceEpoch;
    final regen = lifeRegen.inMilliseconds;
    if (_lifeTimerMs > nowMs) _lifeTimerMs = nowMs; // clock was moved back
    final gained = (nowMs - _lifeTimerMs) ~/ regen;
    if (gained <= 0) return;
    _lives = math.min(maxLives, _lives + gained);
    _lifeTimerMs = _lives >= maxLives ? nowMs : _lifeTimerMs + gained * regen;
    _save(notify: false);
  }

  // ---------------------------------------------------------------------------
  // Daily login reward and spin wheel
  // ---------------------------------------------------------------------------

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _today => dayKey(now);
  String get _yesterday => dayKey(DateTime(now.year, now.month, now.day - 1));

  bool get canClaimDaily => _lastDaily != _today;

  /// Which day (0-6) of the calendar is claimable / was claimed last.
  int get dailyDay {
    if (!canClaimDaily) return (_dailyIndex + 6) % 7;
    if (_lastDaily == _yesterday) return _dailyIndex % 7;
    return 0; // missed a day (or first time): start again at day 1
  }

  Reward? claimDaily() {
    if (!canClaimDaily) return null;
    final day = dailyDay;
    final reward = dailyRewards[day];
    grant(reward);
    _dailyIndex = (day + 1) % 7;
    _lastDaily = _today;
    _save();
    return reward;
  }

  bool get canFreeSpin => _lastFreeSpin != _today;
  bool get canAdSpin => !canFreeSpin && _lastAdSpin != _today;

  void markFreeSpin() {
    _lastFreeSpin = _today;
    _save();
  }

  void markAdSpin() {
    _lastAdSpin = _today;
    _save();
  }

  // ---------------------------------------------------------------------------
  // Settings, purchases, tutorials
  // ---------------------------------------------------------------------------

  bool get removeAds => _removeAds;

  /// Remembers a coin purchase so it is never credited twice. Returns false
  /// if it was already delivered.
  bool markPurchaseDelivered(String purchaseId) {
    if (_delivered.contains(purchaseId)) return false;
    _delivered.add(purchaseId);
    if (_delivered.length > 200) _delivered.removeAt(0);
    _save();
    return true;
  }

  set removeAds(bool v) {
    _removeAds = v;
    _save();
  }

  void setSetting({bool? music, bool? sound, bool? vibration}) {
    if (music != null) this.music = music;
    if (sound != null) this.sound = sound;
    if (vibration != null) this.vibration = vibration;
    _save();
  }

  bool tutorialSeen(String id) => _tutorials.contains(id);

  void markTutorial(String id) {
    if (_tutorials.add(id)) _save();
  }

  /// Deletes all progress (Settings > Reset progress). Purchases stay.
  Future<void> reset() async {
    final keepAds = _removeAds;
    final keepDelivered = List.of(_delivered);
    await _prefs.remove(_key);
    _load();
    _removeAds = keepAds;
    _delivered.addAll(keepDelivered);
    _save();
  }

  // ---------------------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------------------

  void _load() {
    _stars = [];
    _best = [];
    _coins = startCoins;
    _lives = maxLives;
    _lifeTimerMs = now.millisecondsSinceEpoch;
    for (final b in Booster.values) {
      _boosters[b] = 1;
    }
    _dailyIndex = 0;
    _lastDaily = '';
    _lastFreeSpin = '';
    _lastAdSpin = '';
    music = true;
    sound = true;
    vibration = true;
    _removeAds = false;
    _tutorials.clear();
    _levelsSinceInterstitial = 0;
    _levelsFinished = 0;
    _delivered.clear();

    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _stars = (j['stars'] as List? ?? const []).cast<int>().toList();
      _best = (j['best'] as List? ?? const []).cast<int>().toList();
      while (_best.length < _stars.length) {
        _best.add(0);
      }
      _coins = j['coins'] as int? ?? startCoins;
      _lives = j['lives'] as int? ?? maxLives;
      _lifeTimerMs = j['lifeTimer'] as int? ?? now.millisecondsSinceEpoch;
      final boosters = j['boosters'] as Map<String, dynamic>? ?? const {};
      for (final b in Booster.values) {
        _boosters[b] = boosters[b.name] as int? ?? 0;
      }
      _dailyIndex = j['dailyIndex'] as int? ?? 0;
      _lastDaily = j['lastDaily'] as String? ?? '';
      _lastFreeSpin = j['lastFreeSpin'] as String? ?? '';
      _lastAdSpin = j['lastAdSpin'] as String? ?? '';
      music = j['music'] as bool? ?? true;
      sound = j['sound'] as bool? ?? true;
      vibration = j['vibration'] as bool? ?? true;
      _removeAds = j['removeAds'] as bool? ?? false;
      _tutorials.addAll((j['tutorials'] as List? ?? const []).cast<String>());
      _levelsSinceInterstitial = j['sinceAd'] as int? ?? 0;
      _levelsFinished = j['finished'] as int? ?? 0;
      _delivered.addAll((j['delivered'] as List? ?? const []).cast<String>());
    } catch (e) {
      debugPrint('Could not read saved progress: $e');
    }
  }

  void _save({bool notify = true}) {
    final j = {
      'stars': _stars,
      'best': _best,
      'coins': _coins,
      'lives': _lives,
      'lifeTimer': _lifeTimerMs,
      'boosters': {for (final e in _boosters.entries) e.key.name: e.value},
      'dailyIndex': _dailyIndex,
      'lastDaily': _lastDaily,
      'lastFreeSpin': _lastFreeSpin,
      'lastAdSpin': _lastAdSpin,
      'music': music,
      'sound': sound,
      'vibration': vibration,
      'removeAds': _removeAds,
      'tutorials': _tutorials.toList(),
      'sinceAd': _levelsSinceInterstitial,
      'finished': _levelsFinished,
      'delivered': _delivered,
    };
    _prefs.setString(_key, jsonEncode(j));
    if (notify) notifyListeners();
  }
}
