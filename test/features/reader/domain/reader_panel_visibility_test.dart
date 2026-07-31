import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('ReaderSettings panel visibility', () {
    test('defaults are all true', () {
      const s = ReaderSettings();
      expect(s.showTopInfoBar, isTrue);
      expect(s.showTopToolbar, isTrue);
      expect(s.showBottomBar, isTrue);
    });

    test('copyWith showTopInfoBar', () {
      const s = ReaderSettings();
      final changed = s.copyWith(showTopInfoBar: false);
      expect(changed.showTopInfoBar, isFalse);
      expect(changed.showTopToolbar, isTrue);
      expect(changed.showBottomBar, isTrue);
    });

    test('copyWith showTopToolbar', () {
      const s = ReaderSettings();
      final changed = s.copyWith(showTopToolbar: false);
      expect(changed.showTopInfoBar, isTrue);
      expect(changed.showTopToolbar, isFalse);
      expect(changed.showBottomBar, isTrue);
    });

    test('copyWith showBottomBar', () {
      const s = ReaderSettings();
      final changed = s.copyWith(showBottomBar: false);
      expect(changed.showTopInfoBar, isTrue);
      expect(changed.showTopToolbar, isTrue);
      expect(changed.showBottomBar, isFalse);
    });

    test('hiding one panel does not affect others', () {
      const s = ReaderSettings();
      final onlyTopHidden = s.copyWith(showTopInfoBar: false);
      expect(onlyTopHidden.showTopToolbar, isTrue);
      expect(onlyTopHidden.showBottomBar, isTrue);

      final onlyToolbarHidden = s.copyWith(showTopToolbar: false);
      expect(onlyToolbarHidden.showTopInfoBar, isTrue);
      expect(onlyToolbarHidden.showBottomBar, isTrue);

      final onlyBottomHidden = s.copyWith(showBottomBar: false);
      expect(onlyBottomHidden.showTopInfoBar, isTrue);
      expect(onlyBottomHidden.showTopToolbar, isTrue);
    });

    test('multiple panels can be hidden simultaneously', () {
      const s = ReaderSettings();
      final allHidden = s.copyWith(
        showTopInfoBar: false,
        showTopToolbar: false,
        showBottomBar: false,
      );
      expect(allHidden.showTopInfoBar, isFalse);
      expect(allHidden.showTopToolbar, isFalse);
      expect(allHidden.showBottomBar, isFalse);
    });
  });
}
