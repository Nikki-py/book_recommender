import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A rounded button that can be picked: used for genres, vibes and filters.
/// Picked ones fill in green.
class Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// When set, the pill is always filled with this colour (Explore's genre buttons).
  final Color? color;

  const Pill({super.key, required this.label, required this.onTap, this.selected = false, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? (selected ? AppColors.green : Colors.transparent);
    final light = fill.computeLuminance() > 0.25;
    final textColor = color != null || selected ? (light ? AppColors.charcoal : AppColors.cream) : scheme.onSurface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color != null || selected ? fill : scheme.onSurface.withValues(alpha: 0.35)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected && color == null) ...[
                  const Icon(Icons.check, size: 16, color: AppColors.cream),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: AppText.sans(size: 14, color: textColor, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
