import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class QuoteRepository {
  final AppDatabase _db;

  QuoteRepository(this._db);

  Future<List<Quote>> getAllQuotes(String bookId) async {
    return (_db.select(_db.quotes)
          ..where((q) => q.bookId.equals(bookId))
          ..orderBy([(q) => OrderingTerm.desc(q.createdAt)]))
        .get();
  }

  Future<Quote?> getQuote(String id) async {
    return (_db.select(_db.quotes)..where((q) => q.id.equals(id))).getSingleOrNull();
  }

  Future<int> createQuote({
    required String bookId,
    required int chapterIndex,
    required int paragraphIndex,
    required String selectedText,
    String? beforeContext,
    String? afterContext,
    String? note,
  }) async {
    return _db
        .into(_db.quotes)
        .insert(
          QuotesCompanion.insert(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            bookId: bookId,
            chapterIndex: chapterIndex,
            paragraphIndex: paragraphIndex,
            selectedText: selectedText,
            beforeContext: Value(beforeContext),
            afterContext: Value(afterContext),
            note: Value(note),
          ),
        );
  }

  Future<bool> updateQuote({
    required String id,
    String? note,
  }) async {
    final count = await (_db.update(_db.quotes)..where((q) => q.id.equals(id))).write(
      QuotesCompanion(note: note != null ? Value(note) : const Value.absent()),
    );
    return count > 0;
  }

  Future<int> deleteQuote(String id) async {
    return (_db.delete(_db.quotes)..where((q) => q.id.equals(id))).go();
  }

  Future<void> insertQuote(Quote quote) async {
    await _db
        .into(_db.quotes)
        .insert(
          QuotesCompanion.insert(
            id: quote.id,
            bookId: quote.bookId,
            chapterIndex: quote.chapterIndex,
            paragraphIndex: quote.paragraphIndex,
            selectedText: quote.selectedText,
            note: Value(quote.note),
          ),
        );
  }

  Stream<List<Quote>> watchQuotes(String bookId) {
    return (_db.select(_db.quotes)
          ..where((q) => q.bookId.equals(bookId))
          ..orderBy([(q) => OrderingTerm.desc(q.createdAt)]))
        .watch();
  }
}
