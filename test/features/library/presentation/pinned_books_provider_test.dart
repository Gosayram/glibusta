import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/library/presentation/pinned_books_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  test('keeps both books when different pins are toggled concurrently', () async {
    await container.read(pinnedBooksProvider.future);
    final notifier = container.read(pinnedBooksProvider.notifier);

    await Future.wait([
      notifier.toggle('book-a'),
      notifier.toggle('book-b'),
    ]);

    expect(
      container.read(pinnedBooksProvider).value,
      unorderedEquals(['book-a', 'book-b']),
    );
  });
}
