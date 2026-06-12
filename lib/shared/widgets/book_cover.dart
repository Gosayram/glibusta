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
    final coverUrl = book.coverUrl;

    // Try network URL
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

    // Generated placeholder
    return GeneratedBookCover(
      title: book.title,
      author: book.displayAuthor,
      seed: book.id,
    );
  }
}
