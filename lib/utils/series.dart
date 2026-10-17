/// Works out which series a book belongs to from its title.
///
/// Google Books rarely names the series, but titles often carry it, especially
/// ones imported from Goodreads: "Heir of Fire (Throne of Glass, #3)".
/// Returns null when the title gives no series.
({String name, double number})? seriesFromTitle(String title) {
  // "Title (Series Name, #3)" or "Title (Series Name #3)"
  final paren = RegExp(r'\(([^()#]+?),?\s*#\s*(\d+(?:\.\d+)?)\)').firstMatch(title);
  if (paren != null) {
    return (name: paren.group(1)!.trim(), number: double.parse(paren.group(2)!));
  }
  // "Series Name, Book 3" / "Series Name Book 3: Title"
  final book = RegExp(r'^(.+?),?\s+(?:Book|Vol\.?|Volume)\s+(\d+)', caseSensitive: false).firstMatch(title);
  if (book != null) {
    return (name: book.group(1)!.trim(), number: double.parse(book.group(2)!));
  }
  return null;
}

/// The title without its series part, for spines where space is tight.
String shortTitle(String title) => title.replaceAll(RegExp(r'\s*\([^()]*#\s*\d+[^()]*\)'), '').trim();
