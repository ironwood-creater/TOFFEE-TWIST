import 'board.dart';
import 'events.dart';
import 'goals.dart';
import 'level.dart';
import 'match_finder.dart';
import 'rng.dart';
import 'types.dart';

/// Point values.
abstract final class Scoring {
  static const sweet = 30;
  static const striped = 120;
  static const box = 180;
  static const swirl = 300;
  static const caramelLayer = 60;
  static const crateHit = 60;
  static const nut = 400;

  /// Bonus for every move left when a level is won ("Sweet Finale").
  static const finalePerMove = 250;
  static const maxMultiplier = 10;
}

/// Numbers describing one clearing step (used by the bot to rate moves).
class StepStats {
  int sweets = 0;
  int caramelLayers = 0;
  int caramelCleared = 0;
  int crateHits = 0;
  int cratesBroken = 0;
  int stripedMade = 0;
  int boxMade = 0;
  int swirlMade = 0;
  int activations = 0;
  int points = 0;
  final List<int> colorCounts = List<int>.filled(6, 0);
  final List<int> clearedCells = [];
}

/// Result of a player action.
class MoveResult {
  const MoveResult(this.valid, this.events);
  static const invalid = MoveResult(false, []);

  /// False if the action was not allowed (nothing changed, no move used).
  final bool valid;
  final List<BoardEvent> events;
}

enum _ActKind { row, column, blast, color }

class _Act {
  const _Act(this.kind, this.origin, {this.radius = 1, this.color = -1});
  final _ActKind kind;
  final int origin;
  final int radius;
  final int color;
}

/// Data collected while one wave of clearing happens.
class _Step {
  _Step(this.cascade);

  final int cascade;
  final hit = <int>{};
  final crateHit = <int>{};
  final queue = <_Act>[];
  var queueIndex = 0;
  final stats = StepStats();
  int points = 0;

  final cleared = <CellPiece>[];
  final matched = <int>[];
  final activations = <Activation>[];
  final created = <CellPiece>[];
  final armed = <CellPiece>[];
  final caramel = <CellValue>[];
  final crates = <CellValue>[];
  final popups = <ScorePopup>[];

  int get multiplier => cascade < Scoring.maxMultiplier ? cascade : Scoring.maxMultiplier;
}

/// The complete match-3 rules for one level attempt.
///
/// Call [swap], [useRollingPin] or [freeSwap]; each returns the list of
/// [BoardEvent]s that the animation layer plays. The engine state ([board],
/// [score], [goals], [movesLeft], [status]) is already final when they return.
class GameEngine {
  GameEngine(this.level, {required int seed, this.recordEvents = true})
      : rng = Rng(seed),
        board = Board.fromLevel(level),
        movesLeft = level.moves {
    goals = GoalTracker.forLevel(level, board);
    _nutGoal = level.goalOf(GoalType.nuts);
    _fillInitial();
  }

  GameEngine._clone(GameEngine o)
      : level = o.level,
        rng = o.rng.copy(),
        board = o.board.clone(),
        recordEvents = false,
        movesLeft = o.movesLeft {
    goals = o.goals.copy();
    _nutGoal = o._nutGoal;
    _nextId = o._nextId;
    movesUsed = o.movesUsed;
    score = o.score;
    status = o.status;
    nutsCollected = o.nutsCollected;
    _nutsOnBoard = o._nutsOnBoard;
  }

  final LevelDef level;
  final Rng rng;
  final Board board;

  /// When false (simulator), no event objects are built (faster).
  final bool recordEvents;
  late GoalTracker goals;
  GoalDef? _nutGoal;

  int movesLeft;
  int movesUsed = 0;
  int score = 0;
  int finaleBonus = 0;
  GameStatus status = GameStatus.playing;
  int nutsCollected = 0;
  int _nutsOnBoard = 0;
  int _nextId = 1;
  bool _nutSpawnedThisFall = false;

  /// A copy for "what if" checks (bot, hints). Events are not recorded.
  GameEngine clone() => GameEngine._clone(this);

  Status get statusSnapshot => Status(score, goals.snapshot());

  /// Stars earned so far (0 unless the level is won).
  int get stars {
    if (status != GameStatus.won) return 0;
    var s = 1;
    if (score >= level.stars[1]) s++;
    if (score >= level.stars[2]) s++;
    return s;
  }

