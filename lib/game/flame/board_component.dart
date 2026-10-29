import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../services/services.dart';
import '../../theme.dart';
import '../game_session.dart';
import '../logic/board.dart';
import '../logic/events.dart';
import '../logic/types.dart';
import '../render/sweet_art.dart';
import 'fx_layer.dart';
import 'particles.dart';
import 'piece_sprite.dart';
import 'sprite_cache.dart';

class _Timer {
  _Timer(this.left, this.fn);
  double left;
  final void Function() fn;
}

/// The board on screen: draws tiles and blockers, holds the piece sprites,
/// reads swipes/taps and plays the engine's events as animations.
class BoardComponent extends PositionComponent with DragCallbacks, TapCallbacks
    implements BoardView {
  BoardComponent(this.session, {required this.pixelRatio});

  final GameSession session;
  final double pixelRatio;

  static const double tickTime = 0.055;
  static const double hintDelay = 5;

  double tile = 40;
  SpriteCache? _sprites;
  late List<PieceSprite?> _cells;
  final Map<int, PieceSprite> _byId = {};
  late final ParticleLayer particles = ParticleLayer();
  late final FxLayer fx = FxLayer();

  // Local copies of blockers so they change in step with the animations.
  late List<int> _caramel;
  late List<int> _crates;
  ui.Picture? _bg;
  bool _bgDirty = true;

  Vector2 _basePos = Vector2.zero();
  double _shake = 0;
  final _rand = math.Random();
  final List<_Timer> _timers = [];

  int _selected = -1;
  int _dragCell = -1;
  final Vector2 _drag = Vector2.zero();
  double _idle = 0;
  Move? _hint;

  Board get board => session.engine.board;

  @override
  Future<void> onLoad() async {
    _cells = List<PieceSprite?>.filled(board.length, null);
    _caramel = List.of(board.caramel);
    _crates = List.of(board.crate);
    await add(fx);
    await add(particles);
    session.view = this;
  }

  /// Fits the board into [area] (the space Flutter gives the game).
  void layout(Vector2 area) {
    final t = math.min(area.x / board.cols, area.y / board.rows).floorToDouble();
    tile = t.clamp(18.0, 96.0);
    size = Vector2(board.cols * tile, board.rows * tile);
    _basePos = Vector2(((area.x - size.x) / 2).roundToDouble(), ((area.y - size.y) / 2).roundToDouble());
    position = _basePos.clone();
    final px = (tile * pixelRatio).round().clamp(32, 256);
    if (_sprites?.pixelSize != px) {
      final old = _sprites;
      _sprites = SpriteCache(px);
      for (final s in _byId.values) {
        s.image = _sprites!.imageFor(s.piece);
      }
      old?.dispose();
    }
    for (final s in _byId.values) {
      s.size = Vector2.all(tile);
    }
    _bgDirty = true;
    _syncAll();
  }

  SpriteCache get sprites => _sprites!;

  Vector2 cellCenter(int cell) =>
      Vector2((board.colOf(cell) + 0.5) * tile, (board.rowOf(cell) + 0.5) * tile);
  Offset cellOffset(int cell) => cellCenter(cell).toOffset();
  Rect cellRect(int cell) =>
      Rect.fromLTWH(board.colOf(cell) * tile, board.rowOf(cell) * tile, tile, tile);

  // ---------------------------------------------------------------------------
  // Sprites bookkeeping
  // ---------------------------------------------------------------------------

  PieceSprite _create(Piece p, Vector2 at) {
    final s = PieceSprite(p, sprites.imageFor(p), tile)..position = at.clone();
    _byId[p.id] = s;
    add(s);
    return s;
  }

  void _setPiece(PieceSprite s, Piece p) {
    s.piece = p;
    s.image = sprites.imageFor(p);
  }

  void _discard(PieceSprite s) {
    _byId.remove(s.piece.id);
    for (var i = 0; i < _cells.length; i++) {
      if (identical(_cells[i], s)) _cells[i] = null;
    }
  }

  /// Makes the screen match the engine exactly (after every move).
  void _syncAll() {
    if (_sprites == null) return;
    final alive = <int>{};
    for (var i = 0; i < board.length; i++) {
      final p = board.pieces[i];
      if (p == null) {
        _cells[i] = null;
        continue;
      }
      alive.add(p.id);
      var s = _byId[p.id];
      s ??= _create(p, cellCenter(i));
      if (!identical(s.piece, p)) _setPiece(s, p);
      s
        ..position = cellCenter(i)
        ..opacity = 1
        ..scaleK = 1
        ..squashX = 1
        ..squashY = 1
        ..selected = false
        ..hinting = false;
      _cells[i] = s;
    }
    for (final id in _byId.keys.toList()) {
      if (!alive.contains(id)) _byId.remove(id)!.removeFromParent();
    }
    for (var i = 0; i < board.length; i++) {
      if (_caramel[i] != board.caramel[i] || _crates[i] != board.crate[i]) {
        _caramel[i] = board.caramel[i];
        _crates[i] = board.crate[i];
        _bgDirty = true;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Frame loop
  // ---------------------------------------------------------------------------

  Future<void> wait(double seconds) {
    final c = Completer<void>();
    _timers.add(_Timer(seconds, c.complete));
    return c.future;
  }

  void after(double seconds, void Function() fn) {
    if (seconds <= 0) {
      fn();
    } else {
      _timers.add(_Timer(seconds, fn));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_timers.isNotEmpty) {
      final due = <_Timer>[];
      for (final t in _timers) {
        t.left -= dt;
        if (t.left <= 0) due.add(t);
      }
      for (final t in due) {
        _timers.remove(t);
        t.fn();
      }
    }
    if (_shake > 0) {
      _shake = math.max(0, _shake - dt);
      final m = _shake * tile * 0.5;
      position.setValues(
          _basePos.x + (_rand.nextDouble() - 0.5) * m, _basePos.y + (_rand.nextDouble() - 0.5) * m);
    } else if (position != _basePos) {
      position.setFrom(_basePos);
    }
    if (session.canAct && session.boosterMode == BoosterMode.none) {
      _idle += dt;
      if (_idle > hintDelay && _hint == null) _showHint();
    }
  }

  void shake(double strength) {
    _shake = math.max(_shake, strength);
  }

  @override
  void resetIdle() {
    _idle = 0;
    if (_hint != null) {
      for (final s in _byId.values) {
        s.hinting = false;
      }
      _hint = null;
    }
  }

  void _showHint() {
    final m = session.engine.hint();
    if (m == null) return;
    _hint = m;
    _cells[m.a]?.hinting = true;
    _cells[m.b]?.hinting = true;
  }

  // ---------------------------------------------------------------------------
  // Drawing the board (tray, tiles, caramel, crates) - cached as a picture
  // ---------------------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    if (_bgDirty || _bg == null) {
      _bg?.dispose();
      _bg = _paintBackground();
      _bgDirty = false;
    }
    canvas.drawPicture(_bg!);
    if (session.boosterMode != BoosterMode.none) {
      final r = RRect.fromRectAndRadius(
          (Vector2.zero() & size).inflate(tile * 0.14), Radius.circular(tile * 0.3));
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFFFD54F),
      );
    }
  }

  ui.Picture _paintBackground() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final shadow = Paint()..color = const Color(0x44000000);
    final tray = Paint()..color = AppColors.chocolate;
    final trayEdge = Paint()..color = AppColors.chocolateDark;
    final radius = Radius.circular(tile * 0.24);
    for (var i = 0; i < board.length; i++) {
      if (!board.playable[i]) continue;
      c.drawRRect(RRect.fromRectAndRadius(cellRect(i).inflate(tile * 0.12).shift(Offset(0, tile * 0.07)), radius),
          shadow);
    }
    for (var i = 0; i < board.length; i++) {
      if (!board.playable[i]) continue;
      c.drawRRect(RRect.fromRectAndRadius(cellRect(i).inflate(tile * 0.12), radius), trayEdge);
    }
    for (var i = 0; i < board.length; i++) {
      if (!board.playable[i]) continue;
      c.drawRRect(RRect.fromRectAndRadius(cellRect(i).inflate(tile * 0.08), radius), tray);
    }
    final light = Paint()..color = AppColors.tileLight;
    final dark = Paint()..color = AppColors.tileDark;
    for (var i = 0; i < board.length; i++) {
      if (!board.playable[i]) continue;
      final even = (board.rowOf(i) + board.colOf(i)).isEven;
      c.drawRRect(RRect.fromRectAndRadius(cellRect(i).deflate(tile * 0.025), Radius.circular(tile * 0.14)),
          even ? light : dark);
    }
    for (var i = 0; i < board.length; i++) {
      if (_caramel[i] > 0) SweetArt.paintCaramel(c, cellRect(i), _caramel[i]);
      if (_crates[i] > 0) SweetArt.paintCrate(c, cellRect(i), _crates[i]);
    }
    // Golden arrows under the exit cells on golden nut levels.
    if (session.level.goals.any((g) => g.type.name == 'nuts')) {
      final arrow = Paint()..color = const Color(0xCCFFC928);
      for (var col = 0; col < board.cols; col++) {
        final e = board.exitCell[col];
        if (e < 0) continue;
        final r = cellRect(e);
        final y = r.bottom + tile * 0.1;
        final path = Path()
          ..moveTo(r.center.dx - tile * 0.16, y)
          ..lineTo(r.center.dx + tile * 0.16, y)
          ..lineTo(r.center.dx, y + tile * 0.16)
          ..close();
        c.drawPath(path, arrow);
      }
    }
    return rec.endRecording();
  }

  // ---------------------------------------------------------------------------
  // Input: swipe, or tap one sweet then a neighbour
  // ---------------------------------------------------------------------------

  int _cellAt(Vector2 local) {
    final c = (local.x / tile).floor();
    final r = (local.y / tile).floor();
    if (r < 0 || c < 0 || r >= board.rows || c >= board.cols) return -1;
    final i = board.index(r, c);
    return board.playable[i] ? i : -1;
  }

  void _select(int cell) {
    if (_selected >= 0) _cells[_selected]?.selected = false;
    _selected = cell;
    if (cell >= 0) {
      _cells[cell]?.selected = true;
      Services.haptics.light();
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    resetIdle();
    _dragCell = session.canAct ? _cellAt(event.localPosition) : -1;
    _drag.setZero();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragCell < 0) return;
    _drag.add(event.localDelta);
    if (_drag.length < tile * 0.3) return;
    final horizontal = _drag.x.abs() > _drag.y.abs();
    final dr = horizontal ? 0 : _drag.y.sign.toInt();
    final dc = horizontal ? _drag.x.sign.toInt() : 0;
    final from = _dragCell;
    _dragCell = -1;
    final to = board.neighbor(from, dr, dc);
    if (to >= 0 && board.playable[to]) {
      _select(-1);
      session.requestSwap(from, to);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragCell = -1;
  }

  @override
  void onTapUp(TapUpEvent event) {
    resetIdle();
    if (!session.canAct) return;
    final cell = _cellAt(event.localPosition);
    if (cell < 0) {
      _select(-1);
      return;
    }
    if (session.boosterMode == BoosterMode.rollingPin) {
      session.useRollingPin(cell);
      return;
    }
    if (_selected < 0 || _selected == cell) {
      _select(_selected == cell ? -1 : cell);
    } else if (board.areAdjacent(_selected, cell)) {
      final from = _selected;
      _select(-1);
      session.requestSwap(from, cell);
    } else {
      _select(cell);
    }
  }

  // ---------------------------------------------------------------------------
  // Playing engine events
  // ---------------------------------------------------------------------------

  @override
  Future<void> play(List<BoardEvent> events) async {
    resetIdle();
    _select(-1);
    for (final e in events) {
      switch (e) {
        case SwapEvent():
          await _playSwap(e);
        case ClearEvent():
          await _playClear(e);
        case FallEvent():
          await _playFall(e);
        case ConvertEvent():
          await _playConvert(e);
        case NutsCollectedEvent():
          await _playNuts(e);
        case ShuffleEvent():
          await _playShuffle(e);
        case BoosterEvent():
          await _playBooster(e);
      }
    }
    _syncAll();
    _idle = 0;
  }

  Future<void> _playSwap(SwapEvent e) async {
    final sa = _cells[e.a];
    final sb = _cells[e.b];
    if (sa == null || sb == null) return;
    final pa = cellCenter(e.a);
    final pb = cellCenter(e.b);
    sa.priority = 3;
    sb.priority = 2;
    Services.audio.play(Sfx.swap);
    await Future.wait([sa.moveTo(pb, 0.15), sb.moveTo(pa, 0.15)]);
    if (e.reverted) {
      Services.audio.play(Sfx.swapBack);
      Services.haptics.light();
      await Future.wait([sa.moveTo(pa, 0.15), sb.moveTo(pb, 0.15)]);
    } else {
      _cells[e.a] = sb;
      _cells[e.b] = sa;
    }
    sa.priority = 1;
    sb.priority = 1;
  }

  static const _words = ['', '', 'Good!', 'Great!', 'Yum-tastic!', 'Toffee-licious!', 'Twistacular!'];

  Color _colorOf(Piece p) =>
      p.color >= 0 ? SweetArt.baseColors[p.color] : const Color(0xFFFFC928);

  Future<void> _playClear(ClearEvent e) async {
    final boardCenter = (size / 2).toOffset();
    if (e.cascade >= 2) {
      fx.banner(boardCenter, _words[math.min(e.cascade, _words.length - 1)]);
    }
    Services.audio.pop(e.cascade);

    // Effects of specials going off.
    final delays = <int, double>{};
    var big = false;
    for (final a in e.activations) {
      final origin = cellOffset(a.origin);
      final color = a.color >= 0 ? SweetArt.baseColors[a.color] : AppColors.gold;
      switch (a.kind) {
        case EffectKind.lineH:
          fx.beam(Rect.fromLTWH(0, cellRect(a.origin).top, size.x, tile), AppColors.goldLight,
              horizontal: true);
          Services.audio.play(Sfx.striped);
        case EffectKind.lineV:
          fx.beam(Rect.fromLTWH(cellRect(a.origin).left, 0, tile, size.y), AppColors.goldLight,
              horizontal: false);
          Services.audio.play(Sfx.striped);
        case EffectKind.blast:
          fx.ring(origin, tile * (a.radius + 0.9), const Color(0xFFFF9A1F));
          shake(a.radius >= 2 ? 0.45 : 0.22);
          Services.audio.play(Sfx.box);
          Services.haptics.medium();
          big = big || a.radius >= 2;
        case EffectKind.swirl:
          fx.rays(origin, [for (final t in a.targets) cellOffset(t)], color);
          Services.audio.play(Sfx.swirl);
          Services.haptics.medium();
        case EffectKind.cross:
          fx.beam(Rect.fromLTWH(0, cellRect(a.origin).top, size.x, tile), AppColors.goldLight,
              horizontal: true);
          fx.beam(Rect.fromLTWH(cellRect(a.origin).left, 0, tile, size.y), AppColors.goldLight,
              horizontal: false);
          shake(0.3);
          Services.audio.play(Sfx.combo);
          Services.haptics.medium();
        case EffectKind.bigCross:
          final r = cellRect(a.origin);
          fx.beam(Rect.fromLTWH(0, r.top - tile, size.x, tile * 3), AppColors.goldLight, horizontal: true);
          fx.beam(Rect.fromLTWH(r.left - tile, 0, tile * 3, size.y), AppColors.goldLight, horizontal: false);
          big = true;
          Services.audio.play(Sfx.combo);
        case EffectKind.boardClear:
          fx.flash(Vector2.zero() & size);
          fx.ring(origin, size.length / 2, AppColors.gold, duration: 0.7);
          big = true;
          Services.audio.play(Sfx.combo);
      }
      for (final t in a.targets) {
        final d = (cellOffset(t) - origin).distance / tile * 0.035;
        if (d < (delays[t] ?? double.infinity)) delays[t] = d;
      }
    }
    if (big) {
      shake(0.6);
      Services.haptics.heavy();
      fx.banner(boardCenter, 'Twistacular!', size: 46);
    }
    for (final cell in e.matched) {
      delays[cell] = 0;
      fx.glow(cellRect(cell), const Color(0xFFFFFFFF));
    }

    // Pop the cleared pieces.
    final pops = <Future<void>>[];
    var maxDelay = 0.0;
    for (final cp in e.cleared) {
      var s = _cells[cp.cell];
      if (s == null || s.piece.id != cp.piece.id) s = _byId[cp.piece.id];
      if (s == null) continue;
      final sprite = s;
      _discard(sprite);
      final d = delays[cp.cell] ?? 0;
      maxDelay = math.max(maxDelay, d);
      final at = cellCenter(cp.cell);
      final color = _colorOf(cp.piece);
      after(d, () {
        particles.burst(at, color, count: 9, size: tile * 0.09);
        particles.burst(at, const Color(0xFFFFFFFF), count: 3, size: tile * 0.07, shape: ParticleLayer.sparkle);
      });
      pops.add(sprite.pop(delay: d).then((_) => sprite.removeFromParent()));
    }
    for (final cp in e.armed) {
      final s = _byId[cp.piece.id] ?? _cells[cp.cell];
      if (s != null) _setPiece(s, cp.piece);
    }
    for (final cv in e.caramel) {
      after(delays[cv.cell] ?? 0, () {
        _caramel[cv.cell] = cv.value;
        _bgDirty = true;
        particles.burst(cellCenter(cv.cell), const Color(0xFFE89A3C),
            count: 8, size: tile * 0.08, shape: ParticleLayer.crumb);
      });
    }
    if (e.caramel.isNotEmpty) Services.audio.play(Sfx.caramel, volume: 0.5);
    for (final cv in e.crates) {
      after(delays[cv.cell] ?? 0, () {
        _crates[cv.cell] = cv.value;
        _bgDirty = true;
        particles.burst(cellCenter(cv.cell), const Color(0xFFB07038),
            count: cv.value == 0 ? 16 : 8, size: tile * 0.1, shape: ParticleLayer.crumb, speed: 220);
      });
    }
    if (e.crates.isNotEmpty) {
      Services.audio.play(Sfx.crate);
      shake(0.15);
    }
    for (final p in e.popups) {
      if (p.points > 0) fx.scoreText(cellOffset(p.cell), '+${p.points}', size: math.max(16, tile * 0.38));
    }
    session.updateStatus(e.status);
    await Future.wait(pops);

    // New special pieces.
    if (e.created.isNotEmpty) {
      Services.audio.play(Sfx.special);
      final appear = <Future<void>>[];
      for (final cp in e.created) {
        final s = _create(cp.piece, cellCenter(cp.cell));
        _cells[cp.cell] = s;
        appear.add(s.appear());
        particles.burst(cellCenter(cp.cell), AppColors.goldLight, count: 10, shape: ParticleLayer.sparkle,
            size: tile * 0.08, speed: 120);
      }
      await Future.wait(appear);
    }
  }

  Future<void> _playFall(FallEvent e) async {
    var minTick = 1 << 30;
    for (final p in e.paths) {
      minTick = math.min(minTick, p.spawned ? p.ticks.first - 1 : p.ticks.first);
    }
    final moving = <PieceSprite, int>{};
    final starts = <PieceSprite, FallPath>{};
    for (final path in e.paths) {
      PieceSprite? s;
      if (path.spawned) {
        s = _create(path.piece, cellCenter(path.cells.first) - Vector2(0, tile));
        s.opacity = 0;
      } else {
        s = _byId[path.piece.id];
        if (s == null) continue;
        if (identical(_cells[path.cells.first], s)) _cells[path.cells.first] = null;
      }
      moving[s] = path.cells.last;
      starts[s] = path;
    }
    for (final entry in moving.entries) {
      _cells[entry.value] = entry.key;
    }
    final futures = <Future<void>>[];
    for (final entry in starts.entries) {
      final s = entry.key;
      final path = entry.value;
      final points = <Vector2>[];
      final times = <double>[];
      if (path.spawned) {
        points.add(cellCenter(path.cells.first) - Vector2(0, tile));
        times.add((path.ticks.first - 1 - minTick) * tickTime);
      }
      for (var k = 0; k < path.cells.length; k++) {
        points.add(cellCenter(path.cells[k]));
        times.add((path.ticks[k] - minTick) * tickTime);
      }
      var fadeSegment = path.spawned ? 0 : -1;
      if (times.first > 0) {
        points.insert(0, points.first.clone());
        times.insert(0, 0);
        if (path.spawned) fadeSegment = 1;
      }
      if (points.length < 2) {
        points.add(points.first.clone());
        times.add(times.first + tickTime);
      }
      futures.add(s.followPath(points, times, fadeSegment: fadeSegment).then((_) => s.land()));
    }
    // Wait for the movement (the small landing squash runs on its own).
    final total = (e.totalTicks + 1) * tickTime;
    await Future.any([Future.wait(futures), wait(total + 0.2)]);
    await wait(0.02);
  }

  Future<void> _playConvert(ConvertEvent e) async {
    final from = e.origin >= 0 ? cellOffset(e.origin) : null;
    if (from != null) {
      fx.rays(from, [for (final c in e.changes) cellOffset(c.cell)], AppColors.goldLight);
    }
    Services.audio.play(Sfx.special);
    for (final cp in e.changes) {
      final s = _cells[cp.cell] ?? _byId[cp.piece.id];
      if (s == null) continue;
      _setPiece(s, cp.piece);
      particles.burst(cellCenter(cp.cell), AppColors.goldLight, count: 6, shape: ParticleLayer.sparkle,
          size: tile * 0.07, speed: 90);
      s.appear();
    }
    await wait(0.35);
  }

  Future<void> _playNuts(NutsCollectedEvent e) async {
    Services.audio.play(Sfx.nut);
    Services.haptics.medium();
    final futures = <Future<void>>[];
    for (final cp in e.nuts) {
      final s = _cells[cp.cell] ?? _byId[cp.piece.id];
      if (s == null) continue;
      _discard(s);
      final at = cellCenter(cp.cell);
      particles.burst(at, AppColors.gold, count: 16, shape: ParticleLayer.sparkle, size: tile * 0.1);
      fx.scoreText(at.toOffset(), '+400');
      futures.add(Future.wait([
        s.moveTo(at + Vector2(0, tile * 0.7), 0.35, curve: Curves.easeIn),
        s.tween(0.35, (k) => s.opacity = 1 - k),
      ]).then((_) => s.removeFromParent()));
    }
    session.updateStatus(e.status);
    await Future.wait(futures);
  }

  Future<void> _playShuffle(ShuffleEvent e) async {
    fx.banner((size / 2).toOffset(), 'Shuffle!');
    Services.audio.play(Sfx.shuffle);
    await wait(0.35);
    final moves = <Future<void>>[];
    final targets = <PieceSprite, int>{};
    for (final cp in e.after) {
      final s = _byId[cp.piece.id];
      if (s == null) continue;
      if (!identical(s.piece, cp.piece)) _setPiece(s, cp.piece);
      targets[s] = cp.cell;
    }
    for (final s in targets.keys) {
      for (var i = 0; i < _cells.length; i++) {
        if (identical(_cells[i], s)) _cells[i] = null;
      }
    }
    for (final entry in targets.entries) {
      _cells[entry.value] = entry.key;
      moves.add(entry.key.moveTo(cellCenter(entry.value), 0.5, curve: Curves.easeInOutCubic));
    }
    await Future.wait(moves);
  }

  Future<void> _playBooster(BoosterEvent e) async {
    Services.audio.play(Sfx.booster);
    final at = cellOffset(e.cell);
    fx.ring(at, tile * 1.2, AppColors.goldLight);
    particles.burst(cellCenter(e.cell), AppColors.goldLight, count: 14, shape: ParticleLayer.sparkle,
        size: tile * 0.1);
    if (e.booster == 'rollingPin') {
      shake(0.3);
      Services.haptics.heavy();
    }
    await wait(0.12);
  }

  /// Sweet Finale: every unused move becomes bonus points with fireworks.
  @override
  Future<void> playFinale(int moves) async {
    fx.banner((size / 2).toOffset(), 'Sweet Finale!', size: 42);
    Services.audio.play(Sfx.win);
    await wait(0.7);
    final step = moves > 15 ? 0.06 : 0.13;
    for (var i = 0; i < moves; i++) {
      final cells = [
        for (var k = 0; k < board.length; k++)
          if (board.pieces[k] != null) k,
      ];
      if (cells.isNotEmpty) {
        final cell = cells[_rand.nextInt(cells.length)];
        final at = cellCenter(cell);
        final color = SweetArt.baseColors[_rand.nextInt(6)];
        particles.burst(at, color, count: 14, size: tile * 0.1, speed: 230);
        particles.burst(at, AppColors.goldLight, count: 6, shape: ParticleLayer.sparkle, size: tile * 0.1);
        fx.ring(at.toOffset(), tile * 0.9, AppColors.goldLight, duration: 0.3);
        fx.scoreText(at.toOffset(), '+${GameSession.finalePoints}', size: math.max(16, tile * 0.36));
      }
      if (i.isEven) Services.audio.play(Sfx.coin, volume: 0.5);
      session.finaleTick(GameSession.finalePoints);
      await wait(step);
    }
    await wait(0.5);
  }
}
