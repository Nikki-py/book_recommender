import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fairy lights for one shelf: loose, uneven swags under the plank, a tail
/// dangling off one end, and sometimes a strand thrown over a tall book.
///
/// Everything is placed from [seed], so the lights look random but stay put
/// between visits. [twinkle] runs 0 to 1 on repeat to make the bulbs shimmer.
class FairyLightsPainter extends CustomPainter {
  final int seed;
  final double plankBottom;
  final List<Rect> books;
  final Animation<double>? twinkle;

  FairyLightsPainter({required this.seed, required this.plankBottom, required this.books, this.twinkle})
    : super(repaint: twinkle);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final strands = <Path>[];
    final y = plankBottom - 2;

    // Swags under the plank, split at uneven points with different sag depths.
    final cuts = <double>[0];
    var x = 0.0;
    while (true) {
      x += size.width * (0.28 + rnd.nextDouble() * 0.3);
      if (x >= size.width - 30) break;
      cuts.add(x);
    }
    cuts.add(size.width);
    final swag = Path()..moveTo(-6, y);
    for (var i = 1; i < cuts.length; i++) {
      final a = cuts[i - 1], b = cuts[i];
      final depth = 16 + rnd.nextDouble() * 34;
      final lean = (rnd.nextDouble() - 0.5) * (b - a) * 0.3;
      final endY = y + rnd.nextDouble() * 5;
      swag.cubicTo(a + (b - a) * 0.3 + lean, y + depth * 1.3, a + (b - a) * 0.7 + lean, y + depth * 1.3, b, endY);
    }
    strands.add(swag);

    // A loose tail hanging off one end.
    final tailX = rnd.nextBool()
        ? size.width * (0.82 + rnd.nextDouble() * 0.12)
        : size.width * (0.05 + rnd.nextDouble() * 0.1);
    final tailLength = 36 + rnd.nextDouble() * 34;
    strands.add(
      Path()
        ..moveTo(tailX, y + 2)
        ..cubicTo(tailX + 7, y + tailLength * 0.35, tailX - 7, y + tailLength * 0.65, tailX + 2, y + tailLength),
    );

    // Sometimes a strand over the top of a tall book, falling down its spine.
    if (books.length >= 3 && rnd.nextDouble() < 0.7) {
      final tall = [...books]..sort((p, q) => p.top.compareTo(q.top));
      final b = tall[rnd.nextInt(min(3, tall.length))];
      final drop = 30 + rnd.nextDouble() * 40;
      strands.add(
        Path()
          ..moveTo(b.left - 10, b.top + 24)
          ..cubicTo(b.left - 4, b.top - 4, b.right - 6, b.top - 6, b.right - 2, b.top + 22)
          ..cubicTo(
            b.right - 8,
            b.top + b.height * 0.45,
            b.right + 10,
            b.top + b.height * 0.75,
            b.right + 2,
            plankBottom + drop,
          ),
      );
    }

    final wire = Paint()
      ..color = const Color(0xFF7A6855).withValues(alpha: 0.85)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final t = twinkle?.value ?? 0;

    for (final strand in strands) {
      canvas.drawPath(strand, wire);
      for (final metric in strand.computeMetrics()) {
        var d = 4 + rnd.nextDouble() * 10;
        while (d < metric.length - 2) {
          final pos = metric.getTangentForOffset(d)!.position + const Offset(0, 2);
          final radius = 1.3 + rnd.nextDouble() * 1.0;
          final warm = rnd.nextDouble() < 0.3;
          final phase = rnd.nextDouble();
          final glow = twinkle == null ? 1.0 : 0.55 + 0.45 * (0.5 + 0.5 * sin(2 * pi * (t + phase)));
          final colour = warm ? const Color(0xFFFFCF8F) : AppColors.bulb;
          canvas.drawCircle(
            pos,
            radius * 6,
            Paint()
              ..color = colour.withValues(alpha: 0.22 * glow)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 4),
          );
          canvas.drawCircle(pos, radius * 2.2, Paint()..color = colour.withValues(alpha: 0.3 * glow));
          canvas.drawCircle(pos, radius, Paint()..color = const Color(0xFFFFF6DC).withValues(alpha: 0.6 + 0.4 * glow));
          d += 15 + rnd.nextDouble() * 16;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant FairyLightsPainter old) =>
      old.seed != seed || old.plankBottom != plankBottom || old.books.length != books.length;
}

/// A wooden plank: warm brown with faint grain and a lighter front edge.
class WoodPainter extends CustomPainter {
  final int seed;
  WoodPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA0613A), AppColors.brown, Color(0xFF5A2B12)],
          stops: [0, 0.45, 1],
        ).createShader(rect),
    );
    final rnd = Random(seed);
    for (var i = 0; i < 7; i++) {
      final y = 4 + rnd.nextDouble() * (size.height - 6);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x < size.width; x += 40) {
        path.quadraticBezierTo(x + 20, y + (rnd.nextDouble() - 0.5) * 3, x + 40, y + (rnd.nextDouble() - 0.5) * 1.5);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = (rnd.nextBool() ? Colors.black : Colors.white).withValues(alpha: 0.06 + rnd.nextDouble() * 0.05)
          ..strokeWidth = 0.6 + rnd.nextDouble() * 0.8
          ..style = PaintingStyle.stroke,
      );
    }
    // A knot or two.
    for (var i = 0; i < 2; i++) {
      final c = Offset(rnd.nextDouble() * size.width, size.height * (0.35 + rnd.nextDouble() * 0.4));
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 14, height: 5),
        Paint()..color = Colors.black.withValues(alpha: 0.12),
      );
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 3), Paint()..color = const Color(0xFFB8794F));
  }

  @override
  bool shouldRepaint(covariant WoodPainter old) => old.seed != seed;
}

/// Frosted glass look used for the shelf buttons and the dark menu bar.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool bright;
  const Glass({super.key, required this.child, this.radius = 28, this.bright = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.cream.withValues(alpha: bright ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.cream.withValues(alpha: bright ? 0.4 : 0.22)),
          ),
          child: child,
        ),
      ),
    );
  }
}
