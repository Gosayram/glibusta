import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BookCoverPlaceholder extends StatelessWidget {
  final String bookId;
  final String? title;
  final String? author;
  final double size;

  const BookCoverPlaceholder({
    super.key,
    required this.bookId,
    this.title,
    this.author,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _generateColors(bookId);
    final initials = _getInitials(author, title);

    return Container(
      width: size,
      height: size * 1.4,
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
            style: GoogleFonts.inter(
              fontSize: size * 0.3,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          if (title != null && size > 80) ...[
            SizedBox(height: size * 0.05),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.08),
              child: Text(
                title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: (size * 0.08).clamp(9.0, 13.0),
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
    final accentColor = HSLColor.fromAHSL(1.0, (hue + 30) % 360.toDouble(), 0.5, 0.35).toColor();
    return (baseColor, accentColor);
  }

  static String _getInitials(String? author, String? title) {
    if (author != null && author.isNotEmpty) {
      final parts = author.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return author.substring(0, author.length.clamp(0, 2)).toUpperCase();
    }
    if (title != null && title.isNotEmpty) {
      return title.substring(0, title.length.clamp(0, 2)).toUpperCase();
    }
    return '?';
  }
}
