import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';
import 'generated_book_cover.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    required this.book,
    this.width,
    this.height,
    super.key,
  });

  final Book book;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final coverPath = book.coverPath;
    if (coverPath != null && coverPath.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 2 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(coverPath),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildNetworkOrGenerated(),
          ),
        ),
      );
    }
    return _buildNetworkOrGenerated();
  }

  Widget _buildNetworkOrGenerated() {
    final coverUrl = book.coverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty && coverUrl != 'embedded') {
      return AspectRatio(
        aspectRatio: 2 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            coverUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => GeneratedBookCover(
              title: book.title,
              author: book.displayAuthor,
              seed: book.id,
            ),
          ),
        ),
      );
    }
    return GeneratedBookCover(
      title: book.title,
      author: book.displayAuthor,
      seed: book.id,
    );
  }
}
