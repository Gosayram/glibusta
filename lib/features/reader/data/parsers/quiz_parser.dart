/// LW-9.1: Basic quiz/interactive content parser.
/// ponytail: regex-based extraction of quiz structures from EPUB text blocks.
/// Detects question patterns and answer options from plain text content.
class FillableBlock {
  const FillableBlock({
    required this.textParts,
    required this.blanks,
  });

  /// Text segments between blanks. Length = blanks.length + 1.
  final List<String> textParts;

  /// Blank definitions. Each has an optional expected answer.
  final List<BlankDef> blanks;

  String get fullText =>
      textParts.asMap().entries.map((e) => e.value + (e.key < blanks.length ? '___' : '')).join();
}

class BlankDef {
  const BlankDef({this.expectedAnswer, this.id});

  final String? expectedAnswer;
  final String? id;
}

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
      // "1. What is...?" or "Q: What is...?" or "Что такое...?" or "Какой...?"
      final questionMatch = RegExp(
        r'^(?:\d+[\.\)]\s*|Q:\s*|Вопрос\s*\d*[:\.]?\s*)?(.+?)\?+$',
        caseSensitive: false,
      ).firstMatch(trimmed);

      // Only treat as question if it has a prefix OR is short enough
      final hasPrefix = RegExp(
        r'^(?:\d+[\.\)]\s*|Q:\s*|Вопрос)',
        caseSensitive: false,
      ).hasMatch(trimmed);
      final isShortQuestion = trimmed.length < 200;

      if (questionMatch != null && (hasPrefix || isShortQuestion)) {
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

  /// Try to parse fillable-field content from a list of text blocks.
  /// Detects `___` (3+ underscores), `[expected]`, and `{expected}` patterns.
  /// Returns null if no fillable fields detected.
  static List<FillableBlock>? tryParseFillable(List<String> blocks) {
    final results = <FillableBlock>[];
    for (final block in blocks) {
      final text = block.trim();
      if (text.isEmpty) continue;

      // Pattern 1: [expected answer] — bracket-wrapped blanks
      final bracketMatches = RegExp(r'\[([^\]]*?)\]').allMatches(text);
      // Pattern 2: {expected answer} — brace-wrapped blanks
      final braceMatches = RegExp(r'\{([^\}]*?)\}').allMatches(text);
      // Pattern 3: ___ (3+ underscores)
      final underscoreMatches = RegExp(r'_{3,}').allMatches(text);

      final allMatches = [
        ...bracketMatches.map((m) => (m: m, type: 'bracket')),
        ...braceMatches.map((m) => (m: m, type: 'brace')),
        ...underscoreMatches.map((m) => (m: m, type: 'underscore')),
      ]..sort((a, b) => a.m.start.compareTo(b.m.start));

      if (allMatches.isEmpty) continue;

      final blanks = <BlankDef>[];
      var lastEnd = 0;
      final parts = <String>[];
      for (final match in allMatches) {
        // Skip overlapping matches
        if (match.m.start < lastEnd) continue;

        parts.add(text.substring(lastEnd, match.m.start));
        final content = match.m.group(1);
        blanks.add(
          BlankDef(
            expectedAnswer: content != null && content.isNotEmpty ? content : null,
            id: 'blank-${results.length}-${blanks.length}',
          ),
        );
        lastEnd = match.m.end;
      }
      parts.add(text.substring(lastEnd));

      results.add(FillableBlock(textParts: parts, blanks: blanks));
    }

    return results.isEmpty ? null : results;
  }
}
