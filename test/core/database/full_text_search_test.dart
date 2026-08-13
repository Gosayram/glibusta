import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/core/database/full_text_search.dart';

void main() {
  late AppDatabase database;
  late FullTextSearchService search;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    search = FullTextSearchService(database);
  });

  tearDown(() => database.close());

  test('treats FTS syntax characters in a user query as literal text', () async {
    await search.indexBook(
      bookId: 'book-1',
      chapters: const [
        BookChapterContent(
          chapterIndex: 0,
          title: 'Guide',
          content: 'C++ guide for readers',
        ),
      ],
    );

    final results = await search.search('C++');

    expect(results, hasLength(1));
    expect(results.single.bookId, 'book-1');
  });
}
