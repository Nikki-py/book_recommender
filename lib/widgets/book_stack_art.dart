import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The cartoon stack of books on the welcome screen, drawn in TBR's colours.
/// Swap this for a watercolour image later by replacing it with Image.asset.
class BookStackArt extends StatelessWidget {
  final double width;
  const BookStackArt({super.key, this.width = 280});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 1.1,
      child: CustomPaint(painter: _StackPainter()),
    );
  }
}

class _StackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 300 x 330 grid, then scaled to fit.
    canvas.scale(size.width / 300, size.height / 330);
    final outline = Paint()
      ..color = AppColors.charcoal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    void book(double x, double y, double w, double h, Color color, {bool labelLeft = false}) {
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(5));
      canvas.drawRRect(rect, Paint()..color = color);
      canvas.drawRRect(rect, outline);
      // Page edges on one end.
      final pages = labelLeft ? Rect.fromLTWH(x + 4, y + 4, 22, h - 8) : Rect.fromLTWH(x + w - 32, y + 4, 28, h - 8);
      canvas.drawRect(pages, Paint()..color = AppColors.paper);
      canvas.drawRect(pages, outline..strokeWidth = 2);
      outline.strokeWidth = 3;
    }

    final cream = Paint()
      ..color = AppColors.cream
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    book(40, 276, 220, 40, AppColors.brown);
    canvas.drawLine(const Offset(60, 282), const Offset(60, 310), cream);
    canvas.drawLine(const Offset(70, 282), const Offset(70, 310), cream);

    book(58, 236, 196, 40, AppColors.green, labelLeft: true);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(150, 250, 70, 10), const Radius.circular(2)),
      Paint()..color = AppColors.cream,
    );

    book(46, 200, 214, 36, AppColors.sand);
    canvas.drawLine(const Offset(90, 204), const Offset(90, 232), outline);
    canvas.drawLine(const Offset(190, 204), const Offset(190, 232), outline);

    book(70, 166, 180, 34, AppColors.charcoal, labelLeft: true);
    canvas.drawCircle(const Offset(200, 183), 7, Paint()..color = AppColors.sand);

    book(56, 130, 196, 36, AppColors.rust);
    final thin = Paint()
      ..color = AppColors.cream
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(80, 138), const Offset(160, 138), thin);
    canvas.drawLine(const Offset(80, 158), const Offset(160, 158), thin);

    book(78, 96, 150, 34, AppColors.green, labelLeft: true);

    // Open book on top.
    final paper = Paint()..color = AppColors.paper;
    final left = Path()
      ..moveTo(150, 70)
      ..cubicTo(120, 55, 85, 55, 60, 66)
      ..lineTo(60, 92)
      ..cubicTo(85, 82, 120, 82, 150, 96)
      ..close();
    final right = Path()
      ..moveTo(150, 70)
      ..cubicTo(180, 55, 215, 55, 240, 66)
      ..lineTo(240, 92)
      ..cubicTo(215, 82, 180, 82, 150, 96)
      ..close();
    for (final p in [left, right]) {
      canvas.drawPath(p, paper);
      canvas.drawPath(p, outline);
    }
    final lines = Path()
      ..moveTo(75, 70)
      ..cubicTo(100, 64, 125, 66, 145, 76)
      ..moveTo(155, 76)
      ..cubicTo(175, 66, 200, 64, 225, 70);
    canvas.drawPath(lines, outline..strokeWidth = 1.5);
    outline.strokeWidth = 3;

    // Sparkles.
    final sparkle = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(262, 42), const Offset(262, 58), sparkle..color = AppColors.brown);
    canvas.drawLine(const Offset(254, 50), const Offset(270, 50), sparkle);
    canvas.drawLine(const Offset(40, 104), const Offset(40, 116), sparkle..color = AppColors.green);
    canvas.drawLine(const Offset(34, 110), const Offset(46, 110), sparkle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
