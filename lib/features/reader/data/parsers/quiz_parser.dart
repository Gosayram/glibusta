/// LW-9.1: Basic quiz/interactive content parser.
/// ponytail: regex-based extraction of quiz structures from EPUB text blocks.
/// Detects question patterns and answer options from plain text content.
class QuizBlock {
  const QuizBlock({
    required this.question,
    required this.options,
    this.correctIndex,
  });

  final String question;
  final List<String> options;
  final int? correctIndex;
}

class QuizParser {
  /// Try to parse quiz content from a list of text blocks.
  /// Returns null if no quiz-like content is detected.
  static List<QuizBlock>? tryParse(List<String> blocks) {
    final quizzes = <QuizBlock>[];
    String? currentQuestion;
    final currentOptions = <String>[];

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      // Detect question patterns:
      // "1. What is...?" or "Q: What is...?" or "Что такое...?"
      final questionMatch = RegExp(
        r'^(?:\d+[\.\)]\s*|Q:\s*|Вопрос\s*\d*[:\.]?\s*)(.+)\?$',
        caseSensitive: false,
      ).firstMatch(trimmed);

      if (questionMatch != null) {
        // Save previous question if exists
        if (currentQuestion != null && currentOptions.isNotEmpty) {
          quizzes.add(
            QuizBlock(
              question: currentQuestion,
              options: List.unmodifiable(currentOptions),
            ),
          );
        }
        currentQuestion = questionMatch.group(1) ?? trimmed;
        currentOptions.clear();
        continue;
      }

      // Detect answer options:
      // "a) ..." or "A. ..." or "- ..." or "1) ..." or "Правильный ответ: ..."
      final optionMatch = RegExp(
        r'^(?:[a-dA-D][\.\)]\s*|[-–]\s*|\d+[\.\)]\s*)(.+)$',
      ).firstMatch(trimmed);

      if (optionMatch != null && currentQuestion != null) {
        currentOptions.add(optionMatch.group(1)?.trim() ?? trimmed);
        continue;
      }

      // Detect correct answer marker
      final correctMatch = RegExp(
        r'(?:Правильный ответ|Ответ|Correct answer)[:\s]+(.+)',
        caseSensitive: false,
      ).firstMatch(trimmed);

      if (correctMatch != null && currentQuestion != null) {
        final answer = correctMatch.group(1)?.trim() ?? '';
        if (answer.isNotEmpty) {
          currentOptions.add('✓ $answer');
        }
        continue;
      }

      // Detect Yes/No questions (common in EPUB quizzes)
      if (currentQuestion != null &&
          (trimmed == 'Да' ||
              trimmed == 'Нет' ||
              trimmed.toLowerCase() == 'yes' ||
              trimmed.toLowerCase() == 'no')) {
        currentOptions.add(trimmed);
      }
    }

    // Save last question
    if (currentQuestion != null && currentOptions.isNotEmpty) {
      quizzes.add(
        QuizBlock(
          question: currentQuestion,
          options: List.unmodifiable(currentOptions),
        ),
      );
    }

    return quizzes.isEmpty ? null : quizzes;
  }
}
