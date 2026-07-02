import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/quiz_parser.dart';

void main() {
  group('QuizParser', () {
    test('parses numbered questions with letter options', () {
      final blocks = [
        '1. What is the capital of France?',
        'a) London',
        'b) Berlin',
        'c) Paris',
        'd) Madrid',
      ];
      final quizzes = QuizParser.tryParse(blocks);
      expect(quizzes, isNotNull);
      expect(quizzes!.length, 1);
      expect(quizzes[0].question, 'What is the capital of France');
      expect(quizzes[0].options.length, 4);
      expect(quizzes[0].options[2], 'Paris');
    });

    test('parses Russian questions with dash options', () {
      final blocks = [
        'Какой город является столицей Франции?',
        '- Лондон',
        '- Берлин',
        '- Париж',
        '- Мадрид',
      ];
      final quizzes = QuizParser.tryParse(blocks);
      expect(quizzes, isNotNull);
      expect(quizzes!.length, 1);
      expect(quizzes[0].options.length, 4);
    });

    test('parses yes/no questions', () {
      final blocks = [
        'Водород является элементом?',
        'Да',
        'Нет',
      ];
      final quizzes = QuizParser.tryParse(blocks);
      expect(quizzes, isNotNull);
      expect(quizzes!.length, 1);
      expect(quizzes[0].options.length, 2);
    });

    test('parses Q: prefix questions', () {
      final blocks = [
        'Q: What does HTTP stand for?',
        'a) HyperText Transfer Protocol',
        'b) High Tech Transfer Protocol',
      ];
      final quizzes = QuizParser.tryParse(blocks);
      expect(quizzes, isNotNull);
      expect(quizzes![0].question, 'What does HTTP stand for');
    });

    test('returns null for non-quiz content', () {
      final blocks = [
        'Chapter 1',
        'The quick brown fox jumps over the lazy dog.',
        'This is just regular text with no quiz content.',
      ];
      final quizzes = QuizParser.tryParse(blocks);
      expect(quizzes, isNull);
    });

    test('returns null for empty input', () {
      expect(QuizParser.tryParse([]), isNull);
    });

    test('parses multiple questions', () {
      final blocks = [
        '1. Question one?',
        '- a',
        '- b',
        '2. Question two?',
        '- c',
        '- d',
      ];
      final quizzes = QuizParser.tryParse(blocks);
      expect(quizzes, isNotNull);
      expect(quizzes!.length, 2);
      expect(quizzes[0].question, 'Question one');
      expect(quizzes[1].question, 'Question two');
    });
  });
}
