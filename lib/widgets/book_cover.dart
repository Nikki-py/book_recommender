import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A book's cover from Google Books, with a plain titled cover while it loads
/// or when the book has none.
class BookCover extends StatelessWidget {
  final String url;
  final String title;
  final double width;
  final double height;
  final double radius;

  const BookCover({
    super.key,
    required this.url,
    required this.title,
    this.width = 100,
    this.height = 150,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.spines[title.hashCode.abs() % AppColors.spines.length],
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        title,
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: AppText.serif(size: width / 7, color: AppColors.cream),
      ),
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
            ),
    );
  }
}
