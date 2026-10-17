import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/options.dart';
import '../models/book.dart';
import '../services/book_api.dart';
import '../theme/app_theme.dart';
import '../utils/series.dart';
import '../widgets/book_cover.dart';
import '../widgets/cover_placeholders.dart';

/// "Pick books you've loved": a grid of covers from the genres just chosen.
/// Picks go on the Already read shelf and become what TBR recommends from.
class PickBooksScreen extends StatefulWidget {
  final List<String> genres;
  const PickBooksScreen({super.key, required this.genres});

  @override
  State<PickBooksScreen> createState() => _PickBooksScreenState();
}

class _PickBooksScreenState extends State<PickBooksScreen> {
  final _search = TextEditingController();
  final Map<String, Book> _picked = {};
  List<Book> _suggested = [];
  List<Book>? _results;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _suggested.isEmpty && _error == null) _loadSuggestions();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final api = AppScope.of(context).api;
    final chosen = widget.genres.isEmpty ? ['Fiction'] : widget.genres.take(4).toList();
    try {
      final lists = await Future.wait(chosen.map((g) => api.popular(g, limit: 12)));
      // Mix the genres together instead of one block per genre.
      final seen = <String>{};
      final mixed = <Book>[];
      for (var i = 0; i < 12; i++) {
        for (final list in lists) {
          if (i < list.length && seen.add(list[i].id)) mixed.add(list[i]);
        }
      }
      if (mounted) setState(() => _suggested = mixed);
    } on BookApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final found = await AppScope.of(context).api.search(text);
        if (mounted && _search.text == text) setState(() => _results = found);
      } on BookApiException catch (e) {
        if (mounted) setState(() => _error = e.message);
      }
    });
  }

  void _toggle(Book book) => setState(() {
    if (_picked.remove(book.id) == null) _picked[book.id] = book;
  });

  Future<void> _done() async {
    setState(() => _saving = true);
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    final books = _picked.values.toList();
    if (books.isNotEmpty) await scope.shelf.addAllRead(books);
    await scope.profiles.finishOnboarding(lovedBookIds: books.map((b) => b.id).toList());
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final books = _results ?? _suggested;
    return Scaffold(
      appBar: AppBar(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text("Pick books you've loved", style: AppText.serif(size: 30, color: scheme.onSurface)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'TBR will recommend from these.',
              style: AppText.sans(size: 14, color: scheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Text(pickBooksQuote, style: AppText.hand(size: 20)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: SearchField(controller: _search, onChanged: _onSearch, hint: 'Search for a book you loved'),
          ),
          Expanded(
            child: _loading && _results == null
                ? const CoverPlaceholders(grid: true)
                : books.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error ?? 'Nothing found. Try another title.', textAlign: TextAlign.center),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.52,
                    ),
                    itemCount: books.length,
                    itemBuilder: (context, i) => _PickTile(
                      book: books[i],
                      picked: _picked.containsKey(books[i].id),
                      onTap: () => _toggle(books[i]),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Row(
                children: [
                  Text('${_picked.length} picked', style: AppText.sans(size: 15, weight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _done,
                      child: Text(_picked.isEmpty ? 'Skip for now' : 'Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final Book book;
  final bool picked;
  final VoidCallback onTap;
  const _PickTile({required this.book, required this.picked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            offset: picked ? const Offset(0, -0.03) : Offset.zero,
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, c) =>
                      BookCover(url: book.coverUrl, title: book.title, width: c.maxWidth, height: c.maxWidth * 1.5),
                ),
                if (picked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.green, width: 3),
                        color: AppColors.green.withValues(alpha: 0.25),
                      ),
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.all(6),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.green,
                        child: Icon(Icons.check, size: 16, color: AppColors.cream),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            shortTitle(book.title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.sans(size: 12, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// The rounded search box used here and on Explore.
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  const SearchField({super.key, required this.controller, required this.onChanged, required this.hint});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
      ),
    );
  }
}
