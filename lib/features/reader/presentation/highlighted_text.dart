import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

/// A text widget that renders highlight overlays behind the text.
///
/// Highlights are colored rectangles positioned using TextPainter line metrics.
/// The text itself is rendered normally on top of the highlights.
class HighlightedText extends StatefulWidget {
  const HighlightedText({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.highlights,
    super.key,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final List<TextHighlight> highlights;

  @override
  State<HighlightedText> createState() => _HighlightedTextState();
}

class _HighlightedTextState extends State<HighlightedText> {
  TextPainter? _textPainter;
  Size _lastSize = Size.zero;
  TextDirection? _lastTextDirection;

  static const _colorMap = <String, Color>{
    'yellow': Color(0x40FFEB3B),
    'green': Color(0x404CAF50),
    'blue': Color(0x402196F3),
    'red': Color(0x40F44336),
    'purple': Color(0x409C27B0),
    'orange': Color(0x40FF9800),
  };

  @override
  void didUpdateWidget(covariant HighlightedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text ||
        widget.style != oldWidget.style ||
        widget.highlights != oldWidget.highlights) {
      _textPainter = null;
    }
  }

  @override
  void dispose() {
    _textPainter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.highlights.isEmpty) {
      return _buildText();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0) return _buildText();

        _ensureTextPainter(maxWidth, Directionality.of(context));

        return CustomPaint(
          size: Size(maxWidth, _textPainter!.height),
          painter: _HighlightBlockPainter(
            highlights: widget.highlights,
            textPainter: _textPainter!,
            colorMap: _colorMap,
          ),
          child: _buildText(),
        );
      },
    );
  }

  Widget _buildText() {
    return Text(
      widget.text,
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }

  void _ensureTextPainter(double maxWidth, TextDirection textDirection) {
    if (_textPainter != null &&
        _lastSize.width == maxWidth &&
        _lastTextDirection == textDirection) {
      return;
    }

    _textPainter?.dispose();
    _textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: textDirection,
    )..layout(maxWidth: maxWidth);
    _lastSize = Size(maxWidth, _textPainter!.height);
    _lastTextDirection = textDirection;
  }
}

class _HighlightBlockPainter extends CustomPainter {
  _HighlightBlockPainter({
    required this.highlights,
    required this.textPainter,
    required this.colorMap,
  });

  final List<TextHighlight> highlights;
  final TextPainter textPainter;
  final Map<String, Color> colorMap;

  @override
  void paint(Canvas canvas, Size size) {
    if (textPainter.size == Size.zero) return;

    final lineMetrics = textPainter.computeLineMetrics();
    if (lineMetrics.isEmpty) return;

    for (final h in highlights) {
      final color = colorMap[h.color] ?? colorMap['yellow']!;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final rects = _computeRects(h.startOffset, h.endOffset, lineMetrics);
      for (final rect in rects) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
      }
    }
  }

  List<Rect> _computeRects(
    int startOffset,
    int endOffset,
    List<LineMetrics> lineMetrics,
  ) {
    final rects = <Rect>[];
    var currentOffset = 0;

    for (final line in lineMetrics) {
      final lineStart = currentOffset;
      final lineEnd = currentOffset + line.width.ceil();

      if (lineEnd > startOffset && lineStart < endOffset) {
        final s = startOffset.clamp(lineStart, lineEnd);
        final e = endOffset.clamp(lineStart, lineEnd);

        final startX = textPainter.getOffsetForCaret(TextPosition(offset: s), Rect.zero).dx;
        final endX = textPainter.getOffsetForCaret(TextPosition(offset: e), Rect.zero).dx;

        var yOffset = 0.0;
        for (final prev in lineMetrics) {
          if (prev == line) break;
          yOffset += prev.height;
        }

        // ponytail: 2px vertical padding on highlights, no config needed yet
        const padding = 2.0;
        rects.add(
          Rect.fromLTWH(
            startX - 2,
            yOffset + padding,
            (endX - startX) + 4,
            (line.height - padding * 2).clamp(2.0, line.height),
          ),
        );
      }

      currentOffset = lineEnd;
    }

    return rects;
  }

  @override
  bool shouldRepaint(covariant _HighlightBlockPainter oldDelegate) {
    return highlights != oldDelegate.highlights || textPainter != oldDelegate.textPainter;
  }
}
