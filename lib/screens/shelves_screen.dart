import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/shelf_book.dart';
import '../theme/app_theme.dart';
import '../utils/series.dart';
import '../widgets/book_popup.dart';
import '../widgets/fairy_lights.dart';

/// The cozy dark page: wooden shelves with fairy lights. One page shows
/// Already read, the other TBR; the glass buttons (or a swipe) switch between them.
class ShelvesScreen extends StatefulWidget {
  const ShelvesScreen({super.key});

  @override
  State<ShelvesScreen> createState() => _ShelvesScreenState();
}

class _ShelvesScreenState extends State<ShelvesScreen> with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = AppScope.of(context).profile.twinkle && !MediaQuery.disableAnimationsOf(context);
    if (on && !_twinkle.isAnimating) {
      _twinkle.repeat();
    } else if (!on && _twinkle.isAnimating) {
      _twinkle.stop();
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  void _goTo(int page) =>
      _pages.animateToPage(page, duration: const Duration(milliseconds: 420), curve: Curves.easeInOutCubic);

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final twinkle = scope.profile.twinkle ? _twinkle : null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(center: Alignment(0, -1.2), radius: 1.4, colors: [Color(0xFF3A2E2C), AppColors.night]),
      ),
      child: StreamBuilder<List<ShelfBook>>(
        stream: scope.shelf.watchShelf(),
        builder: (context, snap) {
          final all = snap.data ?? const <ShelfBook>[];
          final read = all.where((b) => b.shelf == Shelf.read).toList();
          final tbr = all.where((b) => b.shelf == Shelf.tbr).toList();
          return Stack(
            children: [
              PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _ShelfPage(
                    title: 'Already read',
                    books: read,
                    emptyText: 'Books you finish land here.',
                    twinkle: twinkle,
                    seed: 1,
                  ),
                  _ShelfPage(
                    title: 'TBR',
                    books: tbr,
                    emptyText: 'Tap the bookmark on any book to add it to your TBR.',
                    twinkle: twinkle,
                    seed: 2,
                  ),
                ],
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: bottomInset + 84,
                child: Row(
                  children: [
                    Expanded(
                      child: _GlassButton(label: 'Already read shelf', on: _page == 0, onTap: () => _goTo(0)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GlassButton(label: 'TBR shelf', on: _page == 1, onTap: () => _goTo(1)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _GlassButton({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Glass(
      bright: on,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Center(
              child: Text(
                label,
                style: AppText.sans(size: 14, color: AppColors.cream, weight: on ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShelfPage extends StatelessWidget {
  final String title;
  final List<ShelfBook> books;
  final String emptyText;
  final Animation<double>? twinkle;
  final int seed;

  const _ShelfPage({
    required this.title,
    required this.books,
    required this.emptyText,
    required this.twinkle,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final units = arrangeUnits(books);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = _fillRows(units, constraints.maxWidth - 32);
        final minRows = max(3, ((constraints.maxHeight - 260) / _rowHeight).ceil());
        return ListView(
          padding: EdgeInsets.fromLTRB(0, MediaQuery.paddingOf(context).top + 28, 0, bottomInset + 170),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(title, style: AppText.serif(size: 34, color: AppColors.cream)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text(
                books.isEmpty ? emptyText : '${books.length} ${books.length == 1 ? 'book' : 'books'} on this shelf',
                style: AppText.sans(size: 13, color: const Color(0xFFB9AB95)),
              ),
            ),
            // Always a full bookcase: books fill from the top, the rest stay empty.
            for (var i = 0; i < max(rows.length, minRows); i++)
              _ShelfRow(
                units: i < rows.length ? rows[i] : const [],
                twinkle: twinkle,
                seed: seed * 100 + i,
                onMove: (dragged, target) => _move(context, units, dragged, target),
              ),
          ],
        );
      },
    );
  }

  /// Drops the dragged book (and its whole series) next to the target book.
  void _move(BuildContext context, List<List<ShelfBook>> units, String draggedId, String targetId) {
    final from = units.indexWhere((u) => u.any((b) => b.bookId == draggedId));
    final to = units.indexWhere((u) => u.any((b) => b.bookId == targetId));
    if (from < 0 || to < 0 || from == to) return;
    final reordered = [...units];
    final moved = reordered.removeAt(from);
    reordered.insert(to, moved);
    AppScope.of(context).shelf.reorderSome(books, [for (final u in reordered) ...u.map((b) => b.bookId)]);
  }

  /// Packs units onto shelves left to right, keeping a series together when it fits.
  static List<List<List<ShelfBook>>> _fillRows(List<List<ShelfBook>> units, double width) {
    final rows = <List<List<ShelfBook>>>[];
    var row = <List<ShelfBook>>[];
    var used = 0.0;
    for (final unit in units) {
      final w = unit.fold(0.0, (sum, b) => sum + spineWidth(b) + _gap);
      if (used + w > width && row.isNotEmpty) {
        rows.add(row);
        row = [];
        used = 0;
      }
      if (w > width) {
        // A series longer than a shelf: split it across shelves.
        for (final b in unit) {
          final bw = spineWidth(b) + _gap;
          if (used + bw > width && row.isNotEmpty) {
            rows.add(row);
            row = [];
            used = 0;
          }
          row.add([b]);
          used += bw;
        }
      } else {
        row.add(unit);
        used += w;
      }
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }
}

const _gap = 3.0;
const _rowHeight = 236.0;
const _plankTop = 176.0;
const _plankHeight = 18.0;

/// Groups books for the shelf: books being read first, then everything in the
/// user's order, with each series pulled together in series order.
List<List<ShelfBook>> arrangeUnits(List<ShelfBook> books) {
  final ordered = [...books.where((b) => b.reading), ...books.where((b) => !b.reading)];
  final units = <List<ShelfBook>>[];
  final placed = <String>{};
  for (final book in ordered) {
    if (placed.contains(book.bookId)) continue;
    final series = book.seriesName?.toLowerCase();
    if (series == null || book.reading) {
      units.add([book]);
      placed.add(book.bookId);
      continue;
    }
    final members =
        ordered.where((b) => !b.reading && b.seriesName?.toLowerCase() == series && !placed.contains(b.bookId)).toList()
          ..sort((a, b) => (a.seriesNumber ?? 999).compareTo(b.seriesNumber ?? 999));
    units.add(members);
    placed.addAll(members.map((b) => b.bookId));
  }
  return units;
}

/// Longer books get wider spines.
double spineWidth(ShelfBook b) => b.pageCount <= 0 ? 28 : (18 + b.pageCount / 22).clamp(22.0, 46.0);

/// Heights vary a little so the shelf looks real; the same book is always the same height.
double spineHeight(ShelfBook b) => 132 + (b.bookId.hashCode.abs() % 38).toDouble();

Color spineColor(ShelfBook b) {
  // Books in a series share a colour.
  final key = b.seriesName?.toLowerCase() ?? b.bookId;
  return AppColors.spines[key.hashCode.abs() % AppColors.spines.length];
}

class _ShelfRow extends StatelessWidget {
  final List<List<ShelfBook>> units;
  final Animation<double>? twinkle;
  final int seed;
  final void Function(String dragged, String target) onMove;

  const _ShelfRow({required this.units, required this.twinkle, required this.seed, required this.onMove});

  @override
  Widget build(BuildContext context) {
    final books = [for (final u in units) ...u];
    final rects = <Rect>[];
    var x = 16.0;
    for (final b in books) {
      final w = spineWidth(b), h = spineHeight(b);
      rects.add(Rect.fromLTWH(x, _plankTop - h, w, h));
      x += w + _gap;
    }
    return SizedBox(
      height: _rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < books.length; i++)
            Positioned.fromRect(
              rect: rects[i],
              child: _DraggableSpine(book: books[i], onMove: onMove),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: _plankTop,
            height: _plankHeight,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 10))],
              ),
              child: CustomPaint(painter: WoodPainter(seed)),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: FairyLightsPainter(
                    seed: seed,
                    plankBottom: _plankTop + _plankHeight,
                    books: rects,
                    twinkle: twinkle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableSpine extends StatelessWidget {
  final ShelfBook book;
  final void Function(String dragged, String target) onMove;
  const _DraggableSpine({required this.book, required this.onMove});

  @override
  Widget build(BuildContext context) {
    final spine = BookSpine(book: book);
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != book.bookId,
      onAcceptWithDetails: (d) => onMove(d.data, book.bookId),
      builder: (context, candidates, _) => LongPressDraggable<String>(
        data: book.bookId,
        feedback: Material(
          type: MaterialType.transparency,
          child: Transform.rotate(angle: -0.06, child: Opacity(opacity: 0.9, child: spine)),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: spine),
        child: GestureDetector(
          onTap: () => showBookPopup(context, book.toBook()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.translationValues(candidates.isEmpty ? 0 : 6, 0, 0),
            child: spine,
          ),
        ),
      ),
    );
  }
}

/// One book standing on the shelf: title and author running up the spine.
class BookSpine extends StatelessWidget {
  final ShelfBook book;
  const BookSpine({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final color = spineColor(book);
    final light = color.computeLuminance() > 0.25;
    final ink = light ? AppColors.charcoal : AppColors.cream;
    final w = spineWidth(book), h = spineHeight(book);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              // A faint light edge keeps dark spines visible against the dark wall.
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              gradient: LinearGradient(
                colors: [Color.lerp(color, Colors.white, 0.14)!, color, Color.lerp(color, Colors.black, 0.22)!],
                stops: const [0, 0.5, 1],
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: RotatedBox(
              quarterTurns: 3,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      shortTitle(book.title) +
                          (book.seriesNumber != null ? ' #${book.seriesNumber!.toStringAsFixed(0)}' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.serif(size: min(13, w * 0.42), color: ink),
                    ),
                  ),
                  if (book.authors.isNotEmpty && w >= 30) ...[
                    const SizedBox(width: 8),
                    Text(
                      book.authors.first.split(' ').last,
                      style: AppText.sans(
                        size: 9,
                        color: ink.withValues(alpha: 0.75),
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (book.reading)
            Positioned(
              top: -2,
              right: 4,
              child: ClipPath(
                clipper: _RibbonClipper(),
                child: Container(width: 8, height: 30, color: AppColors.sand),
              ),
            ),
        ],
      ),
    );
  }
}

/// A bookmark ribbon with a notched end.
class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(size.width / 2, size.height - 6)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
