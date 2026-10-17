// Named widget_test.dart so `flutter create .` keeps this file instead of adding its sample test.
import 'package:book_recommender/models/book.dart';
import 'package:book_recommender/utils/series.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Book.fromJson reads backend fields and tolerates missing ones', () {
    final book = Book.fromJson({
      'id': 'L4q6zwEACAAJ',
      'title': 'The Lost Bookshop',
      'authors': ['Evie Woods'],
      'pageCount': 448,
      'averageRating': 4,
      'reasons': ['Same author'],
      'score': 0.25,
    });

    expect(book.title, 'The Lost Bookshop');
    expect(book.authorLine, 'Evie Woods');
    expect(book.pageCount, 448);
    expect(book.averageRating, 4.0);
    expect(book.reasons, ['Same author']);
    expect(book.categories, isEmpty);
    expect(book.coverUrl, '');
  });

  test('Series are read from titles', () {
    expect(seriesFromTitle('Heir of Fire (Throne of Glass, #3)'), (name: 'Throne of Glass', number: 3.0));
    expect(seriesFromTitle('Shadow and Bone (The Shadow and Bone Trilogy #1)')?.number, 1.0);
    expect(seriesFromTitle('Harry Potter, Book 2')?.name, 'Harry Potter');
    expect(seriesFromTitle('Circe'), isNull);
    expect(shortTitle('Heir of Fire (Throne of Glass, #3)'), 'Heir of Fire');
  });
}
