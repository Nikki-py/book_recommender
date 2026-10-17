import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/book.dart';

class BookApiException implements Exception {
  final String message;
  const BookApiException(this.message);

  @override
  String toString() => message;
}

/// Filters the user can set on recommendations.
enum BookLength { short, medium, long }

enum SeriesFilter { standalone, series }

/// Moods the backend understands (keys of MOODS in backend/main.py).
const moods = ['cozy', 'dark', 'fast-paced', 'emotional', 'funny', 'romantic', 'adventurous', 'mysterious'];

/// Talks to the Python backend. The app never calls Google Books directly,
/// so no API keys live in the app.
class BookApi {
  final http.Client _client;
  final String baseUrl;

  BookApi({http.Client? client, String? baseUrl}) : baseUrl = baseUrl ?? apiBaseUrl, _client = client ?? http.Client();

  /// Autocomplete results for what the user has typed so far.
  Future<List<Book>> search(String query) async {
    if (query.trim().length < 2) return [];
    final json = await _get('/search', {'q': query.trim()});
    return _books(json);
  }

  Future<Book> book(String id) async {
    final json = await _get('/book/${Uri.encodeComponent(id)}');
    return Book.fromJson(json as Map<String, dynamic>);
  }

  /// Other books by [author] (includes other books in the same series).
  Future<List<Book>> moreByAuthor(String author, {String excludeTitle = ''}) async {
    final json = await _get('/author', {'name': author, 'exclude': excludeTitle});
    return _books(json);
  }

  /// Well-loved books in a genre, for Explore and "Pick books you've loved".
  Future<List<Book>> popular(String genre, {int limit = 20}) async {
    final json = await _get('/popular', {'genre': genre, 'limit': '$limit'});
    return _books(json);
  }

  /// Recommendations based on one or more books the user liked.
  Future<List<Book>> recommend({
    required List<String> bookIds,
    String? mood,
    String? genre,
    BookLength? length,
    SeriesFilter? series,
    List<String> excludeIds = const [],
    int limit = 10,
  }) async {
    final json = await _post('/recommend', {
      'book_ids': bookIds,
      'mood': mood,
      'genre': genre,
      'length': length?.name,
      'series': series?.name,
      'exclude_ids': excludeIds,
      'limit': limit,
    });
    return _books(json);
  }

  /// Answers already fetched this session, so going back to a page is instant.
  final _cache = <Uri, Object?>{};

  Future<Object?> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    if (_cache.containsKey(uri)) return _cache[uri];
    final body = await _send(() => _client.get(uri), const Duration(seconds: 12));
    _cache[uri] = body;
    return body;
  }

  Future<Object?> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    // Recommendations search many books on the server, so allow them longer.
    return _send(
      () => _client.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)),
      const Duration(seconds: 25),
    );
  }

  Future<Object?> _send(Future<http.Response> Function() request, Duration timeout) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } catch (_) {
      throw const BookApiException("Couldn't reach the book server. Check your connection.");
    }
    final body = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      final detail = body is Map ? body['detail'] : null;
      throw BookApiException(detail is String ? detail : 'Something went wrong (${response.statusCode}).');
    }
    return body;
  }

  List<Book> _books(Object? json) =>
      json is List ? json.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList() : [];
}
