import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reader_search_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('keeps a bounded, case-insensitive history per book', () async {
    final firstBook = ReaderSearchHistory(preferences, 'first book');
    final secondBook = ReaderSearchHistory(preferences, 'second book');

    await firstBook.record('  First\nquery ');
    await firstBook.record('second query');
    await firstBook.record('FIRST QUERY');
    await secondBook.record('private query');

    expect(firstBook.entries(), ['FIRST QUERY', 'second query']);
    expect(secondBook.entries(), ['private query']);

    for (var index = 0; index < ReaderSearchHistory.maxEntries + 3; index++) {
      await firstBook.record('term $index');
    }

    expect(firstBook.entries(), hasLength(ReaderSearchHistory.maxEntries));
    expect(firstBook.entries().first, 'term ${ReaderSearchHistory.maxEntries + 2}');
  });

  test('removes one query or clears only its book history', () async {
    final firstBook = ReaderSearchHistory(preferences, 'book one');
    final secondBook = ReaderSearchHistory(preferences, 'book two');
    await firstBook.record('first');
    await firstBook.record('second');
    await secondBook.record('kept');

    await firstBook.remove('FIRST');
    expect(firstBook.entries(), ['second']);

    await firstBook.clear();
    expect(firstBook.entries(), isEmpty);
    expect(secondBook.entries(), ['kept']);
  });
}
