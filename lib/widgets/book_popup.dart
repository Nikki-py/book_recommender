import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_scope.dart';
import '../models/book.dart';
import '../models/shelf_book.dart';
import '../services/book_api.dart';
import '../theme/app_theme.dart';
import 'book_cover.dart';

/// Opens the book pop-up: a rounded card over the current screen, whose top
/// half takes on the colours of the book's cover.
Future<void> showBookPopup(BuildContext context, Book book) {
  final scope = AppScope.of(context);
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, _, _) => _PopupFrame(
      child: _BookCard(book: book, scope: scope),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6 * animation.value, sigmaY: 6 * animation.value),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Size, shape and swipe-down-to-close for the card.
class _PopupFrame extends StatelessWidget {
  final Widget child;
  const _PopupFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 400) Navigator.of(context).pop();
        },
        child: Container(
          height: height * 0.88,
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30)],
          ),
          // Its own messenger so "Added to TBR" shows on the card, not behind it.
          child: ScaffoldMessenger(
            child: Scaffold(backgroundColor: Colors.transparent, body: child),
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatefulWidget {
  final Book book;
  final AppScope scope;
  const _BookCard({required this.book, required this.scope});

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard> {
  late Book _book = widget.book;
  bool _expanded = false;
  final _scroll = ScrollController();
  late final Future<List<Book>> _moreByAuthor;

  BookApi get _api => widget.scope.api;

  @override
  void initState() {
    super.initState();
    // Books opened from a shelf only carry the basics; fetch the full details.
    if (_book.description.isEmpty) {
      _api
          .book(_book.id)
          .then((full) {
            if (mounted) setState(() => _book = full);
          })
          .catchError((_) {});
    }
    _moreByAuthor = _book.authors.isEmpty
        ? Future.value(const <Book>[])
        : _api.moreByAuthor(_book.authors.first, excludeTitle: _book.title).catchError((_) => <Book>[]);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String text, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 3),
          action: undo == null ? null : SnackBarAction(label: 'Undo', onPressed: undo),
        ),
      );
  }

  Future<void> _toggleTbr(ShelfBook? onShelf) async {
    final shelf = widget.scope.shelf;
    if (onShelf == null) {
      await shelf.add(_book, shelf: Shelf.tbr);
      _toast('Added to TBR', undo: () => shelf.remove(_book.id));
    } else if (onShelf.shelf == Shelf.tbr) {
      await shelf.remove(_book.id);
      _toast('Removed from TBR', undo: () => shelf.add(_book, shelf: Shelf.tbr));
    } else {
      _toast("It's on your Already read shelf.");
    }
  }

  void _readMore() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.offset + 220, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<ShelfBook?>(
      stream: widget.scope.shelf.watchBook(_book.id),
      builder: (context, snap) {
        final onShelf = snap.data;
        return Stack(
          children: [
            _CoverGlow(url: _book.coverUrl),
            Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    children: [
                      _TopButtons(onShelf: onShelf, onBookmark: () => _toggleTbr(onShelf)),
                      const SizedBox(height: 6),
                      Center(
                        child: BookCover(url: _book.coverUrl, title: _book.title, width: 130, height: 195),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _book.title,
                        textAlign: TextAlign.center,
                        style: AppText.serif(size: 26, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _book.authorLine,
                        textAlign: TextAlign.center,
                        style: AppText.sans(size: 15, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      _InfoTiles(book: _book, ownRating: onShelf?.rating),
                      if (onShelf != null) ...[
                        const SizedBox(height: 14),
                        _ShelfActions(entry: onShelf, book: _book, scope: widget.scope, toast: _toast),
                      ],
                      const SizedBox(height: 22),
                      Text('Synopsis', style: AppText.serif(size: 22, color: scheme.onSurface)),
                      const SizedBox(height: 8),
                      _Synopsis(text: _book.description, expanded: _expanded),
                      FutureBuilder<List<Book>>(
                        future: _moreByAuthor,
                        builder: (context, more) {
                          final books = more.data ?? const [];
                          if (books.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'More by ${_book.authors.first}',
                                  style: AppText.serif(size: 20, color: scheme.onSurface),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 130,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: books.length,
                                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                                    itemBuilder: (context, i) => GestureDetector(
                                      onTap: () => showBookPopup(context, books[i]),
                                      child: BookCover(
                                        url: books[i].coverUrl,
                                        title: books[i].title,
                                        width: 84,
                                        height: 126,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  color: scheme.surface,
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _book.description.isEmpty ? null : _readMore,
                          child: Text(_expanded ? 'Show less' : 'Read more'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: scheme.onSurface,
                            side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _showWhereToBuy(context, _book),
                          child: const Text('Where to buy'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The cover, blown up and blurred, fading into the card: the "book colours" top half.
class _CoverGlow extends StatelessWidget {
  final String url;
  const _CoverGlow({required this.url});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: MediaQuery.sizeOf(context).height * 0.42,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isNotEmpty)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp),
                child: Transform.scale(
                  scale: 1.3,
                  child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [surface.withValues(alpha: 0.05), surface.withValues(alpha: 0.35), surface],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopButtons extends StatelessWidget {
  final ShelfBook? onShelf;
  final VoidCallback onBookmark;
  const _TopButtons({required this.onShelf, required this.onBookmark});

  @override
  Widget build(BuildContext context) {
    final onTbr = onShelf?.shelf == Shelf.tbr;
    final read = onShelf?.shelf == Shelf.read;
    return Row(
      children: [
        _GlassIcon(icon: Icons.arrow_back_ios_new, tooltip: 'Back', onTap: () => Navigator.of(context).pop()),
        const Spacer(),
        _GlassIcon(
          icon: read ? Icons.check : (onTbr ? Icons.bookmark : Icons.bookmark_border),
          // Phones have no hover, so this shows on a long-press (and on hover on web/desktop).
          tooltip: read ? 'Already read' : (onTbr ? 'Remove from TBR' : 'Add to TBR'),
          onTap: onBookmark,
        ),
      ],
    );
  }
}

class _GlassIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _GlassIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.white.withValues(alpha: 0.28),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 20, color: AppColors.charcoal)),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTiles extends StatelessWidget {
  final Book book;
  final int? ownRating;
  const _InfoTiles({required this.book, this.ownRating});

  static const _languages = {
    'en': 'English',
    'hi': 'Hindi',
    'fr': 'French',
    'es': 'Spanish',
    'de': 'German',
    'it': 'Italian',
    'ja': 'Japanese',
    'pt': 'Portuguese',
    'ta': 'Tamil',
    'mr': 'Marathi',
    'kn': 'Kannada',
  };

  @override
  Widget build(BuildContext context) {
    // Google Books often has no rating, so fall back to the user's own stars.
    final String rating;
    if (book.averageRating != null) {
      rating = '${book.averageRating!.toStringAsFixed(1)}/5';
    } else if (ownRating != null) {
      rating = '$ownRating/5 (you)';
    } else {
      rating = 'None yet';
    }
    final language = book.language.isEmpty ? '—' : (_languages[book.language] ?? book.language.toUpperCase());
    return Row(
      children: [
        _Tile(label: 'Rating', icon: Icons.star_rounded, iconColor: AppColors.sand, value: rating),
        const SizedBox(width: 10),
        _Tile(
          label: 'Pages',
          icon: Icons.menu_book_rounded,
          iconColor: AppColors.brown,
          value: book.pageCount > 0 ? '${book.pageCount}' : '—',
        ),
        const SizedBox(width: 10),
        _Tile(label: 'Language', icon: Icons.translate_rounded, iconColor: AppColors.green, value: language),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String value;
  const _Tile({required this.label, required this.icon, required this.iconColor, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Text(label, style: AppText.sans(size: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 14, weight: FontWeight.w600, color: scheme.onSurface),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Stars, note and series for books on your shelves; "Start reading" and
/// "Mark as read" for books on your TBR.
class _ShelfActions extends StatelessWidget {
  final ShelfBook entry;
  final Book book;
  final AppScope scope;
  final void Function(String, {VoidCallback? undo}) toast;

  const _ShelfActions({required this.entry, required this.book, required this.scope, required this.toast});

  @override
  Widget build(BuildContext context) {
    final shelf = scope.shelf;
    final scheme = Theme.of(context).colorScheme;
    final small = TextButton.styleFrom(
      foregroundColor: scheme.onSurface,
      textStyle: AppText.sans(size: 13, weight: FontWeight.w500),
      visualDensity: VisualDensity.compact,
    );
    final series = entry.seriesName == null
        ? 'Add to series'
        : '${entry.seriesName}${entry.seriesNumber != null ? ' #${_num(entry.seriesNumber!)}' : ''}';
    return Column(
      children: [
        if (entry.shelf == Shelf.read)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    (entry.rating ?? 0) >= star ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppColors.sand,
                    size: 30,
                  ),
                  onPressed: () => shelf.setRating(entry.bookId, entry.rating == star ? null : star),
                ),
            ],
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            if (entry.shelf == Shelf.tbr && !entry.reading)
              TextButton.icon(
                style: small,
                icon: const Icon(Icons.bookmark_added_outlined, size: 18),
                label: const Text('Start reading'),
                onPressed: () => shelf.setReading(entry.bookId, true),
              ),
            if (entry.shelf == Shelf.tbr)
              TextButton.icon(
                style: small,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Mark as read'),
                onPressed: () async {
                  await shelf.moveTo(entry.bookId, Shelf.read);
                  toast('Moved to Already read', undo: () => shelf.moveTo(entry.bookId, Shelf.tbr));
                },
              ),
            if (entry.shelf == Shelf.read)
              TextButton.icon(
                style: small,
                icon: const Icon(Icons.edit_note, size: 18),
                label: Text(entry.note == null ? 'Add a note' : 'Edit note'),
                onPressed: () => _editNote(context),
              ),
            TextButton.icon(
              style: small,
              icon: const Icon(Icons.collections_bookmark_outlined, size: 18),
              label: Text(series),
              onPressed: () => _editSeries(context),
            ),
          ],
        ),
        if (entry.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '"${entry.note}"',
              textAlign: TextAlign.center,
              style: AppText.hand(size: 20, color: scheme.onSurface),
            ),
          ),
      ],
    );
  }

  static String _num(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  Future<void> _editNote(BuildContext context) async {
    final controller = TextEditingController(text: entry.note);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your note'),
        content: TextField(controller: controller, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (saved != null) await scope.shelf.setNote(entry.bookId, saved);
  }

  Future<void> _editSeries(BuildContext context) async {
    final name = TextEditingController(text: entry.seriesName);
    final number = TextEditingController(text: entry.seriesNumber == null ? '' : _num(entry.seriesNumber!));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Series'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Series name'),
            ),
            TextField(
              controller: number,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Book number'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) await scope.shelf.setSeries(entry.bookId, name.text, double.tryParse(number.text));
  }
}

class _Synopsis extends StatelessWidget {
  final String text;
  final bool expanded;
  const _Synopsis({required this.text, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clean = text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final style = AppText.sans(size: 15, color: scheme.onSurfaceVariant).copyWith(height: 1.55);
    if (clean.isEmpty) return Text('No synopsis for this one yet.', style: style);
    if (expanded) return Text(clean, style: style);
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0, 0.6, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: Text(clean, maxLines: 5, overflow: TextOverflow.clip, style: style),
    );
  }
}

/// Shops and libraries that have the book. TBR has no online copies itself.
Future<void> _showWhereToBuy(BuildContext context, Book book) {
  final query = Uri.encodeComponent(book.isbn.isNotEmpty ? book.isbn : '${book.title} ${book.authorLine}');
  final shops = [
    // Change amazon.in to your country's Amazon if needed.
    ('Amazon', Icons.shopping_bag_outlined, 'https://www.amazon.in/s?k=$query'),
    ('Bookshop.org', Icons.storefront_outlined, 'https://bookshop.org/search?keywords=$query'),
    (
      'Google Play Books',
      Icons.tablet_mac_outlined,
      book.buyLink.isNotEmpty ? book.buyLink : 'https://play.google.com/store/search?q=$query&c=books',
    ),
    ('Find it in a library', Icons.local_library_outlined, 'https://search.worldcat.org/search?q=$query'),
  ];
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Where to buy', style: AppText.serif(size: 24)),
          ),
          for (final (name, icon, url) in shops)
            ListTile(
              leading: Icon(icon),
              title: Text(name),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
