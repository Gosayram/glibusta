import 'package:flutter/material.dart';

import '../data/parsers/quiz_parser.dart';

/// LW-9.1: Inline quiz widget rendered inside reader content.
class QuizWidget extends StatefulWidget {
  const QuizWidget({super.key, required this.blocks});

  final List<QuizBlock> blocks;

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> {
  var _currentIndex = 0;
  final _selected = <int?>[];
  var _showResults = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(List<int?>.filled(widget.blocks.length, null));
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.blocks;
    if (quiz.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _showResults ? _buildResults(quiz, colors) : _buildQuiz(quiz, colors),
      ),
    );
  }

  Widget _buildQuiz(List<QuizBlock> quiz, ColorScheme colors) {
    final item = quiz[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_currentIndex + 1} / ${quiz.length}',
                style: TextStyle(fontSize: 12, color: colors.primary),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _showResults = true),
              child: const Text('Show Results'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(item.question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        ...item.options.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _selected[_currentIndex] == e.key
                      ? colors.primary.withValues(alpha: 0.1)
                      : null,
                  foregroundColor: _selected[_currentIndex] == e.key ? colors.primary : null,
                ),
                onPressed: () => setState(() => _selected[_currentIndex] = e.key),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${String.fromCharCode(0x41 + e.key)}. ${e.value}'),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentIndex > 0)
              TextButton.icon(
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Previous'),
                onPressed: () => setState(() => _currentIndex--),
              )
            else
              const SizedBox.shrink(),
            if (_currentIndex < quiz.length - 1)
              TextButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Next'),
                onPressed: () => setState(() => _currentIndex++),
              )
            else
              FilledButton(
                onPressed: () => setState(() => _showResults = true),
                child: const Text('Finish'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildResults(List<QuizBlock> quiz, ColorScheme colors) {
    final answered = _selected.where((s) => s != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Results: $answered / ${quiz.length} answered',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...quiz.asMap().entries.map((e) {
          final idx = e.key;
          final item = e.value;
          final sel = _selected[idx];
          final isCorrect = item.correctIndex != null && sel == item.correctIndex;
          final isWrong = sel != null && item.correctIndex != null && sel != item.correctIndex;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCorrect
                  ? Colors.green.withValues(alpha: 0.1)
                  : isWrong
                  ? Colors.red.withValues(alpha: 0.1)
                  : colors.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: isCorrect
                  ? Border.all(color: Colors.green.withValues(alpha: 0.5))
                  : isWrong
                  ? Border.all(color: Colors.red.withValues(alpha: 0.5))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${idx + 1}. ${item.question}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text('Your answer: ${sel != null ? item.options[sel] : '(not answered)'}'),
                if (item.correctIndex != null)
                  Text(
                    'Correct: ${item.options[item.correctIndex!]}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}
