import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/logic/board.dart';
import '../../game/logic/goals.dart';
import '../../game/logic/level.dart';
import '../../levels/shop_names.dart';
import '../../services/progress_service.dart';
import '../../services/services.dart';
import '../../theme.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';
import '../game_screen.dart' show BuyBoosterDialog;
import 'game_dialogs.dart';

// -----------------------------------------------------------------------------
// Before a level: goals + start boosters
// -----------------------------------------------------------------------------

class PreLevelDialog extends StatefulWidget {
  const PreLevelDialog({super.key, required this.level});
  final LevelDef level;

  @override
  State<PreLevelDialog> createState() => _PreLevelDialogState();
}

class _PreLevelDialogState extends State<PreLevelDialog> {
  final Set<Booster> _selected = {};

  Future<void> _toggle(Booster b) async {
    final p = Services.progress;
    if (_selected.contains(b)) {
      setState(() => _selected.remove(b));
      return;
    }
    if (p.boosterCount(b) <= 0) {
      final buy = await showPopup<bool>(
        context,
        BuyBoosterDialog(booster: b),
        dismissible: true,
      );
      if (buy != true || !p.buyBooster(b)) return;
      Services.audio.play(Sfx.coin);
    }
    setState(() => _selected.add(b));
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    final goals = GoalTracker.forLevel(level, Board.fromLevel(level));
    final hard = level.kind == LevelKind.hard;
    final p = Services.progress;
    final best = p.starsFor(level.id);
    return SizedBox(
      width: 340,
      child: ChocoPanel(
        title: 'Level ${level.id}',
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
        child: ListenableBuilder(
          listenable: p,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shopNameForLevel(level.id),
                style: AppText.label(15, color: AppColors.chocolateLight),
              ),
              if (hard)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C2F6B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('HARD LEVEL', style: AppText.title(16)),
                ),
              if (best > 0) ...[
                const SizedBox(height: 6),
                StarRow(filled: best, size: 26),
              ],
              const SizedBox(height: 10),
              Text(
                'Goals',
                style: AppText.title(
                  20,
                  color: AppColors.chocolate,
                  shadows: const [],
                ),
              ),
              const SizedBox(height: 4),
              GoalsList(
                level: level,
                targets: [for (final g in goals.goals) g.target],
              ),
              const SizedBox(height: 12),
              Text(
                'Start boosters',
                style: AppText.title(
                  18,
                  color: AppColors.chocolate,
                  shadows: const [],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final b in const [Booster.startBox, Booster.extraMoves])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _BoosterToggle(
                        booster: b,
                        count: p.boosterCount(b),
                        selected: _selected.contains(b),
                        onTap: () => _toggle(b),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              GoldButton(
                label: 'Play',
                color: GoldButtonColor.green,
                width: 230,
                icon: const HeartIcon(size: 26),
                onPressed: () =>
                    Navigator.of(context).pop(Set<Booster>.of(_selected)),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: AppText.label(15, color: AppColors.chocolateLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoosterToggle extends StatelessWidget {
  const _BoosterToggle({
    required this.booster,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final Booster booster;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${booster.label}, $count left',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 112,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF0B8) : AppColors.tileLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.goldDark : AppColors.creamDark,
              width: 3,
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  BoosterIcon(booster, size: 40),
                  Positioned(
                    right: -14,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.mint
                            : (count > 0
                                  ? AppColors.chocolate
                                  : AppColors.goldDark),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : Text(
                              count > 0 ? '$count' : '+',
                              style: AppText.title(14),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                booster.label,
                textAlign: TextAlign.center,
                style: AppText.label(13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Out of lives
// -----------------------------------------------------------------------------

class OutOfLivesDialog extends StatefulWidget {
  const OutOfLivesDialog({super.key});

  @override
  State<OutOfLivesDialog> createState() => _OutOfLivesDialogState();
}

class _OutOfLivesDialogState extends State<OutOfLivesDialog> {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (Services.progress.hasLife) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Services.progress;
    final next = p.nextLifeIn;
    final ads = Services.ads;
    return SizedBox(
      width: 330,
      child: ChocoPanel(
        title: 'Out of lives',
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HeartIcon(size: 64),
            Text('Next life in', style: AppText.label(16)),
            Text(
              next == null ? 'now' : formatDuration(next),
              style: AppText.title(
                34,
                color: AppColors.chocolate,
                shadows: const [],
              ),
            ),
            Text(
              'Lives come back by themselves - one every 30 minutes, even when the game is closed.',
              textAlign: TextAlign.center,
              style: AppText.label(14, color: AppColors.chocolateLight),
            ),
            const SizedBox(height: 14),
            if (ads.rewardedReady) ...[
              GoldButton(
                label: '+1 Life',
                subtitle: 'Watch a short video',
                color: GoldButtonColor.pink,
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                height: 60,
                fontSize: 22,
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final ok = await ads.showRewarded(
                          RewardedPurpose.freeLife,
                        );
                        if (ok) p.addLives(1);
                        if (!context.mounted) return;
                        setState(() => _busy = false);
                        if (ok) Navigator.of(context).pop(true);
                      },
              ),
              const SizedBox(height: 10),
            ],
            GoldButton(
              label: 'Refill lives',
              subtitle: '${ProgressService.refillLivesPrice} coins',
              icon: const CoinIcon(size: 28),
              height: 60,
              fontSize: 22,
              onPressed: p.coins >= ProgressService.refillLivesPrice
                  ? () {
                      if (p.refillLives()) {
                        Services.audio.play(Sfx.coin);
                        Navigator.of(context).pop(true);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Wait',
                style: AppText.label(15, color: AppColors.chocolateLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Daily reward calendar
// -----------------------------------------------------------------------------

class DailyRewardDialog extends StatefulWidget {
  const DailyRewardDialog({super.key});

  @override
  State<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<DailyRewardDialog> {
  Reward? _claimed;

  @override
  Widget build(BuildContext context) {
    final p = Services.progress;
    final today = p.dailyDay;
    final canClaim = p.canClaimDaily;
    Widget tile(int i) {
      final claimed = i < today || (!canClaim && i == today);
      final isToday = i == today && canClaim;
      final big = i == 6;
      return Container(
        width: big ? 196 : 90,
        height: 92,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFFFFF0B8)
              : (claimed ? const Color(0xFFE6F6EC) : AppColors.tileLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday
                ? AppColors.goldDark
                : (claimed ? AppColors.mint : AppColors.creamDark),
            width: isToday ? 3.5 : 2,
          ),
          boxShadow: isToday
              ? const [BoxShadow(color: Color(0x88FFC928), blurRadius: 10)]
              : null,
        ),
        child: Stack(
          children: [
            SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Day ${i + 1}',
                    style: AppText.label(13, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  RewardIcons(ProgressService.dailyRewards[i], size: 30),
                ],
              ),
            ),
            if (claimed)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.mint,
                  size: 22,
                ),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 340,
      child: ChocoPanel(
        title: 'Daily Reward',
        padding: const EdgeInsets.fromLTRB(10, 30, 10, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Come back every day for bigger treats!',
              style: AppText.label(14),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              children: [for (var i = 0; i < 7; i++) tile(i)],
            ),
            const SizedBox(height: 12),
            if (_claimed != null) ...[
              Text(
                'You got ${_claimed!.label}!',
                textAlign: TextAlign.center,
                style: AppText.title(
                  20,
                  color: AppColors.caramelDark,
                  shadows: const [],
                ),
              ),
              const SizedBox(height: 10),
              GoldButton(
                label: 'Yummy!',
                width: 200,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ] else if (canClaim)
              GoldButton(
                label: 'Claim',
                color: GoldButtonColor.green,
                width: 200,
                onPressed: () {
                  final r = p.claimDaily();
                  Services.audio.play(Sfx.coin);
                  setState(() => _claimed = r);
                },
              )
            else ...[
              Text(
                'Come back tomorrow for Day ${(today + 1) % 7 + 1}!',
                style: AppText.label(15),
              ),
              const SizedBox(height: 10),
              GoldButton(
                label: 'OK',
                width: 160,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Spin wheel (free once a day; one extra spin per day for a video; never sold)
// -----------------------------------------------------------------------------

class SpinWheelDialog extends StatefulWidget {
  const SpinWheelDialog({super.key, this.random});
  final math.Random? random;

  @override
  State<SpinWheelDialog> createState() => _SpinWheelDialogState();
}

class _SpinWheelDialogState extends State<SpinWheelDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  late final math.Random _random = widget.random ?? math.Random();
  double _from = 0;
  double _to = 0;
  int _lastTick = 0;
  Reward? _won;
  bool _spinning = false;

  static const _segColors = [
    Color(0xFFFFE08A),
    Color(0xFFFFC2DC),
    Color(0xFFA9D6FF),
    Color(0xFFB8F5D6),
    Color(0xFFE4C2FF),
    Color(0xFFF7C99A),
    Color(0xFFFFE08A),
    Color(0xFFFFC2DC),
  ];

  @override
  void initState() {
    super.initState();
    _spin.addListener(() {
      final angle = _angle;
      final n = ProgressService.spinRewards.length;
      final tick = (angle / (2 * math.pi / n)).floor();
      if (tick != _lastTick) {
        _lastTick = tick;
        Services.audio.play(Sfx.spin, volume: 0.4);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  double get _angle =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_spin.value);

  Future<void> _go({required bool ad}) async {
    final p = Services.progress;
    if (ad) {
      final ok = await Services.ads.showRewarded(RewardedPurpose.extraSpin);
      if (!ok || !mounted) return;
      p.markAdSpin();
    } else {
      p.markFreeSpin();
    }
    final n = ProgressService.spinRewards.length;
    final index = ProgressService.pickSpin(_random.nextDouble());
    final seg = 2 * math.pi / n;
    // Segment i is centred at angle i*seg (clockwise from the top pointer).
    final current = _angle % (2 * math.pi);
    final target = (2 * math.pi - index * seg) % (2 * math.pi);
    var delta = target - current;
    if (delta < 0) delta += 2 * math.pi;
    final jitter = (_random.nextDouble() - 0.5) * seg * 0.6;
    setState(() {
      _spinning = true;
      _won = null;
      _from = _angle;
      _to = _from + 5 * 2 * math.pi + delta + jitter;
    });
    await _spin.forward(from: 0);
    final reward = ProgressService.spinRewards[index].$1;
    p.grant(reward);
    Services.audio.play(Sfx.win);
    if (mounted) {
      setState(() {
        _spinning = false;
        _won = reward;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Services.progress;
    final rewards = ProgressService.spinRewards;
    final n = rewards.length;
    const size = 280.0;
    return SizedBox(
      width: 340,
      child: ChocoPanel(
        title: 'Daily Spin',
        padding: const EdgeInsets.fromLTRB(12, 30, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size + 14,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 14,
                    child: Transform.rotate(
                      angle: _angle,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: const Size(size, size),
                              painter: _WheelPainter(_segColors, n),
                            ),
                            for (var i = 0; i < n; i++)
                              Positioned.fill(
                                child: Transform.rotate(
                                  angle: i * 2 * math.pi / n,
                                  child: Align(
                                    alignment: const Alignment(0, -0.62),
                                    child: RewardIcons(rewards[i].$1, size: 30),
                                  ),
                                ),
                              ),
                            Center(
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    colors: [
                                      AppColors.goldLight,
                                      AppColors.goldDark,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: AppColors.chocolateDark,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: CustomPaint(size: const Size(34, 40), painter: _PointerPainter()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_won != null)
              Text(
                'You won ${_won!.label}!',
                textAlign: TextAlign.center,
                style: AppText.title(
                  20,
                  color: AppColors.caramelDark,
                  shadows: const [],
                ),
              ),
            const SizedBox(height: 8),
            if (!_spinning && p.canFreeSpin)
              GoldButton(
                label: 'Spin!',
                color: GoldButtonColor.green,
                width: 210,
                onPressed: () => _go(ad: false),
              )
            else if (!_spinning && p.canAdSpin && Services.ads.rewardedReady)
              GoldButton(
                label: 'Spin again',
                subtitle: 'Watch a short video',
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                color: GoldButtonColor.pink,
                width: 240,
                height: 60,
                onPressed: () => _go(ad: true),
              )
            else if (!_spinning)
              Text('Next free spin tomorrow!', style: AppText.label(15)),
            const SizedBox(height: 4),
            Text(
              'Prizes are coins and boosters. Spins are free and can\'t be bought.',
              textAlign: TextAlign.center,
              style: AppText.label(12, color: AppColors.chocolateLight),
            ),
            TextButton(
              onPressed: _spinning ? null : () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: AppText.label(15, color: AppColors.chocolateLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.colors, this.n);
  final List<Color> colors;
  final int n;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r - 8);
    final seg = 2 * math.pi / n;
    canvas.drawCircle(c, r, Paint()..color = AppColors.chocolate);
    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * seg - seg / 2;
      canvas.drawArc(
        rect,
        start,
        seg,
        true,
        Paint()..color = colors[i % colors.length],
      );
      canvas.drawArc(
        rect,
        start,
        seg,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x55603010),
      );
    }
    final bulb = Paint()..color = AppColors.goldLight;
    for (var i = 0; i < n * 2; i++) {
      final a = i * math.pi / n;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * (r - 4),
        3.2,
        bulb,
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = const Color(0x55000000));
    canvas.drawPath(path, Paint()..color = AppColors.red);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => false;
}
