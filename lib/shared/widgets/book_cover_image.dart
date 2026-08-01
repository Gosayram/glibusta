import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';


const _palette = [
  Color(0xFF5C6BC0), // indigo
  Color(0xFF26A69A), // teal
  Color(0xFFEF5350), // red
  Color(0xFF42A5F5), // blue
  Color(0xFFAB47BC), // purple
  Color(0xFF66BB6A), // green
  Color(0xFFEC407A), // pink
  Color(0xFFFFA726), // orange
  Color(0xFF78909C), // blue-grey
  Color(0xFF8D6E63), // brown
];

/// Deterministic color from book [title]. Same title always returns same color.
Color deterministicCoverColor(String title) {
  if (title.isEmpty) return _palette.first;
  final index = title.hashCode.abs() % _palette.length;
  return _palette[index];
}

class BookCoverImage extends StatelessWidget {
  final Book book;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool useHero;

  const BookCoverImage({
    super.key,
    required this.book,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.useHero = true,
  });

  @override
  Widget build(BuildContext context) {
    // Priority: local coverPath > HTTP coverUrl > data: URI > placeholder
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      final file = File(book.coverPath!);
      final placeholder = _buildPlaceholder(context);
      final imageWidget = Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      );
      return useHero ? Hero(tag: 'book_cover_${book.id}', child: imageWidget) : imageWidget;
    }

    // coverUrl: only valid for HTTP(S) URLs — skip data: URIs
    final isHttpUrl =
        book.coverUrl != null &&
        book.coverUrl!.isNotEmpty &&
        (book.coverUrl!.startsWith('http://') || book.coverUrl!.startsWith('https://'));

    if (!isHttpUrl) {
      return _buildPlaceholder(context);
    }

    final placeholder = _buildPlaceholder(context);
    final scale = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    final targetWidth = width != null ? (width! * scale).round() : null;
    final targetHeight = height != null ? (height! * scale).round() : null;

    final imageWidget = Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        CachedNetworkImage(
          imageUrl: book.coverUrl!,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: targetWidth,
          memCacheHeight: targetHeight,
          placeholder: (context, url) => const SizedBox.shrink(),
          errorWidget: (context, url, error) => const SizedBox.shrink(),
        ),
      ],
    );

    if (useHero) {
      return Hero(
        tag: 'book_cover_${book.id}',
        child: imageWidget,
      );
    }
    return imageWidget;
  }

  Widget _buildPlaceholder(BuildContext context) {
    final color = deterministicCoverColor(book.title);
    final letter = book.title.isNotEmpty ? book.title[0].toUpperCase() : '?';
    final h = height ?? 120;

    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: (h * 0.4).clamp(16.0, 40.0),
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}
