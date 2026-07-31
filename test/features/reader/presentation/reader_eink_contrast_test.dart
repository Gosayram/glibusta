import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_providers.dart';
import 'package:glibusta/features/reader/presentation/reader_quick_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('e-ink quick settings contrast', () {
    testWidgets('e-ink applies white background and black top border', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerSettingsProvider.overrideWith(() => _EinkNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ReaderQuickSettingsSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ReaderQuickSettingsSheet),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration?)?.border?.top.color == Colors.black,
          ),
        ),
      );
      final root = containers.first;
      final decoration = root.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, isNull);
      expect(decoration.border?.top.color, Colors.black);
    });

    testWidgets('e-ink switch uses activeThumbColor black', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerSettingsProvider.overrideWith(() => _EinkNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ReaderQuickSettingsSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(
        find.byType(Switch),
      );
      for (final sw in switches) {
        if (sw.value) {
          expect(sw.activeThumbColor, Colors.black);
        }
      }
    });

    testWidgets('e-ink theme swatches have solid black border', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerSettingsProvider.overrideWith(() => _EinkNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ReaderQuickSettingsSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final swatchBorders = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration?)?.border?.top.color == Colors.black &&
              (w.decoration as BoxDecoration?)?.borderRadius == BorderRadius.zero,
        ),
      );
      expect(swatchBorders.isNotEmpty, isTrue);
    });

    testWidgets('non-e-ink keeps default surface background', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerSettingsProvider.overrideWith(() => _DefaultNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ReaderQuickSettingsSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ReaderQuickSettingsSheet),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration?)?.border == null &&
                (w.decoration as BoxDecoration?)?.borderRadius != null,
          ),
        ),
      );
      final root = containers.first;
      final decoration = root.decoration! as BoxDecoration;
      expect(decoration.color, isNot(Colors.white));
      expect(decoration.borderRadius, isNotNull);
    });
  });
}

class _EinkNotifier extends ReaderSettingsNotifier {
  @override
  ReaderSettings build() => const ReaderSettings(eink: true);
}

class _DefaultNotifier extends ReaderSettingsNotifier {
  @override
  ReaderSettings build() => const ReaderSettings();
}
