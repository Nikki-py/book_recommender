import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/options.dart';
import '../models/book.dart';
import '../services/book_api.dart';
import '../theme/app_theme.dart';
import '../utils/series.dart';
import '../widgets/book_cover.dart';
import '../widgets/book_popup.dart';
import '../widgets/cover_placeholders.dart';
import '../widgets/pill.dart';
import 'pick_books_screen.dart' show SearchField;

/// Explore: search, then "Explore by categories" with the genres picked on
/// the personalise slides.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Book>? _results;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() {
        _results = null;
        _error = null;
      });
      return;
    }
    final api = AppScope.of(context).api;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      try {
        final found = await api.search(text);
        if (mounted && _search.text == text) setState(() => _results = found);
      } on BookApiException catch (e) {
        if (mounted) setState(() => _error = e.message);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _openGenre(String genre) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => GenreScreen(genre: genre)));

  void _showAllGenres() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < genres.length; i++)
              Pill(
                label: genres[i],
                color: AppColors.spines[i % AppColors.spines.length],
                onTap: () {
                  Navigator.pop(context);
                  _openGenre(genres[i]);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final picked = AppScope.of(context).profile.genres;
    final chips = picked.isEmpty ? genres.take(6).toList() : picked;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 24, 20, 120),
      children: [
        Text('Explore', style: AppText.serif(size: 34, color: scheme.onSurface)),
        const SizedBox(height: 16),
        SearchField(controller: _search, onChanged: _onSearch, hint: 'Search titles or authors'),
        const SizedBox(height: 20),
        if (_results != null || _searching || _error != null) ...[
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) Text(_error!, style: TextStyle(color: scheme.error)),
          if (_results != null && _results!.isEmpty && !_searching) const Text('No books found. Try other words.'),
          for (final book in _results ?? const <Book>[]) _ResultRow(book: book),
        ] else ...[
          Text('Explore by categories', style: AppText.serif(size: 22, color: scheme.onSurface)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < chips.length; i++)
                Pill(
                  label: chips[i],
                  color: AppColors.spines[i % AppColors.spines.length],
                  onTap: () => _openGenre(chips[i]),
                ),
              Pill(label: '+ More', onTap: _showAllGenres),
            ],
          ),
        ],
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final Book book;
  const _ResultRow({required this.book});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showBookPopup(context, book),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            BookCover(url: book.coverUrl, title: book.title, width: 48, height: 72, radius: 5),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.serif(size: 17, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(book.authorLine, style: AppText.sans(size: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Books in one genre, with the agreed filters: length and standalone/series.
class GenreScreen extends StatefulWidget {
  final String genre;
  const GenreScreen({super.key, required this.genre});

  @override
  State<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends State<GenreScreen> {
  Future<List<Book>>? _books;
  BookLength? _length;
  SeriesFilter? _series;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _books ??= AppScope.of(context).api.popular(widget.genre, limit: 30);
  }

  bool _passes(Book b) {
    if (_length != null && b.pageCount > 0) {
      final ok = switch (_length!) {
        BookLength.short => b.pageCount < 250,
        BookLength.medium => b.pageCount >= 250 && b.pageCount < 450,
        BookLength.long => b.pageCount >= 450,
      };
      if (!ok) return false;
    }
    if (_series == SeriesFilter.standalone && b.isSeries) return false;
    if (_series == SeriesFilter.series && !b.isSeries) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget filter(String label, bool on, VoidCallback tap) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pill(label: label, selected: on, onTap: tap),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.genre, style: AppText.serif(size: 24, color: scheme.onSurface)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final l in BookLength.values)
                  filter(
                    '${l.name[0].toUpperCase()}${l.name.substring(1)}',
                    _length == l,
                    () => setState(() => _length = _length == l ? null : l),
                  ),
                filter(
                  'Standalone',
                  _series == SeriesFilter.standalone,
                  () => setState(() => _series = _series == SeriesFilter.standalone ? null : SeriesFilter.standalone),
                ),
                filter(
                  'Series',
                  _series == SeriesFilter.series,
                  () => setState(() => _series = _series == SeriesFilter.series ? null : SeriesFilter.series),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Book>>(
              future: _books,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const CoverPlaceholders(grid: true);
                if (snap.hasError) {
                  final e = snap.error;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e is BookApiException ? e.message : "Couldn't load books.", textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () =>
                                setState(() => _books = AppScope.of(context).api.popular(widget.genre, limit: 30)),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final books = (snap.data ?? const <Book>[]).where(_passes).toList();
                if (books.isEmpty) return const Center(child: Text('No books match those filters.'));
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.5,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => showBookPopup(context, books[i]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, c) => BookCover(
                            url: books[i].coverUrl,
                            title: books[i].title,
                            width: c.maxWidth,
                            height: c.maxWidth * 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          shortTitle(books[i].title),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sans(size: 12, weight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
