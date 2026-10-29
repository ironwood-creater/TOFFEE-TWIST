import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/logic/types.dart';
import '../game/render/sweet_art.dart';
import '../services/services.dart';
import '../theme.dart';

/// Big shiny golden button.
class GoldButton extends StatefulWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fontSize = 24,
    this.width,
    this.height = 58,
    this.color = GoldButtonColor.gold,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double fontSize;
  final double? width;
  final double height;
  final GoldButtonColor color;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

enum GoldButtonColor { gold, green, pink, choco }

class _GoldButtonState extends State<GoldButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final (top, bottom, edge) = switch (widget.color) {
      GoldButtonColor.gold => (AppColors.goldLight, AppColors.goldDark, const Color(0xFF9C5F00)),
      GoldButtonColor.green => (const Color(0xFF9BEFB9), const Color(0xFF2FAE6A), const Color(0xFF1C6E42)),
      GoldButtonColor.pink => (const Color(0xFFFFB6D3), const Color(0xFFE2558F), const Color(0xFF9A2C5B)),
      GoldButtonColor.choco => (AppColors.chocolateLight, AppColors.chocolate, AppColors.chocolateDark),
    };
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                Services.audio.play(Sfx.button);
                Services.haptics.light();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 80),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Container(
              width: widget.width,
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.height / 2.4),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [top, bottom],
                ),
                border: Border.all(color: edge, width: 3),
                boxShadow: [
                  BoxShadow(color: edge, offset: const Offset(0, 4)),
                  const BoxShadow(color: Color(0x33000000), offset: Offset(0, 7), blurRadius: 6),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 8)],
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: Text(widget.label, style: AppText.title(widget.fontSize)),
                        ),
                        if (widget.subtitle != null)
                          Text(widget.subtitle!,
                              style: AppText.label(12, color: Colors.white, weight: FontWeight.w800)),
                      ],
                    ),
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

/// Small round icon button (pause, close, settings ...).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onPressed, this.size = 46, this.tooltip});
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: () {
          Services.audio.play(Sfx.button);
          Services.haptics.light();
          onPressed();
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.goldLight, AppColors.goldDark],
            ),
            border: Border.all(color: const Color(0xFF9C5F00), width: 2.5),
            boxShadow: const [BoxShadow(color: Color(0xFF9C5F00), offset: Offset(0, 3))],
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.58,
              shadows: const [Shadow(color: Color(0x88000000), offset: Offset(0, 1.5))]),
        ),
      ),
    );
  }
}

/// Chocolate-brown rounded panel with a cream inside.
class ChocoPanel extends StatelessWidget {
  const ChocoPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.title});
  final Widget child;
  final EdgeInsets padding;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      decoration: BoxDecoration(
        color: AppColors.chocolate,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.chocolateDark, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(7),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF9EE), AppColors.creamDark],
          ),
        ),
        padding: padding,
        child: child,
      ),
    );
    if (title == null) return panel;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(padding: const EdgeInsets.only(top: 22), child: panel),
        Positioned(top: 0, child: RibbonTitle(title!)),
      ],
    );
  }
}

/// Caramel ribbon with a title, used on top of panels.
class RibbonTitle extends StatelessWidget {
  const RibbonTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFB955), AppColors.caramelDark],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chocolateDark, width: 3),
      ),
      child: Text(text, style: AppText.title(26)),
    );
  }
}

/// Draws one sweet (or special) as a widget.
class SweetIcon extends StatelessWidget {
  const SweetIcon(this.color, {super.key, this.size = 32, this.special = Special.none, this.nut = false});
  final int color;
  final double size;
  final Special special;
  final bool nut;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SweetPainter(color, special, nut)),
      );
}

class _SweetPainter extends CustomPainter {
  _SweetPainter(this.color, this.special, this.nut);
  final int color;
  final Special special;
  final bool nut;

  @override
  void paint(Canvas canvas, Size size) => SweetArt.paintPiece(canvas, Offset.zero & size,
      color: color, special: special, nut: nut);

  @override
  bool shouldRepaint(_SweetPainter old) =>
      old.color != color || old.special != special || old.nut != nut;
}

/// Small pill showing a value with an icon (coins, lives ...).
class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.icon, required this.value, this.onAdd, this.sub});
  final Widget icon;
  final String value;
  final String? sub;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 4, right: 6),
        decoration: BoxDecoration(
          color: AppColors.chocolate.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.chocolateDark, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 32, height: 32, child: icon),
            const SizedBox(width: 4),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppText.title(17)),
                if (sub != null)
                  Text(sub!, style: AppText.label(10, color: AppColors.goldLight, weight: FontWeight.w800)),
              ],
            ),
            if (onAdd != null) ...[
              const SizedBox(width: 4),
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
                child: const Icon(Icons.add, size: 18, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A golden coin drawn in code.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFFFFF3B0), Color(0xFFFFC928), Color(0xFFD48C00)],
            stops: [0, 0.55, 1],
          ),
          border: Border.all(color: const Color(0xFF9C5F00), width: size * 0.07),
        ),
        alignment: Alignment.center,
        child: Text('T',
            style: TextStyle(
                fontFamily: AppText.heading,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.55,
                height: 1.1,
                color: const Color(0xFFB87400))),
      );
}

/// A red heart (lives).
class HeartIcon extends StatelessWidget {
  const HeartIcon({super.key, this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) => Icon(Icons.favorite,
      size: size,
      color: const Color(0xFFFF5470),
      shadows: const [Shadow(color: Color(0xFF9C1F35), offset: Offset(0, 1.5))]);
}

/// Row of 3 stars, [filled] of them golden.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.filled, this.size = 20, this.spread = true});
  final int filled;
  final double size;
  final bool spread;

  @override
  Widget build(BuildContext context) {
    Widget star(int i) => Padding(
          padding: EdgeInsets.only(bottom: spread && i == 1 ? size * 0.25 : 0),
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: i < filled ? AppColors.gold : const Color(0x55000000),
            shadows: i < filled
                ? const [Shadow(color: Color(0xFFB36B00), offset: Offset(0, 1.5))]
                : null,
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [star(0), star(1), star(2)]);
  }
}

/// Warm sweet-shop background used behind screens.
class ShopBackground extends StatelessWidget {
  const ShopBackground({super.key, required this.child, this.colors});
  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors ?? const [Color(0xFFFFE3B3), Color(0xFFF6C27A), Color(0xFFE8A23B)],
        ),
      ),
      child: CustomPaint(painter: _DotsPainter(), child: child),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x22FFFFFF);
    const step = 34.0;
    var row = 0;
    for (var y = 10.0; y < size.height; y += step, row++) {
      for (var x = (row.isEven ? 10.0 : 27.0); x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 4, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

/// Shows a full-screen dialog with a pop-in animation.
Future<T?> showPopup<T>(BuildContext context, Widget child, {bool dismissible = false}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: const Color(0x99000000),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => SafeArea(child: Center(child: child)),
    transitionBuilder: (context, anim, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
}

/// Lock screen orientation to portrait (called once at start-up).
Future<void> lockPortrait() => SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
