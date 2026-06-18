import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcerptShareService {
  Future<void> shareExcerpt({
    required String text,
    required String bookTitle,
    String? authorName,
    File? coverFile,
    ExcerptStyle style = ExcerptStyle.defaultStyle,
  }) async {
    final imageBytes = await _renderExcerptCard(
      text: text,
      bookTitle: bookTitle,
      authorName: authorName,
      coverFile: coverFile,
      style: style,
    );

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/excerpt_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(imageBytes);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: '$bookTitle — $authorName'),
    );
  }

  Future<Uint8List> _renderExcerptCard({
    required String text,
    required String bookTitle,
    String? authorName,
    File? coverFile,
    required ExcerptStyle style,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(1080, 1080);

    final bgPaint = Paint()..color = style.backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final quoteStyle = TextStyle(
      color: style.textColor,
      fontSize: 36,
      fontWeight: FontWeight.w300,
      fontStyle: FontStyle.italic,
      height: 1.5,
    );

    textPainter.text = TextSpan(text: '\u201C$text\u201D', style: quoteStyle);
    textPainter.layout(maxWidth: size.width - 160);

    final textTop = (size.height - textPainter.height - 120) / 2;
    textPainter.paint(canvas, const Offset(80, 80));

    final authorStyle = TextStyle(
      color: style.textColor.withValues(alpha: 0.7),
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );

    final authorText = authorName != null ? '$bookTitle — $authorName' : bookTitle;
    textPainter.text = TextSpan(text: authorText, style: authorStyle);
    textPainter.layout(maxWidth: size.width - 160);
    textPainter.paint(canvas, Offset(80, textTop + textPainter.height + 40));

    final linePaint = Paint()
      ..color = style.accentColor
      ..strokeWidth = 3;
    canvas.drawLine(
      const Offset(80, 60),
      Offset(80 + textPainter.width * 0.3, 60),
      linePaint,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }
}

enum ExcerptStyle {
  defaultStyle,
  simple,
  elegant,
  vertical,
}

extension ExcerptStyleExt on ExcerptStyle {
  Color get backgroundColor {
    switch (this) {
      case ExcerptStyle.defaultStyle:
        return const Color(0xFF1A1A2E);
      case ExcerptStyle.simple:
        return Colors.white;
      case ExcerptStyle.elegant:
        return const Color(0xFF0F0F0F);
      case ExcerptStyle.vertical:
        return const Color(0xFF2D1B69);
    }
  }

  Color get textColor {
    switch (this) {
      case ExcerptStyle.defaultStyle:
        return Colors.white;
      case ExcerptStyle.simple:
        return Colors.black87;
      case ExcerptStyle.elegant:
        return const Color(0xFFE0E0E0);
      case ExcerptStyle.vertical:
        return Colors.white;
    }
  }

  Color get accentColor {
    switch (this) {
      case ExcerptStyle.defaultStyle:
        return const Color(0xFFE94560);
      case ExcerptStyle.simple:
        return const Color(0xFF1976D2);
      case ExcerptStyle.elegant:
        return const Color(0xFFCFB53B);
      case ExcerptStyle.vertical:
        return const Color(0xFFBB86FC);
    }
  }
}
