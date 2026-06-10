import 'package:flutter/material.dart';

import '../models/book.dart';
import 'book_card.dart';

class BookGrid extends StatelessWidget {
  final List<Book> books;
  final Map<String, bool>? downloadStatus;
  final Map<String, double>? progress;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final Widget? emptyState;
  final bool showProgress;
  final Axis scrollDirection;

  const BookGrid({
    super.key,
    required this.books,
    this.downloadStatus,
    this.progress,
    this.physics,
    this.controller,
    this.emptyState,
    this.showProgress = false,
    this.scrollDirection = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty && emptyState != null) {
      return emptyState!;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      controller: controller,
      physics: physics,
      scrollDirection: scrollDirection,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.58,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCard(
          key: ValueKey(book.id),
          book: book,
          isDownloaded: downloadStatus?[book.id],
          progress: showProgress && progress != null ? progress![book.id] : null,
        );
      },
    );
  }
}
