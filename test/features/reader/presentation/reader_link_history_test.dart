import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_link_history.dart';

void main() {
  ReaderPosition position(int chapterIndex) => ReaderPosition(
    bookId: 'book-1',
    chapterIndex: chapterIndex,
    paragraphIndex: chapterIndex,
    updatedAt: DateTime(2026),
  );

  test('goes back and forward through link positions', () {
    final history = ReaderLinkHistory();
    final first = position(1);
    final second = position(2);

    history.pushOrigin(first);
    expect(history.goBack(second), first);
    expect(history.canGoBack, isFalse);
    expect(history.canGoForward, isTrue);
    expect(history.goForward(first), second);
    expect(history.canGoBack, isTrue);
    expect(history.canGoForward, isFalse);
  });

  test('a new link after going back discards the forward branch', () {
    final history = ReaderLinkHistory();
    final first = position(1);
    final second = position(2);

    history.pushOrigin(first);
    expect(history.goBack(second), first);
    history.pushOrigin(first);

    expect(history.canGoForward, isFalse);
    expect(history.goForward(first), isNull);
  });
}
