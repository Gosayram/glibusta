import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:glibusta/core/services/tts_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

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
}
