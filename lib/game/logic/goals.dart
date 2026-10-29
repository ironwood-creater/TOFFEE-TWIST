import 'board.dart';
import 'level.dart';

/// Progress of one goal.
class GoalProgress {
  GoalProgress(this.def, this.target);

  final GoalDef def;

  /// Resolved target (for caramel/crates: number of tiles on the board).
  final int target;
  int progress = 0;

  bool get done => progress >= target;
  int get remaining => (target - progress).clamp(0, target);

  GoalProgress copy() => GoalProgress(def, target)..progress = progress;
}

/// Tracks all goals of a level.
class GoalTracker {
  GoalTracker._(this.goals);

  factory GoalTracker.forLevel(LevelDef level, Board board) {
    var caramelCells = 0;
    var crates = 0;
    for (var i = 0; i < board.length; i++) {
      if (board.caramel[i] > 0) caramelCells++;
      if (board.crate[i] > 0) crates++;
    }
    return GoalTracker._([
      for (final g in level.goals)
        GoalProgress(
          g,
          switch (g.type) {
            GoalType.caramel => caramelCells,
            GoalType.crates => crates,
            _ => g.target,
          },
        ),
    ]);
  }

  final List<GoalProgress> goals;

  bool get allDone => goals.every((g) => g.done);

  GoalTracker copy() => GoalTracker._([for (final g in goals) g.copy()]);

  List<int> snapshot() => [for (final g in goals) g.progress];

  void onSweetCleared(int color) {
    if (color < 0) return;
    for (final g in goals) {
      if (g.def.type == GoalType.collect && g.def.color == color && !g.done) g.progress++;
    }
  }

  void onCaramelCleared() => _bump(GoalType.caramel);
  void onCrateBroken() => _bump(GoalType.crates);
  void onNutCollected() => _bump(GoalType.nuts);

  void onScore(int score) {
    for (final g in goals) {
      if (g.def.type == GoalType.score) g.progress = score;
    }
  }

  /// Remaining number for a collect goal of [color] (0 if none).
  int remainingCollect(int color) {
    var n = 0;
    for (final g in goals) {
      if (g.def.type == GoalType.collect && g.def.color == color) n += g.remaining;
    }
    return n;
  }

  GoalProgress? of(GoalType type) => goals.where((g) => g.def.type == type).firstOrNull;

  void _bump(GoalType type) {
    for (final g in goals) {
      if (g.def.type == type) g.progress++;
    }
  }
}
