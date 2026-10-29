import 'dart:ui';

import 'package:flame/game.dart';

import '../game_session.dart';
import 'board_component.dart';

/// The Flame game: only the board lives here. The HUD (moves, goals, score,
/// boosters) is normal Flutter UI around it.
class TwistGame extends FlameGame {
  TwistGame({required this.session, required this.pixelRatio});

  final GameSession session;
  final double pixelRatio;
  late final BoardComponent board;
  bool _ready = false;
  final Vector2 _lastSize = Vector2.zero();

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    board = BoardComponent(session, pixelRatio: pixelRatio);
    await add(board);
    board.layout(size);
    _lastSize.setFrom(size);
    _ready = true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_ready && size != _lastSize) {
      _lastSize.setFrom(size);
      board.layout(size);
    }
  }
}
