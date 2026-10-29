import 'dart:math' as math;

import '../game/logic/engine.dart';
import '../game/logic/level.dart';
import '../game/logic/rng.dart';
import '../game/logic/types.dart';

/// A simple greedy player: tries every legal move, looks at what the first
/// clearing wave would do (no peeking at future refills) and picks the move
/// that helps the goals most.
class GreedyBot {
  GreedyBot(this.rng);
  final Rng rng;

  Move? choose(GameEngine e) {
    final moves = e.possibleMoves();
    if (moves.isEmpty) return null;
    Move? best;
    var bestValue = -1e9;
    for (final m in moves) {
      final v = evaluate(e, m) + rng.nextDouble() * 0.6;
      if (v > bestValue) {
        bestValue = v;
        best = m;
      }
    }
    return best;
  }

  double evaluate(GameEngine e, Move m) {
    final s = e.preview(m);
    var v = 0.0;
    for (final g in e.goals.goals) {
      if (g.done) continue;
      switch (g.def.type) {
        case GoalType.collect:
          v += math.min(s.colorCounts[g.def.color], g.remaining) * 10;
        case GoalType.caramel:
          v += s.caramelLayers * 9 + s.caramelCleared * 5;
        case GoalType.crates:
          v += s.crateHits * 9 + s.cratesBroken * 5;
        case GoalType.nuts:
          v += _nutProgress(e, s.clearedCells) * 7;
        case GoalType.score:
          v += s.points / 30;
      }
    }
    v += s.sweets;
    v += s.stripedMade * 7 + s.boxMade * 9 + s.swirlMade * 16 + s.activations * 3;
    if (s.clearedCells.isNotEmpty) {
      var rows = 0;
      for (final c in s.clearedCells) {
        rows += e.board.rowOf(c);
      }
      v += rows / s.clearedCells.length / e.board.rows * 2.5;
    }
    return v;
  }

  /// Cleared cells below golden nuts (each lets a nut drop one cell).
  static int _nutProgress(GameEngine e, List<int> cleared) {
    final b = e.board;
    var n = 0;
    for (var i = 0; i < b.length; i++) {
      final p = b.pieces[i];
      if (p == null || !p.isNut) continue;
      final col = b.colOf(i);
      final row = b.rowOf(i);
      for (final c in cleared) {
        if (b.colOf(c) == col && b.rowOf(c) > row) n++;
      }
    }
    return n;
  }
}

/// Result of one bot game.
class SimRun {
  const SimRun({required this.won, required this.movesUsed, required this.score});
  final bool won;

  /// Moves the bot needed to complete all goals (or the cap if it never did).
  final int movesUsed;

  /// Score at the moment the goals were completed (before the finale bonus).
  final int score;
}

/// Plays a level with the greedy bot and no move limit (up to [moveCap]).
/// Because the bot ignores the move counter, "won within M moves" for any
/// M is simply `movesUsed <= M` - one run answers every move budget.
SimRun simulateRun(LevelDef level, int seed, {int moveCap = 90}) {
  final engine = GameEngine(level.copyWith(moves: moveCap), seed: seed, recordEvents: false);
  final bot = GreedyBot(Rng(seed ^ 0x2545F491));
  while (engine.status == GameStatus.playing) {
    final m = bot.choose(engine);
    if (m == null) break;
    engine.swap(m.a, m.b);
  }
  return SimRun(
    won: engine.status == GameStatus.won,
    movesUsed: engine.movesUsed,
    score: engine.score,
  );
}

/// Many bot runs of one level.
class LevelSim {
  LevelSim(this.level, this.runs);

  final LevelDef level;
  final List<SimRun> runs;

  static LevelSim run(LevelDef level, {int plays = 50, int seedBase = 1, int moveCap = 90}) {
    final runs = [
      for (var i = 0; i < plays; i++) simulateRun(level, mixSeed(level.id, seedBase, i), moveCap: moveCap),
    ];
    return LevelSim(level, runs);
  }

  /// Share of runs the bot wins with [moves] moves.
  double winRate(int moves) =>
      runs.where((r) => r.won && r.movesUsed <= moves).length / runs.length;

  /// Share of runs that never finished, even with the move cap.
  double get unsolvedRate => runs.where((r) => !r.won).length / runs.length;

  /// Smallest move count giving at least [target] win rate (null if none).
  int? movesFor(double target, {int maxMoves = 60}) {
    for (var m = 5; m <= maxMoves; m++) {
      if (winRate(m) >= target) return m;
    }
    return null;
  }

  double averageMovesUsed(int moves) {
    final won = runs.where((r) => r.won && r.movesUsed <= moves).toList();
    if (won.isEmpty) return 0;
    return won.fold(0, (a, r) => a + r.movesUsed) / won.length;
  }

  /// Final scores (with the Sweet Finale bonus) of runs won with [moves].
  List<int> winningScores(int moves) => [
        for (final r in runs)
          if (r.won && r.movesUsed <= moves) r.score + (moves - r.movesUsed) * Scoring.finalePerMove,
      ]..sort();

  /// Star thresholds from the bot's winning scores: 2 stars for a typical
  /// win, 3 stars for a great one.
  List<int> starThresholds(int moves) {
    final scores = winningScores(moves);
    final scoreGoal = level.goalOf(GoalType.score)?.target;
    if (scores.isEmpty) {
      final base = scoreGoal ?? 1000;
      return [base, base * 2, base * 3];
    }
    int pct(double p) => scores[((scores.length - 1) * p).round()];
    var s2 = _nice(pct(0.5));
    var s3 = _nice(pct(0.85));
    var s1 = scoreGoal ?? _nice((pct(0.0) * 0.6).round());
    if (s2 <= s1) s2 = _nice((s1 * 1.3).round());
    if (s3 <= s2) s3 = _nice((s2 * 1.25).round());
    return [s1, s2, s3];
  }

  static int _nice(int v) {
    final step = v >= 20000 ? 1000 : (v >= 5000 ? 500 : 100);
    return math.max(step, (v / step).round() * step);
  }
}
