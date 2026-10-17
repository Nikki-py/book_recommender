import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The row of books on the personalise slides. It slides along with the
/// PageView under it; the book for the current slide turns to face you and
/// then opens to a page with a quote.
class BookParade extends StatelessWidget {
  final PageController controller;

  /// 0 to 1: how far the current book has opened. Restarted on every new slide.
  final Animation<double> open;
  final List<({String text, String by})> quotes;

  const BookParade({super.key, required this.controller, required this.open, required this.quotes});

  // Spines standing to the right of each slide's book, clear of it when it
  // opens: (width, height, colour index). The ones after the previous book
  // fill the left side.
  static const _neighbours = [
    _SpineSpec(30, 170, 1),
    _SpineSpec(26, 150, 4),
    _SpineSpec(34, 182, 6),
    _SpineSpec(28, 160, 5),
    _SpineSpec(36, 186, 0),
  ];

  static const _heroColours = [AppColors.green, AppColors.brown, AppColors.charcoal];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final shelfY = constraints.maxHeight - 18;
        return AnimatedBuilder(
          animation: Listenable.merge([controller, open]),
          builder: (context, _) {
            final page = controller.hasClients && controller.position.haveDimensions
                ? controller.page ?? 0
                : controller.initialPage.toDouble();
            final children = <Widget>[];
            for (var i = 0; i < quotes.length; i++) {
              final heroX = w / 2 + (i - page) * w;
              // The open book spans 140 either side of its centre; spines start past that.
              final placed = <(double, _SpineSpec)>[];
              var x = heroX + 140;
              for (final n in _neighbours) {
                placed.add((x, n));
                x += n.width + 3;
              }
              if (i == 0) {
                // The first slide has no book before it, so give it spines on the left too.
                x = heroX - 140;
                for (final n in _neighbours) {
                  x -= n.width + 3;
                  placed.add((x, n));
                }
              }
              for (final (sx, n) in placed) {
                if (sx + n.width < -40 || sx > w + 40) continue;
                children.add(
                  Positioned(
                    left: sx,
                    top: shelfY - n.height,
                    child: _Spine(
                      width: n.width,
                      height: n.height,
                      color: AppColors.spines[(n.colour + i * 2) % AppColors.spines.length],
                    ),
                  ),
                );
              }
              final closeness = (1 - (i - page).abs()).clamp(0.0, 1.0);
              children.add(
                Positioned(
                  left: heroX - 140,
                  top: shelfY - 210,
                  width: 280,
                  height: 210,
                  // As the cover swings toward you it grows a little; cut it off at
                  // the shelf so it never pokes out underneath.
                  child: ClipRect(
                    clipper: const _AboveShelf(),
                    child: _HeroBook(
                      closeness: closeness,
                      open: open.value,
                      color: _heroColours[i % _heroColours.length],
                      quote: quotes[i],
                    ),
                  ),
                ),
              );
            }
            children.add(
              Positioned(
                left: 0,
                right: 0,
                top: shelfY,
                child: Container(height: 6, color: AppColors.brown),
              ),
            );
            return Stack(clipBehavior: Clip.hardEdge, children: children);
          },
        );
      },
    );
  }
}

/// Clips only the bottom edge, leaving room above and to the sides.
class _AboveShelf extends CustomClipper<Rect> {
  const _AboveShelf();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-200, -200, size.width + 200, size.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

class _SpineSpec {
  final double width;
  final double height;
  final int colour;
  const _SpineSpec(this.width, this.height, this.colour);
}

class _Spine extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  const _Spine({required this.width, required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.charcoal, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(height: 10),
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            color: AppColors.cream.withValues(alpha: 0.6),
          ),
          Container(
            height: 2,
            margin: const EdgeInsets.fromLTRB(5, 0, 5, 14),
            color: AppColors.cream.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

/// One slide's book: a spine when far away, turning to show its cover as it
/// reaches the middle, then the cover swings open on its left edge.
class _HeroBook extends StatelessWidget {
  final double closeness;
  final double open;
  final Color color;
  final ({String text, String by}) quote;

  const _HeroBook({required this.closeness, required this.open, required this.color, required this.quote});

  static const _w = 130.0;
  static const _h = 190.0;

  /// A soft shadow along the left edge, where the pages meet the spine.
  static const _foldShadow = LinearGradient(colors: [Color(0x33000000), Color(0x00000000)], stops: [0, 0.18]);

  @override
  Widget build(BuildContext context) {
    if (closeness < 0.5) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: _Spine(width: 40, height: _h, color: color),
      );
    }
    final turn = ((closeness - 0.5) / 0.5).clamp(0.0, 1.0);
    final openAmount = Curves.easeInOut.transform(open) * (turn == 1 ? 1 : 0);
    // A positive angle swings the cover's free edge toward the viewer, like a
    // real cover being lifted open, and lays it down to the left of the spine.
    final coverAngle = openAmount * pi * 0.94;
    final showInside = coverAngle.abs() > pi / 2;

    final cover = Container(
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        color: showInside ? const Color(0xFFEFE2BC) : color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.charcoal, width: 2),
      ),
      // The inside is seen mirrored, so this shadow lands in the fold by the spine.
      foregroundDecoration: showInside ? const BoxDecoration(gradient: _foldShadow) : null,
      child: showInside
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 70, height: 2, color: AppColors.cream.withValues(alpha: 0.7)),
                const SizedBox(height: 14),
                Text('TBR', style: AppText.serif(size: 26, color: AppColors.cream)),
                const SizedBox(height: 14),
                Container(width: 70, height: 2, color: AppColors.cream.withValues(alpha: 0.7)),
              ],
            ),
    );

    final page = Container(
      width: _w,
      height: _h,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.charcoal, width: 1.5),
      ),
      foregroundDecoration: openAmount > 0 ? const BoxDecoration(gradient: _foldShadow) : null,
      child: Opacity(
        opacity: ((openAmount - 0.5) * 2).clamp(0.0, 1.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: _w - 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(quote.text, textAlign: TextAlign.center, style: AppText.hand(size: 17)),
                if (quote.by.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(quote.by, style: AppText.sans(size: 10, color: AppColors.muted)),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        // Slide right as it opens so the open book stays centred.
        offset: Offset(openAmount * _w / 2, 0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY((1 - turn) * pi / 2),
          child: SizedBox(
            width: _w,
            height: _h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                page,
                Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0009)
                    ..rotateY(coverAngle),
                  child: cover,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
