import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('ReaderPosition', () {
    test('initial has empty bookId', () {
      expect(ReaderPosition.initial.bookId, '');
      expect(ReaderPosition.initial.chapterIndex, 0);
      expect(ReaderPosition.initial.paragraphIndex, 0);
    });

    test('copyWith preserves unchanged fields', () {
      final pos = ReaderPosition(
        bookId: 'b1',
        chapterIndex: 3,
        paragraphIndex: 5,
        localOffset: 1.5,
        progressPercent: 0.45,
        updatedAt: DateTime(2026),
      );
      final updated = pos.copyWith(chapterIndex: 7);
      expect(updated.bookId, 'b1');
      expect(updated.chapterIndex, 7);
      expect(updated.paragraphIndex, 5);
      expect(updated.localOffset, 1.5);
      expect(updated.progressPercent, 0.45);
    });

    test('clamp limits chapterIndex', () {
      final pos = ReaderPosition(
        bookId: 'b1',
        chapterIndex: 100,
        paragraphIndex: 0,
        updatedAt: DateTime(2026),
      );
      final clamped = pos.clamp(chapterCount: 10);
      expect(clamped.chapterIndex, 9);
    });

    test('clamp chapterIndex to 0 when chapterCount is 1', () {
      final pos = ReaderPosition(
        bookId: 'b1',
        chapterIndex: 5,
        paragraphIndex: 0,
        updatedAt: DateTime(2026),
      );
      final clamped = pos.clamp(chapterCount: 1);
      expect(clamped.chapterIndex, 0);
    });

    test('clamp resets all fields when chapterCount is 0', () {
      final pos = ReaderPosition(
        bookId: 'b1',
        chapterIndex: 5,
        paragraphIndex: 3,
        localOffset: 50.0,
        progressPercent: 0.5,
        updatedAt: DateTime(2026),
      );
      final clamped = pos.clamp(chapterCount: 0);
      expect(clamped.chapterIndex, 0);
      expect(clamped.paragraphIndex, 0);
      expect(clamped.localOffset, 0.0);
      expect(clamped.progressPercent, 0.0);
    });

    test('clamp paragraphIndex minimum is 0', () {
      final pos = ReaderPosition(
        bookId: 'b1',
        chapterIndex: 0,
        paragraphIndex: -5,
        updatedAt: DateTime(2026),
      );
      final clamped = pos.clamp(chapterCount: 10);
      expect(clamped.paragraphIndex, 0);
    });

    test('clamp localOffset between 0 and 100', () {
      final pos = ReaderPosition(
        bookId: 'b1',
        chapterIndex: 0,
        paragraphIndex: 0,
        localOffset: 150.0,
        updatedAt: DateTime(2026),
      );
      final clamped = pos.clamp(chapterCount: 10);
      expect(clamped.localOffset, 100.0);
    });

    test('clamp progressPercent between 0 and 1', () {
      final pos = ReaderPosition(
        bookId: 'b1',
        chapterIndex: 0,
        paragraphIndex: 0,
        progressPercent: 1.5,
        updatedAt: DateTime(2026),
      );
      final clamped = pos.clamp(chapterCount: 10);
      expect(clamped.progressPercent, 1.0);
    });

    test('currentPosition returns chapterIndex', () {
      final pos = ReaderPosition(
        bookId: 'b1',
        chapterIndex: 7,
        paragraphIndex: 0,
        updatedAt: DateTime(2026),
      );
      expect(pos.currentPosition, 7);
    });
  });

  group('ReaderSettings', () {
    test('default values', () {
      const settings = ReaderSettings();
      expect(settings.theme, ReaderTheme.system);
      expect(settings.mode, ReaderMode.paginated);
      expect(settings.fontSize, 18.0);
      expect(settings.lineHeight, 1.6);
      expect(settings.margin, 20.0);
      expect(settings.font, ReaderFont.literata);
      expect(settings.autoThemeMode, AutoThemeMode.off);
      expect(settings.keepScreenAwake, isTrue);
      expect(settings.restoreLastPosition, isTrue);
    });

    test('copyWith works', () {
      const settings = ReaderSettings();
      final updated = settings.copyWith(
        fontSize: 24.0,
        theme: ReaderTheme.dark,
      );
      expect(updated.fontSize, 24.0);
      expect(updated.theme, ReaderTheme.dark);
      expect(updated.lineHeight, 1.6);
    });
  });

  group('AutoThemeMode', () {
    test('display names', () {
      expect(AutoThemeMode.off.displayName, 'Выкл');
      expect(AutoThemeMode.system.displayName, 'Системная');
      expect(AutoThemeMode.sunset.displayName, 'Закат');
      expect(AutoThemeMode.custom.displayName, 'По времени');
    });
  });

  group('ReaderFont', () {
    test('display names', () {
      expect(ReaderFont.literata.displayName, 'Literata');
      expect(ReaderFont.inter.displayName, 'Inter');
    });
  });

  group('ReadingProgress', () {
    test('fromPosition', () {
      final pos = ReaderPosition(
        bookId: 'b1',
        chapterIndex: 2,
        paragraphIndex: 3,
        updatedAt: DateTime(2026),
      );
      final progress = ReadingProgress.fromPosition(pos, totalPages: 100);
      expect(progress.position, pos);
      expect(progress.totalPages, 100);
      expect(progress.lastRead, pos.updatedAt);
    });
  });
}
