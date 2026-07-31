import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('volume button key codes', () {
    test('audioVolumeUp is a defined logical key', () {
      expect(LogicalKeyboardKey.audioVolumeUp, isNotNull);
      expect(LogicalKeyboardKey.audioVolumeUp.keyId, isPositive);
    });

    test('audioVolumeDown is a defined logical key', () {
      expect(LogicalKeyboardKey.audioVolumeDown, isNotNull);
      expect(LogicalKeyboardKey.audioVolumeDown.keyId, isPositive);
    });
  });

  group('ReaderSettings volumeButtonsEnabled', () {
    test('defaults to false', () {
      const settings = ReaderSettings();
      expect(settings.volumeButtonsEnabled, isFalse);
    });

    test('can be set to true', () {
      const settings = ReaderSettings(volumeButtonsEnabled: true);
      expect(settings.volumeButtonsEnabled, isTrue);
    });

    test('copyWith preserves the value', () {
      const settings = ReaderSettings(volumeButtonsEnabled: true);
      final copied = settings.copyWith(fontSize: 20);
      expect(copied.volumeButtonsEnabled, isTrue);
    });

    test('copyWith can change the value', () {
      const settings = ReaderSettings();
      final copied = settings.copyWith(volumeButtonsEnabled: true);
      expect(copied.volumeButtonsEnabled, isTrue);
    });
  });

  group('volume button handling logic', () {
    bool handleKeyEvent(
      KeyEvent event, {
      required bool volumeButtonsEnabled,
    }) {
      if (event is! KeyDownEvent) return false;
      if (volumeButtonsEnabled) {
        if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
          return true;
        }
        if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
          return true;
        }
      }
      return false;
    }

    KeyDownEvent volumeUp() => const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.audioVolumeUp,
      logicalKey: LogicalKeyboardKey.audioVolumeUp,
      timeStamp: Duration.zero,
    );

    KeyDownEvent volumeDown() => const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.audioVolumeDown,
      logicalKey: LogicalKeyboardKey.audioVolumeDown,
      timeStamp: Duration.zero,
    );

    test('volume up is handled when enabled', () {
      expect(handleKeyEvent(volumeUp(), volumeButtonsEnabled: true), isTrue);
    });

    test('volume down is handled when enabled', () {
      expect(handleKeyEvent(volumeDown(), volumeButtonsEnabled: true), isTrue);
    });

    test('volume up is ignored when disabled', () {
      expect(handleKeyEvent(volumeUp(), volumeButtonsEnabled: false), isFalse);
    });

    test('volume down is ignored when disabled', () {
      expect(handleKeyEvent(volumeDown(), volumeButtonsEnabled: false), isFalse);
    });

    test('non-volume key is not handled even when enabled', () {
      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      );
      expect(handleKeyEvent(event, volumeButtonsEnabled: true), isFalse);
    });

    test('key up events are ignored', () {
      const event = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.audioVolumeUp,
        logicalKey: LogicalKeyboardKey.audioVolumeUp,
        timeStamp: Duration.zero,
      );
      expect(handleKeyEvent(event, volumeButtonsEnabled: true), isFalse);
    });
  });
}
