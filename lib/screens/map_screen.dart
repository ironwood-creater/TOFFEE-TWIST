import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/logic/level.dart';
import '../levels/level_generator.dart';
import '../levels/level_repository.dart';
import '../levels/shops.dart';
import '../services/services.dart';
import '../theme.dart';
import '../widgets/top_bar.dart';
import '../widgets/ui.dart';
import 'dialogs/meta_dialogs.dart';
import 'level_flow.dart';
import 'shop_screen.dart';

/// The level map: a winding path through the sweet shops (20 levels each),
/// level 1 at the bottom. Shows stars per level and locks.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.autoStart = false});

  /// Open the current level's start popup right away (Play button).
  final bool autoStart;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  static const double nodeGap = 96;
  static const double headerHeight = 150;
  static const double sectionHeight = headerHeight + levelsPerShop * nodeGap + 30;

  final ScrollController _scroll = ScrollController();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpTo(Services.progress.currentLevel, animate: false);
      if (widget.autoStart) _play(Services.progress.currentLevel);
    });
    Services.audio.startMusic();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Distance from the bottom of the list to the centre of a level node.
  static double levelOffset(int level) {
    final section = (level - 1) ~/ levelsPerShop;
    final i = (level - 1) % levelsPerShop;
    return section * sectionHeight + headerHeight + i * nodeGap + nodeGap / 2;
  }

  void _jumpTo(int level, {bool animate = true}) {
    if (!_scroll.hasClients) return;
    final view = _scroll.position.viewportDimension;
    final target = (levelOffset(level) + 74 - view / 2).clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 700), curve: Curves.easeInOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  bool _flowRunning = false;

  Future<void> _play(int level) async {
    if (_flowRunning || !Services.progress.isUnlocked(level)) return;
    _flowRunning = true;
    try {
      await LevelFlow.play(context, level, onLevelChanged: (id) {
        if (mounted) _jumpTo(id);
      });
    } finally {
      _flowRunning = false;
    }
    if (mounted) {
      setState(() {});
      _jumpTo(Services.progress.currentLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = Services.ads.banner();
    return Scaffold(
      body: ShopBackground(
        colors: const [Color(0xFFFCE5C0), Color(0xFFF3CF98)],
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Services.progress,
            builder: (context, _) => Column(
              children: [
                _MapTopBar(onBack: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.only(bottom: 74),
                        itemCount: shops.length,
                        itemExtent: sectionHeight,
                        itemBuilder: (context, s) => _ShopSection(
                          index: s,
                          pulse: _pulse,
                          onTap: _play,
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: GoldButton(
                          label: 'Level ${math.min(Services.progress.currentLevel, LevelRepository.totalLevels)}',
                          color: GoldButtonColor.green,
                          height: 54,
                          fontSize: 22,
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                          onPressed: () => _play(math.min(Services.progress.currentLevel, LevelRepository.totalLevels)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (banner != null && !Services.progress.removeAds) banner,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: const BoxDecoration(
        color: AppColors.chocolate,
        boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.home_rounded, onPressed: onBack, size: 42, tooltip: 'Home'),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  LivesPill(onTap: () => showPopup<bool>(context, const OutOfLivesDialog(), dismissible: true)),
                  const SizedBox(width: 6),
                  CoinsPill(
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ShopScreen())),
                  ),
                  const SizedBox(width: 6),
                  StatPill(
                    icon: const Icon(Icons.star_rounded, color: AppColors.gold, size: 30),
                    value: '${Services.progress.totalStars}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One shop: a sign at the bottom and 20 level nodes winding upwards.
class _ShopSection extends StatelessWidget {
  const _ShopSection({required this.index, required this.pulse, required this.onTap});
  final int index;
  final Animation<double> pulse;
  final void Function(int level) onTap;

  static double nodeX(int level, double width) {
    final t = (level - 1) * 0.62;
    return width / 2 + math.sin(t) * width * 0.28;
  }

  @override
  Widget build(BuildContext context) {
    final shop = shops[index];
    final first = index * levelsPerShop + 1;
    final p = Services.progress;
    final unlocked = p.isUnlocked(first);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = _MapScreenState.sectionHeight;
        // y measured from the top of this section.
        double nodeY(int level) {
          final i = (level - 1) % levelsPerShop;
          return h - _MapScreenState.headerHeight - i * _MapScreenState.nodeGap - _MapScreenState.nodeGap / 2;
        }

        final points = [
          // connect to the previous shop's last level and the next shop's first
          Offset(nodeX(first - 1, w),
              2 * h - _MapScreenState.headerHeight - (levelsPerShop - 0.5) * _MapScreenState.nodeGap),
          for (var l = first; l < first + levelsPerShop; l++) Offset(nodeX(l, w), nodeY(l)),
          Offset(nodeX(first + levelsPerShop, w), -_MapScreenState.headerHeight - _MapScreenState.nodeGap / 2),
        ];
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [shop.color.withValues(alpha: 0.75), shop.color.withValues(alpha: 0.35)],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: CustomPaint(painter: _PathPainter(points, shop.accent))),
              // Shop sign at the entrance (bottom of the section).
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(child: _ShopSign(shop: shop, number: index + 1, locked: !unlocked)),
              ),
              for (var l = first; l < first + levelsPerShop; l++)
                Positioned(
                  left: nodeX(l, w) - 34,
                  top: nodeY(l) - 34,
                  child: _LevelNode(level: l, pulse: pulse, onTap: () => onTap(l)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.points, this.accent);
  final List<Offset> points;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, mid.dy, mid.dx, mid.dy);
      path.quadraticBezierTo(b.dx, mid.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x55603010),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF7D9A6),
    );
    // Dashed caramel line in the middle of the road.
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.55);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 26) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 12, metric.length)), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter oldDelegate) => false;
}

class _ShopSign extends StatelessWidget {
  const _ShopSign({required this.shop, required this.number, required this.locked});
  final Shop shop;
  final int number;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.chocolateLight, AppColors.chocolate],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: shop.accent, width: 4),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SHOP $number', style: AppText.label(12, color: AppColors.goldLight, weight: FontWeight.w800)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked) const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.lock_rounded, color: AppColors.goldLight, size: 20),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 90),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(shop.name, style: AppText.title(24))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({required this.level, required this.pulse, required this.onTap});
  final int level;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Services.progress;
    final unlocked = p.isUnlocked(level);
    final current = level == p.currentLevel;
    final stars = p.starsFor(level);
    final hard = level > 30 ? LevelGenerator.kindFor(level) == LevelKind.hard : (level == 20 || level == 30);
    final colors = !unlocked
        ? const [Color(0xFFD8CFC6), Color(0xFFA89A8E)]
        : hard
            ? const [Color(0xFFE48AC0), Color(0xFF9C2F6B)]
            : const [AppColors.goldLight, AppColors.goldDark];
    Widget node = Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
        border: Border.all(color: unlocked ? AppColors.chocolate : const Color(0xFF8A7C70), width: 3.5),
        boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 4), blurRadius: 4)],
      ),
      alignment: Alignment.center,
      child: unlocked
          ? Text('$level', style: AppText.title(level >= 100 ? 22 : 26))
          : const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
    );
    if (current) {
      node = AnimatedBuilder(
        animation: pulse,
        builder: (context, child) => Transform.scale(scale: 1 + pulse.value * 0.1, child: child),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0xCCFFFFFF), blurRadius: 18, spreadRadius: 4)],
              ),
            ),
            node,
          ],
        ),
      );
    }
    return Semantics(
      button: unlocked,
      label: 'Level $level${unlocked ? '' : ', locked'}${stars > 0 ? ', $stars stars' : ''}',
      child: GestureDetector(
        onTap: unlocked ? onTap : null,
        child: SizedBox(
          width: 68,
          height: 86,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              node,
              if (stars > 0) Positioned(top: 58, child: StarRow(filled: stars, size: 20)),
            ],
          ),
        ),
      ),
    );
  }
}
