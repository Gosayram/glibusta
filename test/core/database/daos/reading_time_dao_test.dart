import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('concurrent reading-time increments are not lost', () async {
    final now = DateTime(2026, 7, 14, 12);
    await database.readingTimeDao.addReadingTime('book', now, 1);

    await Future.wait([
      database.readingTimeDao.addReadingTime('book', now, 2),
      database.readingTimeDao.addReadingTime('book', now, 3),
    ]);

    expect(await database.readingTimeDao.getDailyReadingSeconds('book', now), 6);
  });
}
