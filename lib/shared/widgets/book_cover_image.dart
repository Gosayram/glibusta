import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';

class BookCoverImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (book.coverUrl != null) {
      return Image.network(
        book.coverUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _buildPlaceholder(context),
      );
    }
    return _buildPlaceholder(context);
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
    final baseColor = HSLColor.fromAHSL(1.0, hue.toDouble(), 0.55, 0.45).toColor();
    final accentColor = HSLColor.fromAHSL(
      1.0,
      (hue + 30) % 360.toDouble(),
      0.5,
      0.35,
    ).toColor();
    return (baseColor, accentColor);
  }

  String _getInitials() {
    if (book.authorIds.isNotEmpty) {
      final name = book.authorIds.first;
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
    }
    if (book.title.isNotEmpty) {
      return book.title.substring(0, book.title.length.clamp(0, 2)).toUpperCase();
    }
    return '?';
  }
}
