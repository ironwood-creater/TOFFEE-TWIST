import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/logic/level.dart';
import 'screens/game_screen.dart';
import 'services/services.dart';
import 'theme.dart';

class ToffeeTwistApp extends StatelessWidget {
  const ToffeeTwistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toffee Twist',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _DevLauncher(),
    );
  }
}

/// Temporary start screen used while building the game: opens the sandbox
/// level (or `?level=sandbox` on the web).
class _DevLauncher extends StatefulWidget {
  const _DevLauncher();

  @override
  State<_DevLauncher> createState() => _DevLauncherState();
}

class _DevLauncherState extends State<_DevLauncher> {
  LevelDef? _level;
  int? _seed;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final s = Uri.base.queryParameters['seed'];
      if (s != null) _seed = int.tryParse(s);
    }
    final test = kIsWeb ? Uri.base.queryParameters['test'] : null;
    if (test == 'win' || test == 'lose') {
      _level = LevelDef(
        id: 7,
        moves: test == 'win' ? 12 : 1,
        colors: const [0, 1, 2, 3, 4],
        board: List.filled(8, '........'),
        goals: test == 'win' ? const [GoalDef.score(60)] : const [GoalDef.collect(2, 40), GoalDef.collect(4, 30)],
        stars: const [60, 1500, 3000],
      );
      return;
    }
    final id = kIsWeb ? int.tryParse(Uri.base.queryParameters['level'] ?? '') : null;
    if (id != null) {
      Services.levels.load(id).then((l) => setState(() => _level = l));
      return;
    }
    rootBundle.loadString('assets/levels/sandbox.json').then((t) {
      setState(() => _level = LevelDef.parse(t));
    });
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    if (level == null) return const Scaffold(backgroundColor: AppColors.cream);
    return GameScreen(level: level, seed: _seed ?? 12345);
  }
}
