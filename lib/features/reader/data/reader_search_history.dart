import 'package:shared_preferences/shared_preferences.dart';

/// A bounded, device-local history of explicit in-book search queries.
///
/// Entries are scoped to a book and are never sent to an account, network, or
/// sync service. Queries are recorded only after an explicit submit or result
/// selection; typing into the search field alone does not persist anything.
class ReaderSearchHistory {
  const ReaderSearchHistory(this._preferences, this._bookId);

  static const maxEntries = 12;
  static const _keyPrefix = 'reader_search_history/';
  static const _maxQueryRunes = 120;

  final SharedPreferences _preferences;
  final String _bookId;

  static Future<ReaderSearchHistory> open(String bookId) async {
    return ReaderSearchHistory(await SharedPreferences.getInstance(), bookId);
  }

  String get _key => '$_keyPrefix${Uri.encodeComponent(_bookId)}';

  /// Returns newest entries first.
  List<String> entries() {
    final stored = _preferences.getStringList(_key) ?? const <String>[];
    final seen = <String>{};
    final result = <String>[];

    for (final value in stored) {
      final query = normalize(value);
      if (query == null || !seen.add(query.toLowerCase())) continue;
      result.add(query);
      if (result.length == maxEntries) break;
    }

    return List.unmodifiable(result);
  }

  /// Adds [query] to the front, replacing an existing case-insensitive match.
  Future<void> record(String query) async {
    final normalized = normalize(query);
    if (normalized == null) return;

    final key = normalized.toLowerCase();
    final updated = <String>[
      normalized,
      ...entries().where((entry) => entry.toLowerCase() != key),
    ].take(maxEntries).toList(growable: false);
    await _preferences.setStringList(_key, updated);
  }

  /// Removes one query without affecting the remaining local history.
  Future<void> remove(String query) async {
    final normalized = normalize(query);
    if (normalized == null) return;

    final key = normalized.toLowerCase();
    await _preferences.setStringList(
      _key,
      entries().where((entry) => entry.toLowerCase() != key).toList(growable: false),
    );
  }

  /// Deletes every locally stored query for this book.
  Future<void> clear() => _preferences.remove(_key);

  static String? normalize(String query) {
    final compact = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) return null;
    return String.fromCharCodes(compact.runes.take(_maxQueryRunes));
  }
}
