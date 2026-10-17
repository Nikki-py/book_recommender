import 'package:flutter/material.dart';

/// Softly pulsing blank covers shown while books load, in place of a spinner.
/// A horizontal row by default, or a 3-column grid with [grid].
class CoverPlaceholders extends StatefulWidget {
  final bool grid;
  const CoverPlaceholders({super.key, this.grid = false});

  @override
  State<CoverPlaceholders> createState() => _CoverPlaceholdersState();
}

class _CoverPlaceholdersState extends State<CoverPlaceholders> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _cover(Color base, {double? width}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          width: width,
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
        ),
      ),
      const SizedBox(height: 8),
      Container(height: 10, width: 70, color: base),
      const SizedBox(height: 6),
      Container(height: 8, width: 44, color: base),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final base = Color.lerp(
          scheme.surfaceContainer,
          scheme.outline.withValues(alpha: 0.6),
          still ? 0.3 : _pulse.value * 0.6,
        )!;
        if (widget.grid) {
          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 18,
              crossAxisSpacing: 14,
              childAspectRatio: 0.5,
            ),
            itemCount: 9,
            itemBuilder: (context, _) => _cover(base),
          );
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, _) => SizedBox(width: 104, child: _cover(base, width: 104)),
        );
      },
    );
  }
}
