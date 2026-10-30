import 'package:flutter/foundation.dart';

import '../services/progress_service.dart';
import 'logic/engine.dart';
import 'logic/events.dart';
import 'logic/level.dart';
import 'logic/types.dart';

enum SessionPhase { playing, finale, won, lost }

enum BoosterMode { none, rollingPin, freeSwap }

/// What the session needs from the animated board (implemented in Flame).
abstract interface class BoardView {
  Future<void> play(List<BoardEvent> events);
  Future<void> playFinale(int moves);
  void resetIdle();
}

/// One attempt at one level. Owns the [GameEngine] and keeps the numbers the
/// HUD shows in sync with the animations (score, moves, goals).
class GameSession extends ChangeNotifier {
  GameSession({
    required this.level,
    int? seed,
    this.extraMoves = 0,
    this.startBox = false,
    this.consumeBooster,
  }) : seed = seed ?? (DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF) {
    engine = GameEngine(level, seed: this.seed);
    if (extraMoves > 0) engine.addMoves(extraMoves);
    moves = engine.movesLeft;
    goals = engine.goals.snapshot();
  }

  final LevelDef level;
  final int seed;
  final int extraMoves;
  final bool startBox;

  /// Uses one booster from the inventory; returns false if there is none.
  final bool Function(Booster booster)? consumeBooster;

  late final GameEngine engine;
  BoardView? view;

  // Values shown in the HUD (they follow the animations).
  int score = 0;
  int moves = 0;
  List<int> goals = [];
  SessionPhase phase = SessionPhase.playing;
  BoosterMode boosterMode = BoosterMode.none;
  bool busy = false;
  bool _started = false;
  int continues = 0;

  /// Called when the level is won or lost.
  void Function(SessionPhase phase)? onFinished;

  int get stars => engine.stars;

  /// Stars the current displayed score would give (for the score bar).
  int get starsShown {
    var s = 0;
    for (final t in level.stars) {
      if (score >= t) s++;
    }
    return s;
  }

  /// Runs start-of-level effects (Sweet Box booster, stuck board shuffle).
  Future<void> begin() async {
    if (_started) return;
    _started = true;
    final ev = <BoardEvent>[];
    if (startBox) ev.addAll(engine.applyStartBox());
    ev.addAll(engine.shuffleIfNeeded());
    if (ev.isNotEmpty) await _play(ev);
  }

  void updateStatus(Status s) {
    score = s.score;
    goals = s.goalProgress;
    notifyListeners();
  }

  /// Adds finale points to the HUD while the finale animation runs.
  void finaleTick(int points) {
    score += points;
    if (moves > 0) moves--;
    notifyListeners();
  }

  void setBoosterMode(BoosterMode mode) {
    boosterMode = boosterMode == mode ? BoosterMode.none : mode;
    view?.resetIdle();
    notifyListeners();
  }

  bool get canAct => !busy && phase == SessionPhase.playing && _started;

  /// Player swiped or tapped two neighbours.
  Future<void> requestSwap(int a, int b) async {
    if (!canAct) return;
    final free = boosterMode == BoosterMode.freeSwap;
    final result = free ? engine.freeSwap(a, b) : engine.swap(a, b);
    if (result.events.isEmpty) return;
    if (free && result.valid) {
      consumeBooster?.call(Booster.freeSwap);
      boosterMode = BoosterMode.none;
    }
    if (result.valid) moves = engine.movesLeft;
    notifyListeners();
    await _play(result.events);
    if (result.valid) await _checkEnd();
  }

  /// Player tapped a cell while the Rolling Pin is selected.
  Future<void> useRollingPin(int cell) async {
    if (!canAct) return;
    final result = engine.useRollingPin(cell);
    if (!result.valid) return;
    consumeBooster?.call(Booster.rollingPin);
    boosterMode = BoosterMode.none;
    notifyListeners();
    await _play(result.events);
    await _checkEnd();
  }

  /// Continue after running out of moves.
  void continueWithMoves(int n) {
    continues++;
    engine.addMoves(n);
    moves = engine.movesLeft;
    phase = SessionPhase.playing;
    notifyListeners();
    // The last move can leave a board without any possible move (the engine
    // only reshuffles while the game is still running).
    final ev = engine.shuffleIfNeeded();
    if (ev.isNotEmpty) _play(ev);
  }

  Future<void> _play(List<BoardEvent> events) async {
    busy = true;
    try {
      await view?.play(events);
    } finally {
      busy = false;
      moves = engine.movesLeft;
      score = engine.score;
      goals = engine.goals.snapshot();
      notifyListeners();
    }
  }

  Future<void> _checkEnd() async {
    switch (engine.status) {
      case GameStatus.playing:
        return;
      case GameStatus.won:
        phase = SessionPhase.finale;
        notifyListeners();
        final left = engine.movesLeft;
        engine.applyFinale();
        busy = true;
        await view?.playFinale(left);
        busy = false;
        score = engine.score;
        moves = 0;
        phase = SessionPhase.won;
        notifyListeners();
        onFinished?.call(phase);
      case GameStatus.lost:
        phase = SessionPhase.lost;
        notifyListeners();
        onFinished?.call(phase);
    }
  }

  /// Score points per finale move (for the animation).
  static const finalePoints = Scoring.finalePerMove;
}
