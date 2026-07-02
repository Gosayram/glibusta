import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/catalog_cover_cache_service.dart';
import '../models/book.dart';

class BookCoverImage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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

    final cacheService = ref.read(catalogCoverCacheServiceProvider);
    final placeholder = _buildPlaceholder(context);
    final scale = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    final targetWidth = width != null ? (width! * scale).round() : null;
    final targetHeight = height != null ? (height! * scale).round() : null;

    return FutureBuilder<File?>(
      future: cacheService.getCover(book.coverUrl!),
      builder: (context, snapshot) {
        final cachedFile = snapshot.data;
        final imageWidget = Stack(
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
