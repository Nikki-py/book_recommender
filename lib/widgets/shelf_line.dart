import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The footer on the sign-up and log-in screens: a little row of books whose
/// shelf (thick) carries on as a thin line to a link on the right.
class ShelfLine extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const ShelfLine({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 80,
          height: 54,
          child: CustomPaint(painter: _BooksIconPainter(color, Theme.of(context).colorScheme.surface)),
        ),
        Expanded(
          child: Container(height: 1.5, margin: const EdgeInsets.only(bottom: 0.75), color: color),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              label,
              style: AppText.sans(size: 17, color: color, weight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

class _BooksIconPainter extends CustomPainter {
  final Color color;
  final Color background;
  _BooksIconPainter(this.color, this.background);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final bg = Paint()..color = background;
    final h = size.height;

    // Thick shelf under the books; it meets the thin line on the right.
    canvas.drawRRect(RRect.fromLTRBR(0, h - 4, size.width, h, const Radius.circular(2)), fill);

    // Three upright books and one leaning.
    canvas.drawRect(Rect.fromLTWH(4, h - 40, 13, 36), fill);
    canvas.drawRect(Rect.fromLTWH(7, h - 33, 7, 3), bg);
    canvas.drawRect(Rect.fromLTWH(7, h - 15, 7, 3), bg);
    canvas.drawRect(Rect.fromLTWH(19, h - 34, 10, 30), fill);
    canvas.drawRect(Rect.fromLTWH(22, h - 28, 4, 18), bg);
    canvas.drawRect(Rect.fromLTWH(31, h - 44, 10, 40), fill);

    canvas.save();
    canvas.translate(43, h - 4);
    canvas.rotate(-0.42);
    canvas.drawRect(const Rect.fromLTWH(0, -34, 11, 34), fill);
    canvas.drawRect(const Rect.fromLTWH(3, -26, 5, 8), bg);
    canvas.restore();

    // Sparkles.
    final s = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(64, h - 46), Offset(64, h - 38), s);
    canvas.drawLine(Offset(60, h - 42), Offset(68, h - 42), s);
    canvas.drawCircle(Offset(71, h - 33), 1.3, fill);
  }

  @override
  bool shouldRepaint(covariant _BooksIconPainter old) => old.color != color || old.background != background;
}
