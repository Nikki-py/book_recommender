import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/series.dart';
import 'book.dart';

/// Which shelf a book sits on.
enum Shelf { read, tbr }

/// A book on one of the user's shelves, stored at users/{uid}/shelf/{bookId}.
class ShelfBook {
  final String bookId;
  final String title;
  final List<String> authors;
  final String coverUrl;
  final int pageCount;
  final List<String> categories;

  final Shelf shelf;

  /// Being read right now. These sit at the front of the TBR shelf with a bookmark.
  final bool reading;

  /// Set when the title names a series, or when the user adds it to one by hand.
  final String? seriesName;
  final double? seriesNumber;

  /// 1 to 5 stars, or null if not rated yet.
  final int? rating;

  /// Optional; stays null unless the user writes one.
  final String? note;

  /// Where the book sits on the shelf (0 = first). The user can rearrange these.
  final int position;
  final DateTime? addedAt;
  final DateTime? finishedAt;

  const ShelfBook({
    required this.bookId,
    required this.title,
    this.authors = const [],
    this.coverUrl = '',
    this.pageCount = 0,
    this.categories = const [],
    this.shelf = Shelf.read,
    this.reading = false,
    this.seriesName,
    this.seriesNumber,
    this.rating,
    this.note,
    this.position = 0,
    this.addedAt,
    this.finishedAt,
  });

  String get authorLine => authors.join(', ');

  /// When it was finished, for this year's goal and stats. Books picked as
  /// "loved" during setup were read before, so they have no date and don't count.
  DateTime? get readAt => shelf == Shelf.read ? finishedAt : null;

  factory ShelfBook.fromBook(Book book, {required int position, Shelf shelf = Shelf.read}) {
    final series = seriesFromTitle(book.title);
    return ShelfBook(
      bookId: book.id,
      title: book.title,
      authors: book.authors,
      coverUrl: book.coverUrl,
      pageCount: book.pageCount,
      categories: book.categories,
      shelf: shelf,
      seriesName: series?.name,
      seriesNumber: series?.number,
      position: position,
    );
  }

  /// Enough of a Book to open the book pop-up from a shelf.
  Book toBook() => Book(
    id: bookId,
    title: title,
    authors: authors,
    coverUrl: coverUrl,
    pageCount: pageCount,
    categories: categories,
  );

  factory ShelfBook.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ShelfBook(
      bookId: doc.id,
      title: data['title'] as String? ?? '',
      authors: List<String>.from(data['authors'] as List? ?? const []),
      coverUrl: data['coverUrl'] as String? ?? '',
      pageCount: (data['pageCount'] as num?)?.toInt() ?? 0,
      categories: List<String>.from(data['categories'] as List? ?? const []),
      shelf: data['shelf'] == 'tbr' ? Shelf.tbr : Shelf.read,
      reading: data['reading'] as bool? ?? false,
      seriesName: data['seriesName'] as String?,
      seriesNumber: (data['seriesNumber'] as num?)?.toDouble(),
      rating: (data['rating'] as num?)?.toInt(),
      note: data['note'] as String?,
      position: (data['position'] as num?)?.toInt() ?? 0,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
      finishedAt: (data['finishedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'authors': authors,
      'coverUrl': coverUrl,
      'pageCount': pageCount,
      'categories': categories,
      'shelf': shelf.name,
      'reading': reading,
      'seriesName': seriesName,
      'seriesNumber': seriesNumber,
      'rating': rating,
      'note': note,
      'position': position,
      'addedAt': addedAt != null ? Timestamp.fromDate(addedAt!) : FieldValue.serverTimestamp(),
      if (finishedAt != null) 'finishedAt': Timestamp.fromDate(finishedAt!),
    };
  }
}
