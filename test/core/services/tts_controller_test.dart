import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:glibusta/core/services/tts_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

class _TestTimer implements Timer {
  _TestTimer(this._callback);

  final void Function() _callback;
  var _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;

  @override
  void cancel() {
    _isActive = false;
  }

  void fire() {
    if (!_isActive) return;
    _isActive = false;
    _callback();
  }

  void fireAfterCancellation() {
    _callback();
  }
}

void main() {
  late _MockFlutterTts tts;
  late TtsController controller;
  var createdPlayers = 0;

  setUp(() {
    tts = _MockFlutterTts();
    when(() => tts.setLanguage(any())).thenAnswer((_) async {});
    when(() => tts.setSpeechRate(any())).thenAnswer((_) async {});
    when(() => tts.speak(any())).thenAnswer((_) async {});
    when(() => tts.stop()).thenAnswer((_) async {});
    controller = TtsController.forTesting(() {
      createdPlayers++;
      return tts;
    });
  });

  test('reuses one native player across consecutive utterances', () async {
    await controller.speak('first');
    await controller.speak('second');

    expect(createdPlayers, 1);
  });

  test('can stop before the first utterance', () {
    expect(controller.stop, returnsNormally);
  });

  test('maps reader playback speed to native TTS rate', () async {
    await controller.setPlaybackRate(2);

    expect(controller.playbackRate, 2);
    verify(() => tts.setSpeechRate(1)).called(1);

    await controller.speak('chapter');
    verify(() => tts.setSpeechRate(1)).called(1);
  });

  test('rejects playback speed outside the supported range', () async {
    await expectLater(
      controller.setPlaybackRate(0.25),
      throwsArgumentError,
    );
    await expectLater(
      controller.setPlaybackRate(3.5),
      throwsArgumentError,
    );
  });

  test('stores the selected language for subsequent utterances', () async {
    await controller.setLanguage('en-US');

    expect(controller.language, 'en-US');
    verify(() => tts.setLanguage('en-US')).called(1);

    await controller.speak('chapter');
    verify(() => tts.setLanguage('en-US')).called(1);
  });

  test('rejects an empty speech language', () async {
    await expectLater(controller.setLanguage('  '), throwsArgumentError);
  });

  test('sleep timer stops speech when it expires', () async {
    late _TestTimer timer;
    controller = TtsController.forTesting(
      () => tts,
      timerFactory: (_, callback) => timer = _TestTimer(callback),
    );
    await controller.speak('chapter');

    controller.startSleepTimer(const Duration(minutes: 20));
    timer.fire();

    expect(controller.isPlaying, isFalse);
    expect(controller.hasSleepTimer, isFalse);
    verify(() => tts.stop()).called(1);
  });

  test('restarting a sleep timer cancels the previous timer', () async {
    final List<_TestTimer> timers = <_TestTimer>[];
    controller = TtsController.forTesting(
      () => tts,
      timerFactory: (_, callback) {
        final _TestTimer timer = _TestTimer(callback);
        timers.add(timer);
        return timer;
      },
    );
    await controller.speak('chapter');

    controller.startSleepTimer(const Duration(minutes: 20));
    controller.startSleepTimer(const Duration(minutes: 30));
    timers.first.fireAfterCancellation();

    expect(controller.isPlaying, isTrue);
    expect(controller.sleepTimerDuration, const Duration(minutes: 30));
    timers.last.fire();

    expect(controller.isPlaying, isFalse);
    verify(() => tts.stop()).called(1);
  });

  test('disposing cancels a pending sleep timer', () {
    late _TestTimer timer;
    controller = TtsController.forTesting(
      () => tts,
      timerFactory: (_, callback) => timer = _TestTimer(callback),
    );

    controller.startSleepTimer(const Duration(minutes: 20));
    controller.dispose();
    timer.fireAfterCancellation();

    expect(controller.hasSleepTimer, isFalse);
    verifyNever(() => tts.stop());
  });

  test('rejects a non-positive sleep timer duration', () {
    expect(
      () => controller.startSleepTimer(Duration.zero),
      throwsArgumentError,
    );
  });
}
