import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/book.dart';

class LibraryMasterDetail extends StatefulWidget {
  final List<Book> books;

  const LibraryMasterDetail({super.key, required this.books});

  @override
  State<LibraryMasterDetail> createState() => _LibraryMasterDetailState();
}

class _LibraryMasterDetailState extends State<LibraryMasterDetail> {
  Book? _selectedBook;

  @override
  void didUpdateWidget(LibraryMasterDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedBook != null) {
      final stillExists = widget.books.any((b) => b.id == _selectedBook!.id);
      if (!stillExists) {
        _selectedBook = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: _buildBookList(context),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedBook != null
              ? _buildBookDetail(context, _selectedBook!)
              : _buildEmptyState(context),
        ),
      ],
    );
  }

  Widget _buildBookList(BuildContext context) {
    if (widget.books.isEmpty) {
      return Center(
        child: Text(
          'Библиотека пуста',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.books.length,
      itemBuilder: (context, index) {
        final book = widget.books[index];
        final isSelected = _selectedBook?.id == book.id;
        return ListTile(
          leading: book.coverUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    book.coverUrl!,
                    width: 40,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 40,
                      height: 56,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.book, size: 20),
                    ),
                  ),
                )
              : Container(
                  width: 40,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.book, size: 20),
                ),
          title: Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: book.authorIds.isNotEmpty
              ? Text(
                  book.authorIds.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : null,
          selected: isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          onTap: () => setState(() => _selectedBook = book),
        );
      },
    );
  }

  Widget _buildBookDetail(BuildContext context, Book book) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.coverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  book.coverUrl!,
                  width: 120,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 120,
                    height: 180,
                    color: theme.colorScheme.primaryContainer,
                    child: const Icon(Icons.book, size: 48),
                  ),
                ),
              )
            else
              Container(
                width: 120,
                height: 180,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.book, size: 48),
              ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (book.authorIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      book.authorIds.join(', '),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                  if (book.publishDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      book.publishDate!.year.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          unawaited(context.push('/reader/${book.id}'));
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Читать'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          unawaited(context.push('/book/${book.id}'));
                        },
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Подробнее'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (book.description != null) ...[
          const SizedBox(height: 24),
          Text(
            'Описание',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            book.description!,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Выберите книгу',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
