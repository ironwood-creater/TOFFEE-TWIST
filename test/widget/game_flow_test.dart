import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toffeetwist/game/game_session.dart';
import 'package:toffeetwist/game/logic/level.dart';
import 'package:toffeetwist/game/logic/match_finder.dart';
import 'package:toffeetwist/screens/game_screen.dart';
import 'package:toffeetwist/services/services.dart';

Future<void> pumpFor(WidgetTester tester, double seconds) async {
  for (var t = 0.0; t < seconds; t += 0.05) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

LevelDef simpleLevel({required List<GoalDef> goals, int moves = 20, int id = 1}) => LevelDef(
      id: id,
      moves: moves,
      colors: const [0, 1, 2, 3, 4],
      board: List.filled(8, '........'),
      goals: goals,
      stars: const [100, 2000, 4000],
    );

/// Opens the game screen on a "launcher" page and returns the exit result future.
Future<Future<GameExit?>> openGame(WidgetTester tester, LevelDef level) async {
  tester.view.physicalSize = const Size(412 * 2, 892 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.runAsync(() => Services.init());
  late Future<GameExit?> result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => result = Navigator.of(context).push<GameExit>(
              MaterialPageRoute(builder: (_) => GameScreen(level: level, seed: 99)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await pumpFor(tester, 1.5);
  return Future.value(result);
}

Future<void> playOneMove(WidgetTester tester) async {
  final session = GameScreen.debugLastSession!;
  final game = GameScreen.debugLastGame!;
  final m = findPossibleMoves(session.engine.board).first;
  final topLeft = tester.getTopLeft(
      find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('GameWidget')));
  Offset pos(int cell) {
    final c = game.board.position + game.board.cellCenter(cell);
    return topLeft + Offset(c.x, c.y);
  }

  await tester.dragFrom(pos(m.a), pos(m.b) - pos(m.a));
  await pumpFor(tester, 4);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('winning shows stars and coins, records progress', (tester) async {
    final result = await openGame(tester, simpleLevel(goals: const [GoalDef.score(50)]));
    final coinsBefore = Services.progress.coins;
    await playOneMove(tester);
    await pumpFor(tester, 6);
    expect(GameScreen.debugLastSession!.phase, SessionPhase.won);
    expect(find.text('Sweet Success!'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await pumpFor(tester, 1);
    expect(await result, GameExit.next);
    expect(Services.progress.currentLevel, 2);
    expect(Services.progress.starsFor(1), greaterThanOrEqualTo(1));
    expect(Services.progress.coins, greaterThan(coinsBefore));
  });

  testWidgets('running out of moves offers +5 moves, giving up costs a life', (tester) async {
    final result = await openGame(tester, simpleLevel(goals: const [GoalDef.collect(0, 500)], moves: 1));
    await playOneMove(tester);
    await pumpFor(tester, 2);
    expect(find.text('Out of moves!'), findsOneWidget);
    // Buy +5 moves with coins: the game continues.
    await tester.tap(find.text('+5 Moves').first);
    await pumpFor(tester, 1);
    final session = GameScreen.debugLastSession!;
    expect(session.phase, SessionPhase.playing);
    expect(session.engine.movesLeft, 5);
    // Use them up, then give up.
    for (var i = 0; i < 5; i++) {
      await playOneMove(tester);
    }
    await pumpFor(tester, 2);
    expect(find.text('Out of moves!'), findsOneWidget);
    await tester.tap(find.text('Give up (lose a life)'));
    await pumpFor(tester, 1);
    expect(find.text('Level failed'), findsOneWidget);
    expect(Services.progress.lives, 4);
    await tester.tap(find.text('Map'));
    await pumpFor(tester, 1);
    expect(await result, GameExit.map);
  });

  testWidgets('rolling pin booster smashes a piece without using a move', (tester) async {
    await openGame(tester, simpleLevel(goals: const [GoalDef.collect(0, 500)]));
    final session = GameScreen.debugLastSession!;
    final game = GameScreen.debugLastGame!;
    final pins = Services.progress.boosterCount(Booster.rollingPin);
    await tester.tap(find.bySemanticsLabel(RegExp('Rolling Pin')));
    await pumpFor(tester, 0.3);
    expect(session.boosterMode, BoosterMode.rollingPin);
    final topLeft = tester.getTopLeft(
        find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('GameWidget')));
    final c = game.board.position + game.board.cellCenter(27);
    await tester.tapAt(topLeft + Offset(c.x, c.y));
    await pumpFor(tester, 3);
    expect(session.engine.movesLeft, 20);
    expect(session.score, greaterThan(0));
    expect(Services.progress.boosterCount(Booster.rollingPin), pins - 1);
    expect(session.boosterMode, BoosterMode.none);
  });
}
