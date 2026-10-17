import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/book.dart';
import '../models/shelf_book.dart';

/// The signed-in user's two shelves (Already read and TBR), stored in Firestore at users/{uid}/shelf.
///
/// Firestore keeps a copy on the phone, so the shelf still loads offline and
/// changes sync when the connection comes back.
class ShelfService {
  final String uid;
  final FirebaseFirestore _db;

  ShelfService(this.uid, {FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _shelf => _db.collection('users').doc(uid).collection('shelf');

  /// The shelf in the order the user arranged it.
  Stream<List<ShelfBook>> watchShelf() {
    return _shelf.orderBy('position').snapshots().map((snap) => snap.docs.map(ShelfBook.fromFirestore).toList());
  }

  /// IDs of every book on the shelf, so recommendations can skip them.
  Future<List<String>> shelfIds() async {
    final snap = await _shelf.get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Adds a book to the end of [shelf], or moves it there if it's already on the other one.
  Future<void> add(Book book, {Shelf shelf = Shelf.read, int? rating}) async {
    final existing = await _shelf.doc(book.id).get();
    if (existing.exists) {
      await moveTo(book.id, shelf);
      return;
    }
    final last = await _shelf.orderBy('position', descending: true).limit(1).get();
    final next = last.docs.isEmpty ? 0 : ((last.docs.first.data()['position'] as num?)?.toInt() ?? 0) + 1;
    final entry = ShelfBook.fromBook(book, position: next, shelf: shelf);
    await _shelf.doc(book.id).set({
      ...entry.toFirestore(),
      'rating': rating,
      if (shelf == Shelf.read) 'finishedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adds several books to the read shelf at once (used after "Pick books you've loved").
  Future<void> addAllRead(List<Book> books) async {
    final last = await _shelf.orderBy('position', descending: true).limit(1).get();
    var next = last.docs.isEmpty ? 0 : ((last.docs.first.data()['position'] as num?)?.toInt() ?? 0) + 1;
    final batch = _db.batch();
    for (final book in books) {
      final entry = ShelfBook.fromBook(book, position: next++);
      batch.set(_shelf.doc(book.id), entry.toFirestore(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Moves a book between Already read and TBR. Finishing a book stops "reading".
  Future<void> moveTo(String bookId, Shelf shelf) {
    return _shelf.doc(bookId).update({
      'shelf': shelf.name,
      'reading': false,
      'finishedAt': shelf == Shelf.read ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<void> setReading(String bookId, bool reading) =>
      _shelf.doc(bookId).update({'reading': reading, if (reading) 'shelf': Shelf.tbr.name});

  /// Puts a book in a series by hand, for when the title doesn't say.
  Future<void> setSeries(String bookId, String? name, double? number) {
    final trimmed = name?.trim();
    final empty = trimmed == null || trimmed.isEmpty;
    return _shelf.doc(bookId).update({'seriesName': empty ? null : trimmed, 'seriesNumber': empty ? null : number});
  }

  Stream<ShelfBook?> watchBook(String bookId) =>
      _shelf.doc(bookId).snapshots().map((doc) => doc.exists ? ShelfBook.fromFirestore(doc) : null);

  Future<void> remove(String bookId) => _shelf.doc(bookId).delete();

  /// [rating] is 1-5, or null to clear it.
  Future<void> setRating(String bookId, int? rating) {
    assert(rating == null || (rating >= 1 && rating <= 5));
    return _shelf.doc(bookId).update({'rating': rating});
  }

  /// An empty note is stored as null, so the note field stays blank.
  Future<void> setNote(String bookId, String? note) {
    final trimmed = note?.trim();
    return _shelf.doc(bookId).update({'note': (trimmed == null || trimmed.isEmpty) ? null : trimmed});
  }

  /// Saves a new order after the user drags books around.
  /// [orderedIds] is every book on the shelf, in its new order.
  Future<void> reorder(List<String> orderedIds) {
    final batch = _db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_shelf.doc(orderedIds[i]), {'position': i});
    }
    return batch.commit();
  }

  /// Saves a new order for some of the books (one shelf), reusing the
  /// position numbers they already had so the other shelf isn't disturbed.
  Future<void> reorderSome(List<ShelfBook> current, List<String> newOrder) {
    final slots = current.map((b) => b.position).toList()..sort();
    final batch = _db.batch();
    for (var i = 0; i < newOrder.length && i < slots.length; i++) {
      batch.update(_shelf.doc(newOrder[i]), {'position': slots[i]});
    }
    return batch.commit();
  }

  /// Deletes every shelf entry (used when deleting the account).
  Future<void> clear() async {
    final snap = await _shelf.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
