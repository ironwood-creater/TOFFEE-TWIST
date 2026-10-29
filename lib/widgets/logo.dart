import 'package:flutter/material.dart';

import '../game/render/sweet_art.dart';
import '../theme.dart';

/// "Toffee Twist" logo: a golden twisted toffee and the name.
class ToffeeLogo extends StatelessWidget {
  const ToffeeLogo({super.key, this.size = 300});
  final double size;

  @override
  Widget build(BuildContext context) {
    final fontSize = size * 0.2;
    Widget title(String text, double fs) => Stack(
          children: [
            Text(
              text,
              style: TextStyle(
                fontFamily: AppText.heading,
                fontWeight: FontWeight.w800,
                fontSize: fs,
                height: 1,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = fs * 0.16
                  ..strokeJoin = StrokeJoin.round
                  ..color = AppColors.chocolateDark,
              ),
            ),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF4C2), AppColors.gold, AppColors.goldDark],
              ).createShader(r),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: AppText.heading,
                  fontWeight: FontWeight.w800,
                  fontSize: fs,
                  height: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size * 0.62,
            height: size * 0.42,
            child: CustomPaint(painter: _LogoToffeePainter()),
          ),
          FittedBox(fit: BoxFit.scaleDown, child: title('Toffee', fontSize * 1.25)),
          Transform.translate(
            offset: Offset(0, -fontSize * 0.12),
            child: FittedBox(fit: BoxFit.scaleDown, child: title('Twist', fontSize * 1.25)),
          ),
          Container(
            margin: EdgeInsets.only(top: fontSize * 0.05),
            padding: EdgeInsets.symmetric(horizontal: fontSize * 0.6, vertical: fontSize * 0.08),
            decoration: BoxDecoration(
              color: AppColors.pink,
              borderRadius: BorderRadius.circular(fontSize),
              border: Border.all(color: AppColors.chocolateDark, width: 2.5),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Sweet Match 3', maxLines: 1, style: AppText.title(fontSize * 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoToffeePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide * 1.35;
    SweetArt.paintLogoToffee(
        canvas, Rect.fromCenter(center: size.center(Offset.zero), width: s, height: s));
  }

  @override
  bool shouldRepaint(_LogoToffeePainter oldDelegate) => false;
}
