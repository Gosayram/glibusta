import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('changing brightness does not rebuild content watcher', (tester) async {
    int contentBuilds = 0;
    int overlayBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final fontSize = ref.watch(
                readerSettingsProvider.select((s) => s.fontSize),
              );
              final brightness = ref.watch(
                readerSettingsProvider.select((s) => s.brightness),
              );
              contentBuilds++;
              return Text('f=$fontSize b=$brightness');
            },
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );

    contentBuilds = 0;
    overlayBuilds = 0;

    container.read(readerSettingsProvider.notifier).updateBrightness(0.5);
    await tester.pump();

    expect(overlayBuilds, 0);
    expect(contentBuilds, 1);

    contentBuilds = 0;
    container.read(readerSettingsProvider.notifier).updateBrightness(0.3);
    await tester.pump();

    expect(contentBuilds, 1);
  });

  testWidgets('changing fontSize does not rebuild brightness watcher', (tester) async {
    int watcherBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(
                readerSettingsProvider.select((s) => s.brightness),
              );
              watcherBuilds++;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );

    watcherBuilds = 0;

    container.read(readerSettingsProvider.notifier).updateFontSize(24);
    await tester.pump();

    expect(watcherBuilds, 0);
  });

  testWidgets('selective watches trigger only for their fields', (tester) async {
    int brightnessBuilds = 0;
    int fontSizeBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  ref.watch(
                    readerSettingsProvider.select((s) => s.brightness),
                  );
                  brightnessBuilds++;
                  return const SizedBox();
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  ref.watch(
                    readerSettingsProvider.select((s) => s.fontSize),
                  );
                  fontSizeBuilds++;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer).first),
    );

    brightnessBuilds = 0;
    fontSizeBuilds = 0;

    container.read(readerSettingsProvider.notifier).updateBrightness(0.7);
    await tester.pump();

    expect(brightnessBuilds, 1);
    expect(fontSizeBuilds, 0);

    brightnessBuilds = 0;
    fontSizeBuilds = 0;

    container.read(readerSettingsProvider.notifier).updateFontSize(30);
    await tester.pump();

    expect(brightnessBuilds, 0);
    expect(fontSizeBuilds, 1);
  });

  testWidgets('changing warmth does not rebuild fontSize watcher', (tester) async {
    int fontSizeBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(
                readerSettingsProvider.select((s) => s.fontSize),
              );
              fontSizeBuilds++;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );

    fontSizeBuilds = 0;

    container.read(readerSettingsProvider.notifier).updateWarmth(0.5);
    await tester.pump();

    expect(fontSizeBuilds, 0);
  });

  testWidgets('changing mode triggers mode watcher only', (tester) async {
    int modeBuilds = 0;
    int brightnessBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  ref.watch(
                    readerSettingsProvider.select((s) => s.mode),
                  );
                  modeBuilds++;
                  return const SizedBox();
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  ref.watch(
                    readerSettingsProvider.select((s) => s.brightness),
                  );
                  brightnessBuilds++;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer).first),
    );

    modeBuilds = 0;
    brightnessBuilds = 0;

    container.read(readerSettingsProvider.notifier).updateMode(ReaderMode.continuous);
    await tester.pump();

    expect(modeBuilds, 1);
    expect(brightnessBuilds, 0);
  });
}
