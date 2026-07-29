import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/per_book_settings_service.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('mergeReaderSettings', () {
    test('keeps every global preference when a book overrides only its font size', () {
      const global = ReaderSettings(
        theme: ReaderTheme.bedtime,
        mode: ReaderMode.continuous,
        twoPageEnabled: true,
        fontSize: 19,
        lineHeight: 1.8,
        margin: 24,
        marginTop: 11,
        marginBottom: 12,
        marginLeft: 13,
        marginRight: 14,
        separateMargins: true,
        font: ReaderFont.mono,
        paragraphSpacing: 27,
        letterSpacing: 0.2,
        wordSpacing: 0.3,
        fontWeightDelta: 100,
        textAlign: ReaderTextAlign.center,
        autoThemeMode: AutoThemeMode.custom,
        customDayHour: 8,
        customNightHour: 22,
        brightness: 0.7,
        warmth: 0.4,
        keepScreenAwake: false,
        autoHideDelay: 9,
        progressBarPosition: ProgressBarPosition.hidden,
        bottomBarContent: BottomBarContent.chapter,
        paragraphFirstLineIndent: 23,
        paragraphIndentMode: ParagraphIndentMode.emptyLine,
        hyphenation: false,
        pageTurnAnimation: PageTurnAnimation.curl,
        scrollInertia: ScrollInertia.heavy,
        textDirection: ReaderTextDirection.rtl,
        readerWidth: 640,
        verticalSwipeBrightness: false,
        doubleTapAction: DoubleTapAction.translate,
        longPressAction: LongPressAction.openMenu,
        restoreLastPosition: false,
        forcedEncoding: 'windows-1251',
        horizontalGesture: HorizontalGesture.inverse,
        horizontalGestureScroll: HorizontalGestureScroll.threeQuarters,
        tapZoneWidth: 0.4,
        fullScreenMode: FullScreenMode.keepPanels,
        customCss: 'p { color: red; }',
        perceptionExpander: true,
        hideBarsOnFastScroll: true,
        orientationLock: OrientationLock.landscape,
        bionicReading: true,
        horizontalLimiter: true,
        horizontalLimiterHeight: 0.6,
        horizontalLimiterOffset: 0.7,
        horizontalLimiterDimming: 0.2,
        horizontalLimiterLines: false,
        scrollbarIndicator: false,
        showImages: false,
        imageCornerRadius: 8,
        imageAlignment: ImageAlignment.end,
        imageWidth: 0.8,
        imageColorEffect: ImageColorEffect.grayscale,
        activeColorPresetId: 'custom',
        oldStyleFigures: true,
        smallCaps: true,
        rsvpWpm: 450,
        ignoreBookAlignment: true,
        ignoreBookIndent: true,
      );

      final settings = mergeReaderSettings(global, const {'fontSize': 24});

      expect(settings, global.copyWith(fontSize: 24));
    });

    test('applies a persisted override for a newly supported preference', () {
      const global = ReaderSettings();

      final settings = mergeReaderSettings(global, const {
        'showImages': false,
        'orientationLock': 'portrait',
      });

      expect(settings.showImages, isFalse);
      expect(settings.orientationLock, OrientationLock.portrait);
    });

    test('keeps compact and expanded two-page preferences isolated for one book', () {
      const global = ReaderSettings(
        fontSize: 19,
      );
      const savedBookSettings = {
        'fontSize': 21,
        'layoutProfiles': {
          'compact': {'twoPageEnabled': false},
          'expanded': {'twoPageEnabled': true},
        },
      };

      final compact = mergeReaderSettingsForDeviceClass(
        global,
        savedBookSettings,
        ReaderLayoutDeviceClass.compact,
      );
      final expanded = mergeReaderSettingsForDeviceClass(
        global,
        savedBookSettings,
        ReaderLayoutDeviceClass.expanded,
      );

      expect(compact.fontSize, 21);
      expect(compact.twoPageEnabled, isFalse);
      expect(expanded.fontSize, 21);
      expect(expanded.twoPageEnabled, isTrue);
    });

    test('ignores a malformed layout profile without changing shared settings', () {
      const global = ReaderSettings(twoPageEnabled: true);

      final settings = mergeReaderSettingsForDeviceClass(
        global,
        const {
          'layoutProfiles': {
            'expanded': {'twoPageEnabled': 'yes'},
          },
        },
        ReaderLayoutDeviceClass.expanded,
      );

      expect(settings.twoPageEnabled, isTrue);
    });
  });

  test('captures only appearance fields for a per-book profile', () {
    const settings = ReaderSettings(
      theme: ReaderTheme.sepia,
      fontSize: 21,
      font: ReaderFont.mono,
      marginLeft: 28,
      paragraphIndentMode: ParagraphIndentMode.emptyLine,
      showImages: false,
    );

    expect(
      readingAppearanceOverrides(settings),
      {
        'theme': 'sepia',
        'fontSize': 21,
        'lineHeight': 1.6,
        'margin': 20.0,
        'marginTop': 20.0,
        'marginBottom': 20.0,
        'marginLeft': 28.0,
        'marginRight': 20.0,
        'separateMargins': false,
        'font': 'mono',
        'paragraphSpacing': 20.0,
        'letterSpacing': 0.0,
        'wordSpacing': 0.0,
        'fontWeightDelta': 0.0,
        'textAlign': 'justify',
        'paragraphFirstLineIndent': 16.0,
        'paragraphIndentMode': 'emptyLine',
      },
    );
  });
}