  List<Move> possibleMoves() => findPossibleMoves(board);

  // ---------------------------------------------------------------------------
  // Player actions
  // ---------------------------------------------------------------------------

  /// Swaps two neighbouring pieces. Uses a move if it is valid.
  MoveResult swap(int a, int b) => _swap(a, b, free: false);

  /// "Free Swap" booster: swaps any two neighbours, needs no match, uses no move.
  MoveResult freeSwap(int a, int b) => _swap(a, b, free: true);

  MoveResult _swap(int a, int b, {required bool free}) {
    if (status != GameStatus.playing) return MoveResult.invalid;
    if (a < 0 || b < 0 || a >= board.length || b >= board.length) {
      return MoveResult.invalid;
    }
    if (!board.areAdjacent(a, b)) return MoveResult.invalid;
    final pa = board.pieces[a];
    final pb = board.pieces[b];
    if (pa == null || pb == null || !pa.swappable || !pb.swappable) {
      return MoveResult.invalid;
    }
    final ev = recordEvents ? <BoardEvent>[] : null;
    final combo = _isCombo(pa, pb);
    board.pieces[a] = pb;
    board.pieces[b] = pa;
    final matches = combo || hasMatchAt(board, a) || hasMatchAt(board, b);
    if (!matches && !free) {
      board.pieces[a] = pa;
      board.pieces[b] = pb;
      return MoveResult(false, [if (ev != null) SwapEvent(a, b, reverted: true)]);
    }
    if (!free) {
      movesLeft--;
      movesUsed++;
    }
    ev?.add(SwapEvent(a, b, reverted: false));
    if (free) ev?.add(BoosterEvent('freeSwap', b));
    _resolve(ev, swapCells: [b, a], combo: combo ? (a, b) : null);
    _afterAction(ev);
    return MoveResult(true, ev ?? const []);
  }

  /// "Rolling Pin" booster: smashes one piece (or hits a crate). No move used.
  MoveResult useRollingPin(int cell) {
    if (status != GameStatus.playing) return MoveResult.invalid;
    if (cell < 0 || cell >= board.length || !board.playable[cell]) {
      return MoveResult.invalid;
    }
    final p = board.pieces[cell];
    if (board.crate[cell] == 0 && (p == null || p.isNut)) return MoveResult.invalid;
    final ev = recordEvents ? <BoardEvent>[BoosterEvent('rollingPin', cell)] : null;
    final step = _Step(1);
    _hit(step, cell);
    _resolve(ev, firstStep: step);
    _afterAction(ev);
    return MoveResult(true, ev ?? const []);
  }

  /// "Sweet Box start" booster: turns one sweet near the middle into a Sweet Box.
  List<BoardEvent> applyStartBox() {
    final candidates = <int>[];
    final fallback = <int>[];
    for (var i = 0; i < board.length; i++) {
      final p = board.pieces[i];
      if (p == null || p.isSpecial || p.isNut || p.color < 0) continue;
      final r = board.rowOf(i);
      final c = board.colOf(i);
      final central = r >= 2 && r <= board.rows - 3 && c >= 2 && c <= board.cols - 3;
      (central ? candidates : fallback).add(i);
    }
    final pool = candidates.isNotEmpty ? candidates : fallback;
    if (pool.isEmpty) return const [];
    final cell = rng.pick(pool);
    final boxed = board.pieces[cell]!.copyWith(special: Special.box);
    board.pieces[cell] = boxed;
    return [ConvertEvent(-1, [CellPiece(cell, boxed)])];
  }

  /// Shuffles the board if no move is possible (returns no events otherwise).
  List<BoardEvent> shuffleIfNeeded() {
    if (hasPossibleMove(board)) return const [];
    final ev = <BoardEvent>[];
    _shuffle(ev);
    return ev;
  }

  /// Extra moves (+3 booster, +5 after losing). Continues a lost game.
  void addMoves(int n) {
    movesLeft += n;
    if (status == GameStatus.lost && movesLeft > 0) status = GameStatus.playing;
  }

  /// Adds the bonus for unused moves once the level is won. Returns it.
  int applyFinale() {
    if (status != GameStatus.won || finaleBonus > 0) return 0;
    finaleBonus = movesLeft * Scoring.finalePerMove;
    score += finaleBonus;
    goals.onScore(score);
    return finaleBonus;
  }

