import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toffeetwist/screens/dialogs/meta_dialogs.dart';
import 'package:toffeetwist/screens/game_screen.dart';
import 'package:toffeetwist/screens/home_screen.dart';
import 'package:toffeetwist/screens/map_screen.dart';
import 'package:toffeetwist/services/services.dart';

Future<void> pumpFor(WidgetTester tester, double seconds) async {
  for (var t = 0.0; t < seconds; t += 0.05) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Claims and closes the daily reward popup if it is showing.
Future<void> dismissDaily(WidgetTester tester) async {
  if (find.text('Claim').evaluate().isEmpty) return;
  await tester.tap(find.text('Claim'));
  await pumpFor(tester, 0.5);
  await tester.tap(find.text('Yummy!'));
  await pumpFor(tester, 0.5);
}

Future<void> startApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360 * 2, 640 * 2); // small phone
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.runAsync(() => Services.init());
  await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
  await pumpFor(tester, 1);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home -> daily reward -> play -> map -> level start -> game', (tester) async {
    await startApp(tester);
    // The daily reward pops up on the first launch.
    expect(find.text('Daily Reward'), findsOneWidget);
    await tester.tap(find.text('Claim'));
    await pumpFor(tester, 0.5);
    expect(Services.progress.coins, 350);
    await tester.tap(find.text('Yummy!'));
    await pumpFor(tester, 0.5);

    expect(find.text('Level 1'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await pumpFor(tester, 2);
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(PreLevelDialog), findsOneWidget);
    expect(find.text('Score 8000 points'), findsOneWidget);

    // Pick the +3 moves booster and start.
    await tester.tap(find.text('+3 Moves'));
    await pumpFor(tester, 0.3);
    await tester.tap(find.text('Play').last);
    await pumpFor(tester, 2);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(Services.progress.boosterCount(Booster.extraMoves), 0);
    final session = GameScreen.debugLastSession!;
    expect(session.engine.movesLeft, session.level.moves + 3);
    // Level 1 has a tutorial popup.
    expect(find.text("Let's go!"), findsOneWidget);
  });

  testWidgets('with no lives the out-of-lives popup shows instead of the level', (tester) async {
    await startApp(tester);
    await dismissDaily(tester);
    for (var i = 0; i < 5; i++) {
      Services.progress.loseLife();
    }
    await tester.tap(find.text('Play'));
    await pumpFor(tester, 2);
    expect(find.byType(OutOfLivesDialog), findsOneWidget);
    expect(find.textContaining('Next life in'), findsOneWidget);
  });

  testWidgets('spin wheel gives a prize once per day', (tester) async {
    await startApp(tester);
    await dismissDaily(tester);
    final coins = Services.progress.coins;
    final boosters = Booster.values.fold(0, (a, b) => a + Services.progress.boosterCount(b));
    await tester.tap(find.text('Spin'));
    await pumpFor(tester, 0.6);
    await tester.tap(find.text('Spin!'));
    await pumpFor(tester, 5);
    expect(find.textContaining('You won'), findsOneWidget);
    final boostersAfter = Booster.values.fold(0, (a, b) => a + Services.progress.boosterCount(b));
    expect(Services.progress.coins > coins || boostersAfter > boosters, isTrue);
    expect(find.text('Spin!'), findsNothing, reason: 'no second free spin today');
    expect(Services.progress.canFreeSpin, isFalse);
  });
}
