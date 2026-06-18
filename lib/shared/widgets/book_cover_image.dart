import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/catalog_cover_cache_service.dart';
import '../models/book.dart';

const List<int> _transparentImageBytes = [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  10,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  0,
  1,
  0,
  0,
  5,
  0,
  1,
  13,
  10,
  57,
  60,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

class BookCoverImage extends ConsumerWidget {
  final Book book;
  final double? width;
  final double? height;
  final BoxFit fit;

  const BookCoverImage({
    super.key,
    required this.book,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (book.coverUrl == null || book.coverUrl!.isEmpty) {
      return _buildPlaceholder(context);
    }

    final cacheService = ref.read(catalogCoverCacheServiceProvider);
    final placeholder = _buildPlaceholder(context);
    final scale = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    final targetWidth = width != null ? (width! * scale).round() : null;
    final targetHeight = height != null ? (height! * scale).round() : null;

    return FutureBuilder<File?>(
      future: cacheService.getCover(book.coverUrl!),
      builder: (context, snapshot) {
        final cachedFile = snapshot.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            placeholder,
            if (cachedFile != null)
              Image.file(
                cachedFile,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            else
              FadeInImage(
                placeholder: MemoryImage(
                  Uint8List.fromList(_transparentImageBytes),
                ),
                image: ResizeImage(
                  NetworkImage(book.coverUrl!),
                  width: targetWidth,
                  height: targetHeight,
                ),
                width: width,
                height: height,
                fit: fit,
                imageErrorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colors = _generateColors(book.id);
    final initials = _getInitials();
    final h = height ?? 120;

    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.$1, colors.$2],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            initials,
            style: TextStyle(
              fontSize: (h * 0.3).clamp(12.0, 32.0),
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          if (h > 80) ...[
            SizedBox(height: h * 0.05),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: h * 0.08),
              child: Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: (h * 0.08).clamp(9.0, 13.0),
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static (Color, Color) _generateColors(String id) {
    final hash = md5.convert(utf8.encode(id)).bytes;
    final hue = (hash[0] * 360 / 255).round();
    final baseColor = HSLColor.fromAHSL(
      1.0,
      hue.toDouble(),
      0.55,
      0.45,
    ).toColor();
    final accentColor = HSLColor.fromAHSL(
      1.0,
      (hue + 30) % 360.toDouble(),
      0.5,
      0.35,
    ).toColor();
    return (baseColor, accentColor);
  }

  String _getInitials() {
    final author = book.displayAuthor;
    if (author.isNotEmpty) {
      final parts = author.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return author.substring(0, author.length.clamp(0, 2)).toUpperCase();
    }
    if (book.title.isNotEmpty) {
      return book.title.substring(0, book.title.length.clamp(0, 2)).toUpperCase();
    }
    return '?';
  }
}