  /// A good move to show as a hint (or null if there is none).
  Move? hint() {
    final moves = possibleMoves();
    if (moves.isEmpty) return null;
    Move? best;
    var bestValue = -1.0;
    for (final m in moves) {
      final s = preview(m);
      final v = s.sweets +
          s.stripedMade * 6 +
          s.boxMade * 8 +
          s.swirlMade * 14 +
          s.caramelLayers * 3 +
          s.crateHits * 3 +
          s.activations * 4.0;
      if (v > bestValue) {
        bestValue = v;
        best = m;
      }
    }
    return best;
  }

  /// What the first clearing wave of [m] would do (no gravity, no refill).
  StepStats preview(Move m) => clone()._previewSwap(m.a, m.b);

  StepStats _previewSwap(int a, int b) {
    final pa = board.pieces[a]!;
    final pb = board.pieces[b]!;
    final combo = _isCombo(pa, pb);
    board.pieces[a] = pb;
    board.pieces[b] = pa;
    final step = _Step(1);
    if (combo) _applyCombo(step, a, b, null);
    final creations = <(int, Piece)>[];
    for (final g in findMatches(board)) {
      _applyGroup(step, g, [b, a], creations);
    }
    _runQueue(step);
    step.stats.points = step.points;
    return step.stats;
  }

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  Piece _newSweet(int color) => Piece(id: _nextId++, color: color);
  Piece _newNut() => Piece(id: _nextId++, color: -1, isNut: true);

  void _fillInitial() {
    final preset = level.preset;
    final fixed = List<bool>.filled(board.length, false);
    var nutsPlaced = 0;
    for (var i = 0; i < board.length; i++) {
      if (!board.holdsPiece(i)) continue;
      final r = board.rowOf(i);
      final c = board.colOf(i);
      final ch = level.board[r][c];
      if (ch == 'n' && _nutGoal != null && nutsPlaced < _nutGoal!.target) {
        board.pieces[i] = _newNut();
        fixed[i] = true;
        nutsPlaced++;
        continue;
      }
      final presetSweet = preset == null ? null : Sweet.fromCode(preset[r][c]);
      if (presetSweet != null) {
        board.pieces[i] = _newSweet(presetSweet.index);
        fixed[i] = true;
      } else {
        board.pieces[i] = _newSweet(_safeColor(i));
      }
    }
    _nutsOnBoard = nutsPlaced;
    _breakMatches(fixed);
    final specials = level.presetSpecials;
    if (specials != null) {
      for (var i = 0; i < board.length; i++) {
        final p = board.pieces[i];
        if (p == null || p.isNut) continue;
        final code = specials[board.rowOf(i)][board.colOf(i)];
        final sp = switch (code) {
          '-' => Special.stripedH,
          '|' => Special.stripedV,
          'b' => Special.box,
          's' => Special.swirl,
          _ => null,
        };
        if (sp == null) continue;
        board.pieces[i] = Piece(id: p.id, color: sp == Special.swirl ? -1 : p.color, special: sp);
      }
    }
    for (var attempt = 0; attempt < 30 && !hasPossibleMove(board); attempt++) {
      for (var i = 0; i < board.length; i++) {
        final p = board.pieces[i];
        if (!fixed[i] && p != null && !p.isSpecial) board.pieces[i] = _newSweet(_safeColor(i));
      }
      _breakMatches(fixed);
    }
    if (!hasPossibleMove(board)) _shuffle(null);
  }

  /// A random level color that does not complete a line with the pieces to
  /// the left or above.
  int _safeColor(int i) {
    final colors = level.colors;
    final start = rng.nextInt(colors.length);
    for (var k = 0; k < colors.length; k++) {
      final color = colors[(start + k) % colors.length];
      if (!_wouldMatch(i, color)) return color;
    }
    return colors[start];
  }

