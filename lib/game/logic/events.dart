import 'types.dart';

/// Things that happened on the board, in order. The game logic finishes a
/// whole move instantly and returns these events; the Flame layer then plays
/// them one by one as animations.
sealed class BoardEvent {
  const BoardEvent();
}

/// A piece standing at a cell.
class CellPiece {
  const CellPiece(this.cell, this.piece);
  final int cell;
  final Piece piece;
}

/// A new value for a cell blocker (caramel layers or crate hit points).
class CellValue {
  const CellValue(this.cell, this.value);
  final int cell;
  final int value;
}

/// Floating "+120" text.
class ScorePopup {
  const ScorePopup(this.cell, this.points);
  final int cell;
  final int points;
}

/// Visual effect kinds for special activations.
enum EffectKind {
  lineH,
  lineV,
  blast,
  swirl,
  cross,
  bigCross,
  boardClear,
}

/// A special piece (or combo) going off.
class Activation {
  const Activation(this.kind, this.origin, this.targets, {this.radius = 1, this.color = -1});
  final EffectKind kind;
  final int origin;
  final List<int> targets;
  final int radius;
  final int color;
}

/// Snapshot of the score/goals after an event (to update the HUD in sync).
class Status {
  const Status(this.score, this.goalProgress);
  final int score;
  final List<int> goalProgress;
}

class SwapEvent extends BoardEvent {
  const SwapEvent(this.a, this.b, {required this.reverted});
  final int a;
  final int b;

  /// True when the swap made no match and the pieces go back.
  final bool reverted;
}

/// One "wave" of clearing (a cascade step).
class ClearEvent extends BoardEvent {
  const ClearEvent({
    required this.cascade,
    required this.cleared,
    required this.matched,
    required this.activations,
    required this.created,
    required this.armed,
    required this.caramel,
    required this.crates,
    required this.popups,
    required this.points,
    required this.status,
  });

  /// 1 for the first wave of a move, 2+ for chain reactions.
  final int cascade;
  final List<CellPiece> cleared;

  /// Cells cleared by a normal 3+ match (not by explosions).
  final List<int> matched;
  final List<Activation> activations;

  /// New special pieces placed this step.
  final List<CellPiece> created;

  /// Sweet Boxes that exploded once and now wait to explode again.
  final List<CellPiece> armed;
  final List<CellValue> caramel;
  final List<CellValue> crates;
  final List<ScorePopup> popups;
  final int points;
  final Status status;
}

/// Pieces changing type in place (Toffee Swirl combos, Sweet Box booster).
class ConvertEvent extends BoardEvent {
  const ConvertEvent(this.origin, this.changes);

  /// Where the effect comes from (-1 = none).
  final int origin;
  final List<CellPiece> changes;
}

/// How one piece moves during gravity.
///
/// [cells] and [ticks] are waypoints: the piece is at `cells[k]` at time
/// `ticks[k]` (1 tick = one cell of falling). A [spawned] piece appears one
/// cell above `cells.first`, one tick before `ticks.first`.
class FallPath {
  FallPath(this.piece, {required this.spawned});
  final Piece piece;
  final bool spawned;
  final List<int> cells = [];
  final List<int> ticks = [];
}

class FallEvent extends BoardEvent {
  const FallEvent(this.paths, this.totalTicks);
  final List<FallPath> paths;
  final int totalTicks;
}

class NutsCollectedEvent extends BoardEvent {
  const NutsCollectedEvent(this.nuts, this.status);
  final List<CellPiece> nuts;
  final Status status;
}

/// The board had no possible move and was shuffled. [after] lists every
/// shuffled piece at its new cell (pieces may also have changed color).
class ShuffleEvent extends BoardEvent {
  const ShuffleEvent(this.after);
  final List<CellPiece> after;
}

/// A booster removed or changed something (for sounds/effects).
class BoosterEvent extends BoardEvent {
  const BoosterEvent(this.booster, this.cell);
  final String booster;
  final int cell;
}
