import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toffeetwist/game/logic/level.dart';
import 'package:toffeetwist/game/logic/match_finder.dart';
import 'package:toffeetwist/screens/game_screen.dart';
import 'package:toffeetwist/services/services.dart';

Future<void> pumpFor(WidgetTester tester, double seconds) async {
  for (var t = 0.0; t < seconds; t += 0.05) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a level can be played with swipes', (tester) async {
    tester.view.physicalSize = const Size(412 * 2, 892 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => Services.init());
    final level = LevelDef.parse(File('tool/levels/sandbox.json').readAsStringSync());
    await tester.pumpWidget(MaterialApp(home: GameScreen(level: level, seed: 12345)));
    await pumpFor(tester, 1);
    final session = GameScreen.debugLastSession!;
    final game = GameScreen.debugLastGame!;
    expect(session.canAct, isTrue, reason: 'game ready');

    final origin = tester.getTopLeft(find.byType(GameScreen)) ;
    Offset cellPos(int cell) {
      final board = game.board;
      final widgetTopLeft = tester.getTopLeft(find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('GameWidget')));
      final c = board.position + board.cellCenter(cell);
      return widgetTopLeft + Offset(c.x, c.y);
    }

    for (var move = 0; move < 6; move++) {
      final moves = findPossibleMoves(session.engine.board);
      expect(moves, isNotEmpty);
      final m = moves.first;
      final before = session.engine.movesLeft;
      final from = cellPos(m.a);
      final to = cellPos(m.b);
      await tester.dragFrom(from, to - from);
      await pumpFor(tester, 4);
      expect(session.busy, isFalse, reason: 'move $move stuck in ${game.board.debugStage}');
      expect(session.engine.movesLeft, before - 1, reason: 'move $move used a move');
      expect(session.moves, session.engine.movesLeft);
    }
    expect(origin, isNotNull);
  });
}
