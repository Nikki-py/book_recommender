import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/book.dart';
import '../models/shelf_book.dart';
import '../models/user_profile.dart';
import '../services/book_api.dart';
import '../theme/app_theme.dart';
import '../utils/series.dart';
import '../widgets/book_cover.dart';
import '../widgets/cover_placeholders.dart';
import '../widgets/book_popup.dart';

/// Home: a summary of your reading, the book you're on, and picks for you.
class HomeScreen extends StatefulWidget {
  final VoidCallback onExplore;
  const HomeScreen({super.key, required this.onExplore});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Book>>? _recommended;
  String _recommendedFor = '';

  /// Says why these picks were chosen, shown under the heading.
  String _reason = '';

  /// With books read (or picked as loved), recommendations come from those,
  /// steered by the genres chosen on the slides. Before that, they're
  /// well-loved books from those genres, so the section is never empty.
  void _loadRecommendations(UserProfile profile, List<ShelfBook> shelf) {
    final read = shelf.where((b) => b.shelf == Shelf.read).toList();
    final rated = read.where((b) => (b.rating ?? 0) >= 4).map((b) => b.bookId);
    final seeds = {...profile.lovedBookIds, ...rated}.take(8).toList();
    final ids = seeds.isEmpty ? read.map((b) => b.bookId).take(5).toList() : seeds;
    final key = '${ids.join(',')}|${profile.genres.join(',')}|${profile.vibes.join(',')}';
    if (key == _recommendedFor && _recommended != null) return;
    _recommendedFor = key;

    final api = AppScope.of(context).api;
    final onShelf = shelf.map((b) => b.bookId).toSet();
    final random = Random();
    final genres = [...profile.genres]..shuffle(random);

    Future<List<Book>> fromGenres() async {
      final picked = genres.isEmpty ? ['Fiction'] : genres.take(3).toList();
      final lists = await Future.wait(picked.map((g) => api.popular(g, limit: 12).catchError((_) => <Book>[])));
      // Take turns from each genre so the row is a mix, skipping duplicates.
      final mixed = <Book>[];
      final seen = <String>{...onShelf};
      for (var i = 0; i < 12; i++) {
        for (final list in lists) {
          if (i < list.length && seen.add(list[i].id)) mixed.add(list[i]);
        }
      }
      if (mixed.isEmpty && lists.every((l) => l.isEmpty)) {
        // Every genre failed: show the server's own message.
        await api.popular(picked.first, limit: 1);
      }
      return mixed.take(15).toList();
    }

    if (ids.isEmpty) {
      _reason = genres.isEmpty ? 'Popular with readers' : 'Because you like ${_listOf(genres.take(3).toList())}';
      _recommended = fromGenres();
      return;
    }

    final seedTitles = [
      for (final b in shelf)
        if (ids.contains(b.bookId)) shortTitle(b.title),
    ];
    _reason = seedTitles.isEmpty
        ? 'Based on books you love'
        : 'Because you read ${seedTitles[random.nextInt(seedTitles.length)]}';
    Future<List<Book>> fromBooks() async {
      try {
        final books = await api.recommend(
          bookIds: ids,
          mood: profile.vibes.isEmpty ? null : profile.vibes[random.nextInt(profile.vibes.length)],
          genre: genres.isEmpty ? null : genres.first,
          excludeIds: onShelf.toList(),
          limit: 12,
        );
        if (books.isNotEmpty) return books;
      } on BookApiException {
        // Fall back to the chosen genres below.
      }
      return fromGenres();
    }

    _recommended = fromBooks();
  }

