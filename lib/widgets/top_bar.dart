import 'dart:async';

import 'package:flutter/material.dart';

import '../services/services.dart';
import '../theme.dart';
import 'ui.dart';

/// Lives with the countdown to the next life (updates every second).
class LivesPill extends StatefulWidget {
  const LivesPill({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  State<LivesPill> createState() => _LivesPillState();
}

class _LivesPillState extends State<LivesPill> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
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
    return StatPill(
      icon: const Center(child: HeartIcon(size: 28)),
      value: '${p.lives}',
      sub: next == null ? 'Full' : formatDuration(next),
      onAdd: widget.onTap,
    );
  }
}

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

class CoinsPill extends StatelessWidget {
  const CoinsPill({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Services.progress,
        builder: (context, _) => StatPill(
          icon: const Center(child: CoinIcon(size: 28)),
          value: '${Services.progress.coins}',
          onAdd: onTap,
        ),
      );
}

/// Shows what a reward is (coins and boosters) as a row of icons.
class RewardIcons extends StatelessWidget {
  const RewardIcons(this.reward, {super.key, this.size = 34, this.color = AppColors.chocolate});
  final Reward reward;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        if (reward.coins > 0)
          Row(mainAxisSize: MainAxisSize.min, children: [
            CoinIcon(size: size * 0.8),
            const SizedBox(width: 3),
            Text('${reward.coins}', style: AppText.title(size * 0.5, color: color, shadows: const [])),
          ]),
        for (final e in reward.boosters.entries)
          Row(mainAxisSize: MainAxisSize.min, children: [
            BoosterIcon(e.key, size: size),
            if (e.value > 1)
              Text('x${e.value}', style: AppText.title(size * 0.45, color: color, shadows: const [])),
          ]),
        if (reward.lives > 0)
          Row(mainAxisSize: MainAxisSize.min, children: [
            HeartIcon(size: size * 0.8),
            Text('${reward.lives}', style: AppText.title(size * 0.5, color: color, shadows: const [])),
          ]),
      ],
    );
  }
}

/// Picture of a booster.
class BoosterIcon extends StatelessWidget {
  const BoosterIcon(this.booster, {super.key, this.size = 36});
  final Booster booster;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (booster) {
      Booster.rollingPin => (Icons.horizontal_rule_rounded, const Color(0xFFC98D4E)),
      Booster.freeSwap => (Icons.swap_horiz_rounded, AppColors.sky),
      Booster.startBox => (Icons.card_giftcard_rounded, AppColors.goldDark),
      Booster.extraMoves => (Icons.add_circle_rounded, AppColors.mint),
    };
    if (booster == Booster.rollingPin) {
      return SizedBox(width: size, height: size, child: CustomPaint(painter: RollingPinPainter()));
    }
    if (booster == Booster.extraMoves) {
      return SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)),
          alignment: Alignment.center,
          child: Text('+3', style: AppText.title(size * 0.42)),
        ),
      );
    }
    return Icon(icon, size: size, color: color,
        shadows: const [Shadow(color: Color(0x66000000), offset: Offset(0, 1.5))]);
  }
}

/// A rolling pin drawn in code (booster icon).
class RollingPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.save();
    canvas.translate(w / 2, size.height / 2);
    canvas.rotate(-0.6);
    final handle = Paint()..color = const Color(0xFF8C5220);
    final rect = Rect.fromCenter(center: Offset.zero, width: w * 0.62, height: w * 0.3);
    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF5D3A0), Color(0xFFC98D4E)],
      ).createShader(rect);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.12),
            Radius.circular(w * 0.06)),
        handle);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(w * 0.12)), body);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w * 0.12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF6B3A10),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(RollingPinPainter oldDelegate) => false;
}