  bool _wouldMatch(int i, int color) {
    final r = board.rowOf(i);
    final c = board.colOf(i);
    int col(int rr, int cc) =>
        (rr < 0 || cc < 0 || rr >= board.rows || cc >= board.cols)
            ? -1
            : board.matchColor(rr * board.cols + cc);
    if (col(r, c - 1) == color && col(r, c - 2) == color) return true;
    if (col(r, c + 1) == color && col(r, c + 2) == color) return true;
    if (col(r, c - 1) == color && col(r, c + 1) == color) return true;
    if (col(r - 1, c) == color && col(r - 2, c) == color) return true;
    if (col(r + 1, c) == color && col(r + 2, c) == color) return true;
    if (col(r - 1, c) == color && col(r + 1, c) == color) return true;
    return false;
  }

  /// Recolors free sweets until no 3-in-a-row is left.
  void _breakMatches(List<bool>? fixed) {
    for (var iter = 0; iter < 60; iter++) {
      final groups = findMatches(board);
      if (groups.isEmpty) return;
      for (final g in groups) {
        final free = [
          for (final c in g.cells)
            if ((fixed == null || !fixed[c]) && !board.pieces[c]!.isSpecial) c,
        ];
        if (free.isEmpty) continue;
        final cell = free[rng.nextInt(free.length)];
        final p = board.pieces[cell]!;
        final options = [
          for (final color in level.colors)
            if (color != p.color && !_wouldMatch(cell, color)) color,
        ];
        final others = [
          for (final color in level.colors)
            if (color != p.color) color,
        ];
        final color = options.isNotEmpty ? rng.pick(options) : rng.pick(others);
        board.pieces[cell] = p.copyWith(color: color);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Resolution
  // ---------------------------------------------------------------------------

  static bool _isCombo(Piece a, Piece b) =>
      (a.isSpecial && b.isSpecial) ||
      (a.isSwirl && b.matchable) ||
      (b.isSwirl && a.matchable);

  /// Clears matches and specials, then applies gravity, again and again
  /// until the board is calm (cascades).
  void _resolve(
    List<BoardEvent>? ev, {
    List<int> swapCells = const [],
    (int, int)? combo,
    _Step? firstStep,
  }) {
    var cascade = 0;
    var preferred = swapCells;
    var pendingCombo = combo;
    var pendingStep = firstStep;
    while (cascade < 200) {
      final groups = findMatches(board);
      final armedCells = <int>[
        for (var i = 0; i < board.length; i++)
          if (board.pieces[i]?.armed ?? false) i,
      ];
      if (pendingCombo == null && pendingStep == null && groups.isEmpty && armedCells.isEmpty) {
        break;
      }
      cascade++;
      final step = pendingStep ?? _Step(cascade);
      pendingStep = null;
      if (pendingCombo != null) {
        _applyCombo(step, pendingCombo.$1, pendingCombo.$2, ev);
        pendingCombo = null;
      }
      for (final cell in armedCells) {
        _hit(step, cell);
      }
      final creations = <(int, Piece)>[];
      for (final g in groups) {
        _applyGroup(step, g, preferred, creations);
      }
      _runQueue(step);
      for (final (cell, piece) in creations) {
        if (board.pieces[cell] == null && board.holdsPiece(cell)) {
          board.pieces[cell] = piece;
          step.created.add(CellPiece(cell, piece));
        }
      }
      score += step.points;
      goals.onScore(score);
      if (ev != null) {
        ev.add(ClearEvent(
          cascade: step.cascade,
          cleared: step.cleared,
          matched: step.matched,
          activations: step.activations,
          created: step.created,
          armed: step.armed,
          caramel: step.caramel,
          crates: step.crates,
          popups: step.popups,
          points: step.points,
          status: statusSnapshot,
        ));
      }
      preferred = _settle(ev);
    }
  }

  void _afterAction(List<BoardEvent>? ev) {
    if (goals.allDone) {
      status = GameStatus.won;
      return;
    }
    if (movesLeft <= 0) {
      status = GameStatus.lost;
      return;
    }
    if (!hasPossibleMove(board)) _shuffle(ev);
  }

  void _applyGroup(_Step s, MatchGroup g, List<int> preferred, List<(int, Piece)> creations) {
    final before = s.points;
    final special = g.special;
    final pos = special == Special.none ? null : _pickSpecialCell(g, special, preferred);
    for (final cell in g.cells) {
      s.matched.add(cell);
      _hit(s, cell);
    }
    for (final cell in g.cells) {
      for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final n = board.neighbor(cell, dr, dc);
        if (n >= 0 && board.playable[n] && board.crate[n] > 0) _hitCrate(s, n);
      }
    }
    if (pos != null) {
      final piece = Piece(
        id: _nextId++,
        color: special == Special.swirl ? -1 : g.color,
        special: special,
      );
      creations.add((pos, piece));
      switch (special) {
        case Special.stripedH || Special.stripedV:
          s.points += Scoring.striped;
          s.stats.stripedMade++;
        case Special.box:
          s.points += Scoring.box;
          s.stats.boxMade++;
        case Special.swirl:
          s.points += Scoring.swirl;
          s.stats.swirlMade++;
        case Special.none:
          break;
      }
    }
    s.popups.add(ScorePopup(pos ?? g.cells[g.cells.length ~/ 2], s.points - before));
  }

  int? _pickSpecialCell(MatchGroup g, Special special, List<int> preferred) {
    bool ok(int c) {
      final p = board.pieces[c];
      return p != null && !p.isSpecial;
    }

    for (final p in preferred) {
      if (g.cells.contains(p) && ok(p)) return p;
    }
    if (special == Special.box) {
      final x = g.intersection;
      if (x != null && ok(x)) return x;
    }
    final mid = g.middle;
    if (ok(mid)) return mid;
    for (final c in g.cells) {
      if (ok(c)) return c;
    }
    return null;
  }

  /// Hits one cell: clears the piece (activating specials), peels caramel,
  /// damages crates. Each cell is hit at most once per step.
  void _hit(_Step s, int cell) {
    if (!board.playable[cell]) return;
    if (board.crate[cell] > 0) {
      _hitCrate(s, cell);
      return;
    }
    if (!s.hit.add(cell)) return;
    final p = board.pieces[cell];
    if (p == null || p.isNut) return;
    _hitCaramel(s, cell);
    if (p.isBox && !p.armed) {
      // First explosion: the box stays (armed) and explodes again later.
      final armed = p.copyWith(armed: true);
      board.pieces[cell] = armed;
      s.armed.add(CellPiece(cell, armed));
      s.queue.add(_Act(_ActKind.blast, cell, radius: 1));
      s.points += Scoring.sweet * s.multiplier;
      s.stats.activations++;
      return;
    }
    _remove(s, cell, p);
    if (p.armed) {
      s.queue.add(_Act(_ActKind.blast, cell, radius: p.big ? 2 : 1));
      s.stats.activations++;
      return;
    }
    switch (p.special) {
      case Special.stripedH:
        s.queue.add(_Act(_ActKind.row, cell));
        s.stats.activations++;
      case Special.stripedV:
        s.queue.add(_Act(_ActKind.column, cell));
        s.stats.activations++;
      case Special.swirl:
        s.queue.add(_Act(_ActKind.color, cell, color: _mostCommonColor()));
        s.stats.activations++;
      case Special.box || Special.none:
        break;
    }
  }

  void _remove(_Step s, int cell, Piece p) {
    board.pieces[cell] = null;
    s.cleared.add(CellPiece(cell, p));
    s.stats.sweets++;
    s.stats.clearedCells.add(cell);
    if (p.color >= 0) s.stats.colorCounts[p.color]++;
    goals.onSweetCleared(p.color);
    s.points += Scoring.sweet * s.multiplier;
  }

  /// Removes a piece without triggering its own effect (used by combos).
  void _removeQuiet(_Step s, int cell) {
    final p = board.pieces[cell];
    s.hit.add(cell);
    if (p == null) return;
    _hitCaramel(s, cell);
    _remove(s, cell, p);
  }

  void _hitCaramel(_Step s, int cell) {
    if (board.caramel[cell] <= 0) return;
    board.caramel[cell]--;
    s.caramel.add(CellValue(cell, board.caramel[cell]));
    s.points += Scoring.caramelLayer;
    s.stats.caramelLayers++;
    if (board.caramel[cell] == 0) {
      s.stats.caramelCleared++;
      goals.onCaramelCleared();
    }
  }

  void _hitCrate(_Step s, int cell) {
    if (board.crate[cell] <= 0 || !s.crateHit.add(cell)) return;
    board.crate[cell]--;
    s.crates.add(CellValue(cell, board.crate[cell]));
    s.points += Scoring.crateHit;
    s.stats.crateHits++;
    if (board.crate[cell] == 0) {
      s.stats.cratesBroken++;
      goals.onCrateBroken();
    }
  }

  int _mostCommonColor() {
    final counts = List<int>.filled(6, 0);
    for (final p in board.pieces) {
      if (p != null && p.matchable) counts[p.color]++;
    }
    var best = -1;
    var bestCount = 0;
    for (final c in level.colors) {
      if (counts[c] > bestCount) {
        bestCount = counts[c];
        best = c;
      }
    }
    return best;
  }

  List<int> _cellsOfColor(int color) => [
        for (var i = 0; i < board.length; i++)
          if (board.pieces[i] != null &&
              board.pieces[i]!.matchable &&
              board.pieces[i]!.color == color)
            i,
      ];

  void _runQueue(_Step s) {
    while (s.queueIndex < s.queue.length) {
      final a = s.queue[s.queueIndex++];
      final before = s.points;
      final r = board.rowOf(a.origin);
      final c = board.colOf(a.origin);
      switch (a.kind) {
        case _ActKind.row:
          final t = [
            for (var k = 0; k < board.cols; k++)
              if (board.playable[r * board.cols + k]) r * board.cols + k,
          ];
          s.activations.add(Activation(EffectKind.lineH, a.origin, t));
          for (final cell in t) {
            _hit(s, cell);
          }
        case _ActKind.column:
          final t = [
            for (var k = 0; k < board.rows; k++)
              if (board.playable[k * board.cols + c]) k * board.cols + c,
          ];
          s.activations.add(Activation(EffectKind.lineV, a.origin, t));
          for (final cell in t) {
            _hit(s, cell);
          }
        case _ActKind.blast:
          final t = _square(r, c, a.radius);
          s.activations.add(Activation(EffectKind.blast, a.origin, t, radius: a.radius));
          for (final cell in t) {
            _hit(s, cell);
          }
        case _ActKind.color:
          if (a.color < 0) break;
          final t = _cellsOfColor(a.color);
          s.activations.add(Activation(EffectKind.swirl, a.origin, t, color: a.color));
          for (final cell in t) {
            _hit(s, cell);
          }
      }
      final gained = s.points - before;
      if (gained > 0) s.popups.add(ScorePopup(a.origin, gained));
    }
  }

  List<int> _square(int r, int c, int radius) => [
        for (var rr = r - radius; rr <= r + radius; rr++)
          for (var cc = c - radius; cc <= c + radius; cc++)
            if (rr >= 0 && cc >= 0 && rr < board.rows && cc < board.cols)
              if (board.playable[rr * board.cols + cc]) rr * board.cols + cc,
      ];

  /// Special + special (or swirl + sweet) effects. The pieces were already
  /// swapped: the dragged piece now sits at [b].
  void _applyCombo(_Step s, int a, int b, List<BoardEvent>? ev) {
    final p1 = board.pieces[b]!;
    final p2 = board.pieces[a]!;
    final r = board.rowOf(b);
    final c = board.colOf(b);
    s.stats.activations += 2;

    if (p1.isSwirl && p2.isSwirl) {
      _removeQuiet(s, a);
      _removeQuiet(s, b);
      final all = [
        for (var i = 0; i < board.length; i++)
          if (board.playable[i]) i,
      ];
      s.activations.add(Activation(EffectKind.boardClear, b, all));
      for (final cell in all) {
        _hit(s, cell);
      }
      return;
    }

    if (p1.isSwirl || p2.isSwirl) {
      final swirlCell = p1.isSwirl ? b : a;
      final otherCell = p1.isSwirl ? a : b;
      final other = board.pieces[otherCell]!;
      final color = other.color;
      _removeQuiet(s, swirlCell);
      if (other.isStriped || other.isBox) {
        final changes = <CellPiece>[];
        for (final cell in _cellsOfColor(color)) {
          final p = board.pieces[cell]!;
          if (p.isSpecial) continue;
          final sp = other.isBox
              ? Special.box
              : (rng.nextInt(2) == 0 ? Special.stripedH : Special.stripedV);
          final np = p.copyWith(special: sp);
          board.pieces[cell] = np;
          changes.add(CellPiece(cell, np));
        }
        ev?.add(ConvertEvent(swirlCell, changes));
      }
      final targets = _cellsOfColor(color);
      s.activations.add(Activation(EffectKind.swirl, swirlCell, targets, color: color));
      final before = s.points;
      for (final cell in targets) {
        _hit(s, cell);
      }
      s.popups.add(ScorePopup(swirlCell, s.points - before));
      return;
    }

    // Two specials without a swirl.
    if (p1.isBox && p2.isBox) {
      _removeQuiet(s, a);
      final big = p1.copyWith(armed: true, big: true);
      board.pieces[b] = big;
      s.hit.add(b);
      s.armed.add(CellPiece(b, big));
      s.queue.add(_Act(_ActKind.blast, b, radius: 2));
      return;
    }
    _removeQuiet(s, a);
    _removeQuiet(s, b);
    final before = s.points;
    if (p1.isStriped && p2.isStriped) {
      final t = <int>{
        for (var k = 0; k < board.cols; k++)
          if (board.playable[r * board.cols + k]) r * board.cols + k,
        for (var k = 0; k < board.rows; k++)
          if (board.playable[k * board.cols + c]) k * board.cols + c,
      }.toList();
      s.activations.add(Activation(EffectKind.cross, b, t));
      for (final cell in t) {
        _hit(s, cell);
      }
    } else {
      // Striped + Sweet Box: 3 rows and 3 columns.
      final t = <int>{};
      for (var dr = -1; dr <= 1; dr++) {
        final rr = r + dr;
        if (rr < 0 || rr >= board.rows) continue;
        for (var k = 0; k < board.cols; k++) {
          if (board.playable[rr * board.cols + k]) t.add(rr * board.cols + k);
        }
      }
      for (var dc = -1; dc <= 1; dc++) {
        final cc = c + dc;
        if (cc < 0 || cc >= board.cols) continue;
        for (var k = 0; k < board.rows; k++) {
          if (board.playable[k * board.cols + cc]) t.add(k * board.cols + cc);
        }
      }
      final list = t.toList();
      s.activations.add(Activation(EffectKind.bigCross, b, list));
      for (final cell in list) {
        _hit(s, cell);
      }
    }
    s.popups.add(ScorePopup(b, s.points - before));
  }

  // ---------------------------------------------------------------------------
  // Gravity, refill and golden nuts
  // ---------------------------------------------------------------------------

  /// Drops pieces, refills, collects nuts. Returns the cells where pieces
  /// landed (bottom first), used to place specials from cascades.
  List<int> _settle(List<BoardEvent>? ev) {
    final moved = <int>{};
    _gravity(ev, moved);
    while (true) {
      final nuts = <CellPiece>[];
      for (var c = 0; c < board.cols; c++) {
        final e = board.exitCell[c];
        if (e < 0) continue;
        final p = board.pieces[e];
        if (p != null && p.isNut) {
          nuts.add(CellPiece(e, p));
          board.pieces[e] = null;
          moved.remove(e);
          nutsCollected++;
          _nutsOnBoard--;
          goals.onNutCollected();
          score += Scoring.nut;
        }
      }
      if (nuts.isEmpty) break;
      goals.onScore(score);
      ev?.add(NutsCollectedEvent(nuts, statusSnapshot));
      _gravity(ev, moved);
    }
    return moved.toList()..sort((x, y) => y.compareTo(x));
  }

  Piece _spawnPiece() {
    final g = _nutGoal;
    if (g != null && !_nutSpawnedThisFall) {
      final pending = g.target - nutsCollected - _nutsOnBoard;
      if (pending > 0 && _nutsOnBoard < g.maxOnBoard && rng.chance(0.4)) {
        _nutsOnBoard++;
        _nutSpawnedThisFall = true;
        return _newNut();
      }
    }
    return _newSweet(rng.pick(level.colors));
  }

  /// True if the empty cell [i] cannot be refilled from straight above
  /// because a crate blocks the column.
  bool _starved(int i) {
    var k = board.above[i];
    while (k >= 0) {
      if (board.crate[k] > 0) return true;
      if (board.pieces[k] != null) return false;
      k = board.above[k];
    }
    return false;
  }

  void _gravity(List<BoardEvent>? ev, Set<int> moved) {
    final b = board;
    final paths = ev != null ? <int, FallPath>{} : null;
    _nutSpawnedThisFall = false;
    var tick = 0;

    void track(Piece p, int from, int to) {
      moved.remove(from);
      moved.add(to);
      if (paths == null) return;
      final path = paths.putIfAbsent(p.id, () => FallPath(p, spawned: false));
      if (path.cells.isEmpty || path.ticks.last < tick - 1) {
        path.cells.add(from);
        path.ticks.add(tick - 1);
      }
      path.cells.add(to);
      path.ticks.add(tick);
    }

    while (tick < 400) {
      tick++;
      var any = false;
      // 1) Straight down (bottom rows first, so each piece moves one cell).
      for (var i = b.length - 1; i >= 0; i--) {
        if (b.pieces[i] != null || !b.holdsPiece(i)) continue;
        final src = b.above[i];
        if (src < 0 || b.crate[src] > 0) continue;
        final p = b.pieces[src];
        if (p == null) continue;
        b.pieces[i] = p;
        b.pieces[src] = null;
        track(p, src, i);
        any = true;
      }
      // 2) New pieces at the top of each column.
      for (var c = 0; c < b.cols; c++) {
        final s = b.spawnCell[c];
        if (s < 0 || b.crate[s] > 0 || b.pieces[s] != null) continue;
        final p = _spawnPiece();
        b.pieces[s] = p;
        moved.add(s);
        if (paths != null) {
          paths[p.id] = FallPath(p, spawned: true)
            ..cells.add(s)
            ..ticks.add(tick);
        }
        any = true;
      }
      // 3) When nothing else moves, slide one piece diagonally into a cell
      //    that a crate keeps from being refilled.
      if (!any) {
        outer:
        for (var i = b.length - 1; i >= 0; i--) {
          if (b.pieces[i] != null || !b.holdsPiece(i) || !_starved(i)) continue;
          final r = b.rowOf(i);
          if (r == 0) continue;
          final c = b.colOf(i);
          final order = ((r + c + tick) & 1) == 0 ? const [-1, 1] : const [1, -1];
          for (final dc in order) {
            final cc = c + dc;
            if (cc < 0 || cc >= b.cols) continue;
            final j = (r - 1) * b.cols + cc;
            if (!b.holdsPiece(j)) continue;
            final p = b.pieces[j];
            if (p == null) continue;
            b.pieces[i] = p;
            b.pieces[j] = null;
            track(p, j, i);
            any = true;
            break outer;
          }
        }
      }
      if (!any) break;
    }
    if (paths != null && paths.isNotEmpty) {
      ev!.add(FallEvent(paths.values.toList(), tick - 1));
    }
  }

  // ---------------------------------------------------------------------------
  // Reshuffle
  // ---------------------------------------------------------------------------

  void _shuffle(List<BoardEvent>? ev) {
    final cells = <int>[
      for (var i = 0; i < board.length; i++)
        if (board.pieces[i] != null && !board.pieces[i]!.isNut && !board.pieces[i]!.armed) i,
    ];
    if (cells.length < 2) return;
    final pieces = [for (final c in cells) board.pieces[c]!];
    var ok = false;
    for (var attempt = 0; attempt < 300 && !ok; attempt++) {
      if (attempt >= 100) {
        for (var k = 0; k < pieces.length; k++) {
          if (!pieces[k].isSpecial) pieces[k] = pieces[k].copyWith(color: rng.pick(level.colors));
        }
      }
      rng.shuffle(pieces);
      for (var k = 0; k < cells.length; k++) {
        board.pieces[cells[k]] = pieces[k];
      }
      ok = findMatches(board).isEmpty && hasPossibleMove(board);
    }
    if (!ok) {
      _breakMatches(null);
      if (!hasPossibleMove(board)) {
        // Last resort: a Toffee Swirl next to a sweet is always a valid move.
        for (final cell in cells) {
          final p = board.pieces[cell];
          if (p == null || p.isSpecial) continue;
          board.pieces[cell] = Piece(id: p.id, color: -1, special: Special.swirl);
          if (hasPossibleMove(board)) break;
          board.pieces[cell] = p;
        }
      }
    }
    ev?.add(ShuffleEvent([for (final c in cells) CellPiece(c, board.pieces[c]!)]));
    if (findMatches(board).isNotEmpty) _resolve(ev);
  }
}
