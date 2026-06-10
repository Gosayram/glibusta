import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/book_card.dart';
import 'smart_collections_provider.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(smartCollectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Коллекции'),
        automaticallyImplyLeading: false,
      ),
      body: collectionsAsync.when(
        data: (collections) {
          final nonEmpty = collections.where((c) => !c.isEmpty).toList();
          if (nonEmpty.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.collections_bookmark_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет книг в библиотеке',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте книги, чтобы увидеть автоматические коллекции',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: nonEmpty.length,
            itemBuilder: (context, index) {
              final collection = nonEmpty[index];
              return _SmartCollectionSection(
                collection: collection,
                onBookTap: (bookId) => unawaited(context.push('/reader/$bookId')),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Ошибка: $e'),
        ),
      ),
    );
  }
}

class _SmartCollectionSection extends StatelessWidget {
  final SmartCollection collection;
  final void Function(String bookId) onBookTap;

  const _SmartCollectionSection({
    required this.collection,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              collection.type.icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              collection.type.label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${collection.books.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: collection.books.length,
            itemBuilder: (context, index) {
              final book = collection.books[index];
              return SizedBox(
                width: 120,
                child: BookCard(
                  key: ValueKey(book.id),
                  book: book,
                  onTap: () => onBookTap(book.id),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
