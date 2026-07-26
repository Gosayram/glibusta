import 'package:shared_preferences/shared_preferences.dart';

/// A bounded, device-local list of terms explicitly looked up in the reader.
///
/// This store is intentionally separate from account and sync data: entries
/// are recorded only after the user taps the dictionary action and are never
/// sent anywhere by this class.
class DictionaryLookupHistory {
  const DictionaryLookupHistory(this._preferences);

  static const maxEntries = 50;
  static const _key = 'reader_dictionary_lookup_history';
  static const _maxQueryRunes = 120;

  final SharedPreferences _preferences;

  static Future<DictionaryLookupHistory> open() async {
    return DictionaryLookupHistory(await SharedPreferences.getInstance());
  }

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

  /// Removes one term without affecting the rest of the local history.
  Future<void> remove(String query) async {
    final normalized = normalize(query);
    if (normalized == null) return;

    final key = normalized.toLowerCase();
    await _preferences.setStringList(
      _key,
      entries().where((entry) => entry.toLowerCase() != key).toList(growable: false),
    );
  }

  /// Deletes every locally stored lookup term.
  Future<void> clear() => _preferences.remove(_key);

  static String? normalize(String query) {
    final compact = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) return null;
    return String.fromCharCodes(compact.runes.take(_maxQueryRunes));
  }
}
