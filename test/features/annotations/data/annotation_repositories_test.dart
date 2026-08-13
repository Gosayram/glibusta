import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/bookmarks/data/bookmark_repository.dart';
import 'package:glibusta/features/highlights/data/highlight_repository.dart';
import 'package:glibusta/features/notes/data/note_repository.dart';
import 'package:glibusta/features/quotes/data/quote_repository.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('creating bookmarks concurrently does not overwrite or reject entries', () async {
    final repository = BookmarkRepository(database);

    await Future.wait(
      List.generate(
        20,
        (index) => repository.createBookmark(
          bookId: 'book',
          chapterIndex: 0,
          paragraphIndex: index,
        ),
      ),
    );

    expect(await repository.getAllBookmarks('book'), hasLength(20));
  });

  test('creating notes, quotes, and highlights concurrently preserves every entry', () async {
    final noteRepository = NoteRepository(database);
    final quoteRepository = QuoteRepository(database);
    final highlightRepository = HighlightRepository(database);

    await Future.wait([
      ...List.generate(
        10,
        (index) => noteRepository.createNote(
          bookId: 'book',
          chapterIndex: 0,
          paragraphIndex: index,
          content: 'note $index',
        ),
      ),
      ...List.generate(
        10,
        (index) => quoteRepository.createQuote(
          bookId: 'book',
          chapterIndex: 0,
          paragraphIndex: index,
          selectedText: 'quote $index',
        ),
      ),
      ...List.generate(
        10,
        (index) => highlightRepository.saveHighlight(
          bookId: 'book',
          chapterId: 'chapter',
          chapterIndex: 0,
          blockIndex: index,
          startOffset: 0,
          endOffset: 1,
          selectedText: 'h',
          color: 'yellow',
        ),
      ),
    ]);

    expect(await noteRepository.getAllNotes('book'), hasLength(10));
    expect(await quoteRepository.getAllQuotes('book'), hasLength(10));
    expect(await highlightRepository.watchHighlightsForBook('book').first, hasLength(10));
  });
}
