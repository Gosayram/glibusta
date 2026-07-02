import 'dart:async';

import 'package:flutter/material.dart';

import '../data/parsers/quiz_parser.dart';

/// LW-9.2: Fillable field widget — renders blanks with tap-to-fill.
class FillableFieldWidget extends StatefulWidget {
  const FillableFieldWidget({super.key, required this.block});

  final FillableBlock block;

  @override
  State<FillableFieldWidget> createState() => _FillableFieldWidgetState();
}

class _FillableFieldWidgetState extends State<FillableFieldWidget> {
  final _answers = <String>{};
  var _showResults = false;

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final colors = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildText(block, colors, ts),
            if (_showResults) ...[
              const SizedBox(height: 12),
              _buildResults(block, colors),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_showResults)
                  FilledButton(
                    onPressed: _answers.isEmpty ? null : () => setState(() => _showResults = true),
                    child: const Text('Check'),
                  ),
                if (_showResults)
                  TextButton(
                    onPressed: () => setState(() {
                      _answers.clear();
                      _showResults = false;
                    }),
                    child: const Text('Reset'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildText(FillableBlock block, ColorScheme colors, TextStyle ts) {
    final widgets = <InlineSpan>[];
    for (var i = 0; i < block.textParts.length; i++) {
      widgets.add(TextSpan(text: block.textParts[i], style: ts));
      if (i < block.blanks.length) {
        final blank = block.blanks[i];
        final isFilled = _answers.contains(blank.id);
        widgets.add(
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _fillBlank(blank),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isFilled ? colors.primary : colors.outline,
                      width: 2,
                    ),
                  ),
                  color: isFilled ? colors.primary.withValues(alpha: 0.1) : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '________',
                  style: ts.copyWith(color: colors.primary),
                ),
              ),
            ),
          ),
        );
      }
    }
    return RichText(text: TextSpan(children: widgets));
  }

  void _fillBlank(BlankDef blank) {
    final controller = TextEditingController();
    unawaited(
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fill in the blank'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: blank.expectedAnswer ?? 'Type your answer...',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                setState(() => _answers.add(blank.id!));
              }
              Navigator.of(ctx).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() => _answers.add(blank.id!));
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(FillableBlock block, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: block.blanks.map((blank) {
        final hasAnswer = _answers.contains(blank.id);
        if (blank.expectedAnswer == null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              hasAnswer ? '✓ Answered' : '✗ Skipped',
              style: TextStyle(color: hasAnswer ? Colors.green : Colors.orange),
            ),
          );
        }
        final isCorrect = hasAnswer;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: isCorrect ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text('Expected: ${blank.expectedAnswer}'),
            ],
          ),
        );
      }).toList(),
    );
  }
}
