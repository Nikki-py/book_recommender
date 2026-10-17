/// A book as returned by the backend (built from Google Books data).
class Book {
  final String id;
  final String title;
  final String subtitle;
  final List<String> authors;
  final String description;
  final List<String> categories;
  final int pageCount;
  final String publishedDate;
  final double? averageRating;
  final int ratingsCount;
  final String coverUrl;
  final String buyLink;
  final bool isSeries;
  final String language;
  final String isbn;

  /// Only set on recommendations: why the book was picked, and how closely it matched.
  final List<String> reasons;
  final double? score;

  const Book({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.authors = const [],
    this.description = '',
    this.categories = const [],
    this.pageCount = 0,
    this.publishedDate = '',
    this.averageRating,
    this.ratingsCount = 0,
    this.coverUrl = '',
    this.buyLink = '',
    this.isSeries = false,
    this.language = '',
    this.isbn = '',
    this.reasons = const [],
    this.score,
  });

  String get authorLine => authors.join(', ');

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      authors: _strings(json['authors']),
      description: json['description'] as String? ?? '',
      categories: _strings(json['categories']),
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
      publishedDate: json['publishedDate'] as String? ?? '',
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      ratingsCount: (json['ratingsCount'] as num?)?.toInt() ?? 0,
      coverUrl: json['coverUrl'] as String? ?? '',
      buyLink: json['buyLink'] as String? ?? '',
      isSeries: json['isSeries'] as bool? ?? false,
      language: json['language'] as String? ?? '',
      isbn: json['isbn'] as String? ?? '',
      reasons: _strings(json['reasons']),
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  static List<String> _strings(Object? value) => value is List ? value.map((e) => e.toString()).toList() : const [];
}
