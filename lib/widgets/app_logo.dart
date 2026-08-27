import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Njangi-Pay signature mark v4: a single classy motif -- a gold coin
/// medallion with an embossed ring and an "N" monogram. Earlier versions
/// combined a book + pen + coins into one busy composite that read as
/// cluttered at small sizes; this pulls back to one clean idea done well.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinMonogramPainter()),
    );
  }
}

class _CoinMonogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);

    // Outer coin -- gold fill
    canvas.drawCircle(center, w / 2, Paint()..color = AppColors.gold);

    // Embossed ring -- a slightly darker gold stroke inset from the edge,
    // giving the coin a minted/embossed look instead of a flat circle
    canvas.drawCircle(
      center,
      w * 0.42,
      Paint()
        ..color = AppColors.indigo.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03,
    );

    // Outer edge stroke for definition
    canvas.drawCircle(
      center,
      w / 2 - w * 0.01,
      Paint()
        ..color = AppColors.indigo.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );

    // "N" monogram, centered, bold serif -- reads as a minted medallion
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: AppColors.indigo,
          fontSize: w * 0.46,
          fontWeight: FontWeight.w800,
          fontFamily: 'Georgia',
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}