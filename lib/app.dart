import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game/logic/level.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'services/services.dart';
import 'theme.dart';

class ToffeeTwistApp extends StatefulWidget {
  const ToffeeTwistApp({super.key});

  @override
  State<ToffeeTwistApp> createState() => _ToffeeTwistAppState();
}

class _ToffeeTwistAppState extends State<ToffeeTwistApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      Services.audio.pauseForBackground();
    } else if (state == AppLifecycleState.resumed) {
      Services.audio.resumeFromBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    final debugParams = kIsWeb &&
        (Uri.base.queryParameters.containsKey('level') || Uri.base.queryParameters.containsKey('test'));
    return MaterialApp(
      title: 'Toffee Twist',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: debugParams ? const _WebLevelLauncher() : const HomeScreen(),
    );
  }
}

/// Web-only helper used for testing and store screenshots:
/// `?level=12` opens level 12 directly, `?test=win|lose` opens tiny test levels,
/// `&seed=5` fixes the random seed, `&slowmo=0.1` plays animations slowly.
class _WebLevelLauncher extends StatefulWidget {
  const _WebLevelLauncher();

  @override
  State<_WebLevelLauncher> createState() => _WebLevelLauncherState();
}

class _WebLevelLauncherState extends State<_WebLevelLauncher> {
  LevelDef? _level;
  int? _seed;
  double _timeScale = 1;

  @override
  void initState() {
    super.initState();
    final q = Uri.base.queryParameters;
    _seed = int.tryParse(q['seed'] ?? '');
    _timeScale = double.tryParse(q['slowmo'] ?? '') ?? 1;
    final test = q['test'];
    if (test == 'win' || test == 'lose') {
      _level = LevelDef(
        id: 7,
        moves: test == 'win' ? 12 : 1,
        colors: const [0, 1, 2, 3, 4],
        board: List.filled(8, '........'),
        goals: test == 'win' ? const [GoalDef.score(60)] : const [GoalDef.collect(2, 40), GoalDef.collect(4, 30)],
        stars: const [60, 1200, 2400],
      );
      return;
    }
    final id = int.tryParse(q['level'] ?? '') ?? 1;
    Services.levels.load(id).then((l) => setState(() => _level = l));
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    if (level == null) return const Scaffold(backgroundColor: AppColors.cream);
    return GameScreen(level: level, seed: _seed ?? 12345, timeScale: _timeScale);
  }
}
