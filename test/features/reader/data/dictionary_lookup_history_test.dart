import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/dictionary_lookup_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;
  late DictionaryLookupHistory history;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    history = DictionaryLookupHistory(preferences);
  });

  test('keeps newest explicit lookups first and deduplicates them', () async {
    await history.record('  First\nterm  ');
    await history.record('Second term');
    await history.record('first term');

    expect(history.entries(), ['first term', 'Second term']);
  });

  test('keeps at most fifty local entries', () async {
    for (var index = 0; index < DictionaryLookupHistory.maxEntries + 4; index++) {
      await history.record('term $index');
    }

    final entries = history.entries();
    expect(entries, hasLength(DictionaryLookupHistory.maxEntries));
    expect(entries.first, 'term 53');
    expect(entries.last, 'term 4');
  });

  test('removes one history entry or clears all entries', () async {
    await history.record('first');
    await history.record('second');

    await history.remove('FIRST');
    expect(history.entries(), ['second']);

    await history.clear();
    expect(history.entries(), isEmpty);
  });

  test('normalizes blank and oversized selections before storage', () async {
    await history.record('   ');
    await history.record('a' * 200);

    expect(history.entries(), hasLength(1));
    expect(history.entries().single.runes, hasLength(120));
  });
}
