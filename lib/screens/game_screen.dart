import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/flame/twist_game.dart';
import '../game/game_session.dart';
import '../game/logic/level.dart';
import '../services/progress_service.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/goal_widgets.dart';
import '../widgets/top_bar.dart';
import '../widgets/ui.dart';
import 'dialogs/game_dialogs.dart';
import 'dialogs/tutorial_dialog.dart';

/// How the player left the game screen.
enum GameExit { next, retry, map }

/// Hooks for rewarded ads (filled in by the ads service; null = no ads).
class GameAdHooks {
  const GameAdHooks({this.extraMoves, this.tripleCoins});
  final Future<bool> Function()? extraMoves;
  final Future<bool> Function()? tripleCoins;
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.level,
    this.startBoosters = const {},
    this.ads = const GameAdHooks(),
    this.seed,
  });

  final LevelDef level;
  final Set<Booster> startBoosters;
  final GameAdHooks ads;
  final int? seed;

  /// The most recent session (lets widget tests look inside).
  @visibleForTesting
  static GameSession? debugLastSession;

  /// The most recent Flame game (for widget tests).
  @visibleForTesting
  static TwistGame? debugLastGame;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameSession session;
  late TwistGame game;
  bool _ended = false;

  ProgressService get progress => Services.progress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final ratio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    session = GameSession(
      level: widget.level,
      seed: widget.seed,
      extraMoves: widget.startBoosters.contains(Booster.extraMoves) ? 3 : 0,
      startBox: widget.startBoosters.contains(Booster.startBox),
      consumeBooster: progress.useBooster,
    )..onFinished = _onFinished;
    game = TwistGame(session: session, pixelRatio: ratio);
    GameScreen.debugLastSession = session;
    GameScreen.debugLastGame = game;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      game.pauseEngine();
    } else if (state == AppLifecycleState.resumed) {
      game.resumeEngine();
    }
  }

  Future<void> _start() async {
    await game.loaded;
    await game.board.loaded;
    final tut = widget.level.tutorial;
    if (tut != null && mounted && !progress.tutorialSeen('level_${widget.level.id}')) {
      await showPopup<void>(context, TutorialDialog(tutorial: tut));
      progress.markTutorial('level_${widget.level.id}');
    }
    await session.begin();
  }

  // ---------------------------------------------------------------------------
  // End of level
  // ---------------------------------------------------------------------------

  Future<void> _onFinished(SessionPhase phase) async {
    if (!mounted || _ended) return;
    if (phase == SessionPhase.won) {
      _ended = true;
      final stars = session.stars;
      final coins = progress.recordWin(widget.level.id, stars, session.engine.score);
      final triple = widget.ads.tripleCoins;
      final tripled = await showPopup<bool>(
        context,
        WinDialog(
          levelId: widget.level.id,
          stars: stars,
          score: session.engine.score,
          coins: coins,
          onTripleCoins: triple,
        ),
      );
      if (tripled == true) progress.addCoins(coins * 2);
      if (mounted) Navigator.of(context).pop(GameExit.next);
    } else if (phase == SessionPhase.lost) {
      await _outOfMoves();
    }
  }

  Future<void> _outOfMoves() async {
    const price = ProgressService.continueMovesPrice;
    final choice = await showPopup<LoseChoice>(
      context,
      OutOfMovesDialog(
        level: widget.level,
        goals: session.engine.goals,
        price: price,
        canAfford: progress.coins >= price,
        adAvailable: widget.ads.extraMoves != null,
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case LoseChoice.buyMoves:
        if (progress.spendCoins(price)) {
          Services.audio.play(Sfx.coin);
          session.continueWithMoves(5);
          return;
        }
      case LoseChoice.adMoves:
        final ok = await widget.ads.extraMoves!();
        if (ok) {
          session.continueWithMoves(5);
          return;
        }
        if (mounted) await _outOfMoves();
        return;
      case LoseChoice.giveUp || null:
        break;
    }
    if (!mounted) return;
    _ended = true;
    Services.audio.play(Sfx.lose);
    progress.recordLoss();
    final retry = await showPopup<bool>(
      context,
      LevelFailedDialog(levelId: widget.level.id, livesLeft: progress.lives),
    );
    if (mounted) Navigator.of(context).pop(retry == true ? GameExit.retry : GameExit.map);
  }

  Future<void> _pause() async {
    if (_ended) return;
    game.pauseEngine();
    final movesMade = session.engine.movesUsed > 0;
    final choice = await showPopup<PauseChoice>(
      context,
      PauseDialog(level: widget.level, movesMade: movesMade),
      dismissible: true,
    );
    game.resumeEngine();
    if (!mounted || choice == null || choice == PauseChoice.resume) return;
    if (movesMade && !_ended) progress.recordLoss();
    _ended = true;
    if (!mounted) return;
    Navigator.of(context).pop(choice == PauseChoice.restart && progress.lives > 0 ? GameExit.retry : GameExit.map);
  }

  // ---------------------------------------------------------------------------
  // Boosters
  // ---------------------------------------------------------------------------

  Future<void> _boosterTap(Booster b, BoosterMode mode) async {
    if (!session.canAct) return;
    if (session.boosterMode == mode) {
      session.setBoosterMode(BoosterMode.none);
      return;
    }
    if (progress.boosterCount(b) <= 0) {
      final buy = await showPopup<bool>(
        context,
        BuyBoosterDialog(booster: b),
        dismissible: true,
      );
      if (buy != true || !mounted) return;
      if (!progress.buyBooster(b)) return;
      Services.audio.play(Sfx.coin);
    }
    session.setBoosterMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        body: ShopBackground(
          colors: const [Color(0xFFFFE9C4), Color(0xFFF5C988), Color(0xFFE9A94F)],
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([session, progress]),
              builder: (context, _) => Column(
                children: [
                  _TopHud(session: session, onPause: _pause),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      child: GameWidget(game: game),
                    ),
                  ),
                  _BottomBar(
                    session: session,
                    onRollingPin: () => _boosterTap(Booster.rollingPin, BoosterMode.rollingPin),
                    onFreeSwap: () => _boosterTap(Booster.freeSwap, BoosterMode.freeSwap),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud({required this.session, required this.onPause});
  final GameSession session;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final level = session.level;
    final goals = session.engine.goals.goals;
    final lowMoves = session.moves <= 5 && session.phase == SessionPhase.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.chocolate,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.chocolateDark, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                // Moves
                Container(
                  width: 74,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.chocolateDark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text('MOVES', style: AppText.label(11, color: AppColors.goldLight, weight: FontWeight.w800)),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: AppText.title(32, color: lowMoves ? const Color(0xFFFF8A8A) : Colors.white),
                        child: Text('${session.moves}'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Goals
                Expanded(
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.chocolateLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < goals.length; i++)
                          GoalChip(
                            goal: goals[i].def,
                            remaining: math.max(0, goals[i].target -
                                (i < session.goals.length ? session.goals[i] : 0)),
                            size: goals.length > 3 ? 28 : 32,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    RoundIconButton(icon: Icons.pause_rounded, onPressed: onPause, size: 40, tooltip: 'Pause'),
                    const SizedBox(height: 2),
                    Text('Lv ${level.id}', style: AppText.label(12, color: AppColors.goldLight, weight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            _ScoreBar(score: session.score, stars: level.stars),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.score, required this.stars});
  final int score;
  final List<int> stars;

  @override
  Widget build(BuildContext context) {
    final max = stars[2] * 1.08;
    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth - 70;
          return Row(
            children: [
              SizedBox(
                width: w,
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      top: 6,
                      bottom: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.chocolateDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 2,
                      top: 8,
                      bottom: 6,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: (w - 4) * (score / max).clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.gold, AppColors.caramel]),
                        ),
                      ),
                    ),
                    for (final t in stars)
                      Positioned(
                        left: (w - 4) * (t / max) - 10,
                        top: -1,
                        child: Icon(Icons.star_rounded,
                            size: 22,
                            color: score >= t ? AppColors.gold : const Color(0xFF8A6A50),
                            shadows: const [Shadow(color: Color(0xAA000000), offset: Offset(0, 1))]),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: Text('$score', style: AppText.title(20)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.session, required this.onRollingPin, required this.onFreeSwap});
  final GameSession session;
  final VoidCallback onRollingPin;
  final VoidCallback onFreeSwap;

  @override
  Widget build(BuildContext context) {
    final p = Services.progress;
    final mode = session.boosterMode;
    final hint = switch (mode) {
      BoosterMode.rollingPin => 'Tap a piece to smash it!',
      BoosterMode.freeSwap => 'Swap any two neighbours!',
      BoosterMode.none => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          _BoosterButton(
            icon: Icons.horizontal_rule_rounded,
            painter: const RollingPinIcon(),
            label: 'Rolling Pin',
            count: p.boosterCount(Booster.rollingPin),
            active: mode == BoosterMode.rollingPin,
            onTap: onRollingPin,
          ),
          const SizedBox(width: 10),
          _BoosterButton(
            icon: Icons.swap_horiz_rounded,
            label: 'Free Swap',
            count: p.boosterCount(Booster.freeSwap),
            active: mode == BoosterMode.freeSwap,
            onTap: onFreeSwap,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: hint == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(hint),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.chocolate,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(hint, style: AppText.label(14, color: Colors.white)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoosterButton extends StatelessWidget {
  const _BoosterButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.painter,
  });
  final IconData icon;
  final Widget? painter;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $count left',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? const [Color(0xFFFFF2B0), AppColors.gold]
                  : const [AppColors.chocolateLight, AppColors.chocolate],
            ),
            border: Border.all(color: active ? Colors.white : AppColors.chocolateDark, width: 3),
            boxShadow: [
              if (active) const BoxShadow(color: Color(0xAAFFD54F), blurRadius: 14, spreadRadius: 2),
              const BoxShadow(color: Color(0x55000000), offset: Offset(0, 3), blurRadius: 3),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              painter ?? Icon(icon, size: 36, color: Colors.white),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: count > 0 ? AppColors.mint : AppColors.gold,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: count > 0
                      ? Text('$count', style: AppText.title(14))
                      : const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rolling pin drawn in code.
class RollingPinIcon extends StatelessWidget {
  const RollingPinIcon({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: RollingPinPainter()));
}

/// Offer to buy a booster with coins.
class BuyBoosterDialog extends StatelessWidget {
  const BuyBoosterDialog({super.key, required this.booster});
  final Booster booster;

  @override
  Widget build(BuildContext context) {
    final canPay = Services.progress.coins >= booster.price;
    return SizedBox(
      width: 320,
      child: ChocoPanel(
        title: booster.label,
        padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(booster.description, textAlign: TextAlign.center, style: AppText.label(17)),
            const SizedBox(height: 6),
            Text('You have ${Services.progress.coins} coins', style: AppText.label(14, color: AppColors.chocolateLight)),
            const SizedBox(height: 14),
            GoldButton(
              label: 'Buy for ${booster.price}',
              icon: const CoinIcon(size: 26),
              fontSize: 20,
              onPressed: canPay ? () => Navigator.of(context).pop(true) : null,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No thanks', style: AppText.label(15, color: AppColors.chocolateLight)),
            ),
          ],
        ),
      ),
    );
  }
}
