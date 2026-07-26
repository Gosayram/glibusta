import 'package:flutter/material.dart';

/// A small, deliberately scoped editor for the reader's supported CSS subset.
///
/// Keeping the controller alive avoids moving the caret to the end whenever a
/// setting update rebuilds the quick-settings sheet.
class ReaderCustomCssEditor extends StatefulWidget {
  const ReaderCustomCssEditor({
    required this.css,
    required this.onChanged,
    super.key,
  });

  final String css;
  final ValueChanged<String> onChanged;

  @override
  State<ReaderCustomCssEditor> createState() => _ReaderCustomCssEditorState();
}

class _ReaderCustomCssEditorState extends State<ReaderCustomCssEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.css);
  }

  @override
  void didUpdateWidget(covariant ReaderCustomCssEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.css == oldWidget.css || _controller.text == widget.css) return;

    _controller.value = TextEditingValue(
      text: widget.css,
      selection: TextSelection.collapsed(offset: widget.css.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCss = _controller.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Пользовательский CSS', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'Применяются только свойства p: font-size, line-height, '
          'letter-spacing и word-spacing. Сеть и стили книги недоступны.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          ),
          child: TextField(
            controller: _controller,
            onChanged: (value) {
              setState(() {});
              widget.onChanged(value);
            },
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: 'p { line-height: 1.7; }',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              suffixIcon: hasCss
                  ? IconButton(
                      tooltip: 'Сбросить пользовательский CSS',
                      icon: const Icon(Icons.restart_alt),
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
