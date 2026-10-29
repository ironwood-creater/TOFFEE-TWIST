import 'package:flutter/material.dart';

import '../game/logic/level.dart';
import '../game/render/sweet_art.dart';
import '../theme.dart';
import 'ui.dart';

/// Picture for a goal type (sweet, caramel tile, crate, nut, star).
class GoalIcon extends StatelessWidget {
  const GoalIcon(this.goal, {super.key, this.size = 34});
  final GoalDef goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (goal.type) {
      GoalType.collect => SweetIcon(goal.color, size: size),
      GoalType.nuts => SweetIcon(-1, size: size, nut: true),
      GoalType.score => Icon(Icons.star_rounded, size: size, color: AppColors.gold,
          shadows: const [Shadow(color: Color(0xFFB36B00), offset: Offset(0, 1.5))]),
      GoalType.caramel => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _TilePainter((c, r) => SweetArt.paintCaramel(c, r, 1))),
        ),
      GoalType.crates => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _TilePainter((c, r) => SweetArt.paintCrate(c, r, 2))),
        ),
    };
  }
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.fn);
  final void Function(Canvas, Rect) fn;

  @override
  void paint(Canvas canvas, Size size) => fn(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(_TilePainter oldDelegate) => false;
}

/// Short text describing a goal, e.g. "Collect 20 Donuts".
String goalText(GoalDef g, int target) => switch (g.type) {
      GoalType.score => 'Score $target points',
      GoalType.collect => 'Collect $target ${_plural(g.color, target)}',
      GoalType.caramel => 'Clear $target caramel tiles',
      GoalType.crates => 'Break $target wooden crates',
      GoalType.nuts => 'Bring $target golden nuts down',
    };

const _names = ['Toffee', 'Cupcake', 'Donut', 'Macaron', 'Lollipop', 'Chocolate'];

String _plural(int color, int n) => n == 1 ? _names[color] : '${_names[color]}s';

/// Goal icon with the number still needed (or a tick when done).
class GoalChip extends StatelessWidget {
  const GoalChip({super.key, required this.goal, required this.remaining, this.size = 34});
  final GoalDef goal;
  final int remaining;
  final double size;

  @override
  Widget build(BuildContext context) {
    final done = remaining <= 0;
    return SizedBox(
      width: size + 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GoalIcon(goal, size: size),
              if (done)
                Positioned(
                  right: -6,
                  bottom: -4,
                  child: Container(
                    decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(1),
                    child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 1),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: FittedBox(
              key: ValueKey(remaining),
              fit: BoxFit.scaleDown,
              child: Text(
                done ? '' : (goal.type == GoalType.score ? _short(remaining) : '$remaining'),
                maxLines: 1,
                style: AppText.title(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _short(int n) => n >= 10000 ? '${(n / 1000).toStringAsFixed(0)}k' : '$n';
}