  static String _listOf(List<String> items) =>
      items.length < 2 ? items.join() : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<ShelfBook>>(
      stream: scope.shelf.watchShelf(),
      builder: (context, snap) {
        final shelf = snap.data ?? const <ShelfBook>[];
        if (snap.hasData) _loadRecommendations(scope.profile, shelf);
        final reading = shelf.where((b) => b.reading).toList();
        final tbr = shelf.where((b) => b.shelf == Shelf.tbr && !b.reading).toList();
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _recommendedFor = '');
            await _recommended;
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, MediaQuery.paddingOf(context).top + 20, 0, 120),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _dateLine().toUpperCase(),
                  style: AppText.sans(size: 12, color: scheme.onSurfaceVariant).copyWith(letterSpacing: 2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                child: Text.rich(
                  TextSpan(
                    style: AppText.serif(size: 34, color: scheme.onSurface),
                    children: [
                      const TextSpan(text: 'Hello, '),
                      TextSpan(
                        text: scope.profile.displayName.isEmpty ? 'reader' : scope.profile.displayName,
                        style: TextStyle(
                          color: scheme.brightness == Brightness.dark ? AppColors.sand : AppColors.brown,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SummaryCard(shelf: shelf, profile: scope.profile),
              ),
              const SizedBox(height: 26),
              _SectionTitle(reading.isEmpty ? 'Pick your next read' : 'Currently reading'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: reading.isNotEmpty
                    ? Column(children: [for (final b in reading) _ReadingCard(book: b)])
                    : tbr.isNotEmpty
                    ? _ReadingCard(book: tbr.first, suggestion: true)
                    : _EmptyCard(
                        text: 'Your TBR is empty. Find something on Explore.',
                        action: 'Explore',
                        onTap: widget.onExplore,
                      ),
              ),
              const SizedBox(height: 26),
              const _SectionTitle('Recommended for you', tight: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(_reason, style: AppText.sans(size: 13, color: scheme.onSurfaceVariant)),
              ),
              SizedBox(
                height: 210,
                child: FutureBuilder<List<Book>>(
                  future: _recommended,
                  builder: (context, rec) {
                    if (rec.connectionState == ConnectionState.waiting) return const CoverPlaceholders();
                    if (rec.hasError) {
                      final message = rec.error is BookApiException
                          ? (rec.error as BookApiException).message
                          : "Couldn't load recommendations.";
                      return Center(
                        child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
                      );
                    }
                    final books = rec.data ?? const <Book>[];
                    if (books.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _EmptyCard(
                          text: 'No picks right now. Find something on Explore.',
                          action: 'Explore',
                          onTap: widget.onExplore,
                        ),
                      );
                    }
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: books.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, i) => _CoverWithTitle(book: books[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _dateLine() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  /// Less space below, for a heading with a line of text under it.
  final bool tight;
  const _SectionTitle(this.text, {this.tight = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(24, 0, 24, tight ? 2 : 12),
    child: Text(text, style: AppText.serif(size: 22, color: Theme.of(context).colorScheme.onSurface)),
  );
}

/// Books read this year against the goal, pages read, and the TBR count.
class _SummaryCard extends StatelessWidget {
  final List<ShelfBook> shelf;
  final UserProfile profile;
  const _SummaryCard({required this.shelf, required this.profile});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final thisYear = shelf.where((b) => b.readAt?.year == year).toList();
    final pages = thisYear.fold<int>(0, (sum, b) => sum + b.pageCount);
    final tbr = shelf.where((b) => b.shelf == Shelf.tbr).length;
    final goal = profile.yearlyGoal;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: goal == null || goal == 0 ? 0 : (thisYear.length / goal).clamp(0.0, 1.0),
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: AppColors.sand,
                  backgroundColor: AppColors.cream.withValues(alpha: 0.15),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${thisYear.length}', style: AppText.serif(size: 28, color: AppColors.cream)),
                      Text(
                        goal == null ? 'read' : 'of $goal',
                        style: AppText.sans(size: 11, color: AppColors.cream.withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your $year', style: AppText.serif(size: 20, color: AppColors.cream)),
                const SizedBox(height: 8),
                _stat(Icons.menu_book_rounded, '$pages pages read'),
                _stat(Icons.bookmark_rounded, '$tbr on your TBR'),
                if (goal == null)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.sand,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => askYearlyGoal(context),
                    child: const Text('Set a reading goal →'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.sand),
        const SizedBox(width: 8),
        Text(text, style: AppText.sans(size: 14, color: AppColors.cream)),
      ],
    ),
  );
}

/// Asks for this year's goal; used on Home and in Profile.
Future<void> askYearlyGoal(BuildContext context) async {
  final scope = AppScope.of(context);
  final controller = TextEditingController(text: scope.profile.yearlyGoal?.toString() ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Books to read this year'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. 24'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
      ],
    ),
  );
  if (result == null) return;
  final goal = int.tryParse(result.trim());
  await scope.profiles.setYearlyGoal(goal != null && goal > 0 ? goal : null);
}

class _ReadingCard extends StatelessWidget {
  final ShelfBook book;
  final bool suggestion;
  const _ReadingCard({required this.book, this.suggestion = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => showBookPopup(context, book.toBook()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            BookCover(url: book.coverUrl, title: book.title, width: 64, height: 96, radius: 6),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (suggestion)
                    Text(
                      'Next up on your TBR',
                      style: AppText.sans(size: 12, color: AppColors.green, weight: FontWeight.w600),
                    ),
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.serif(size: 19, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(book.authorLine, style: AppText.sans(size: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;
  const _EmptyCard({required this.text, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: AppText.sans(size: 14, color: scheme.onSurfaceVariant)),
          ),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _CoverWithTitle extends StatelessWidget {
  final Book book;
  const _CoverWithTitle({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showBookPopup(context, book),
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(url: book.coverUrl, title: book.title, width: 104, height: 156),
            const SizedBox(height: 8),
            Text(
              shortTitle(book.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 12, weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
