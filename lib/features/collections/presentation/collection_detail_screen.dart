import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/book_card.dart';
import 'user_collections_provider.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({required this.collectionId, super.key});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionProvider(collectionId));
    return collection.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Ошибка: $error'))),
      data: (value) => Scaffold(
        appBar: AdaptiveAppBar(title: Text(value?.name ?? 'Коллекция')),
        body: value == null
            ? const Center(child: Text('Коллекция не найдена'))
            : _CollectionBooks(collectionId: collectionId),
      ),
    );
  }
}

class _CollectionBooks extends ConsumerWidget {
  const _CollectionBooks({required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(collectionBooksProvider(collectionId));
    return books.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Ошибка: $error')),
      data: (items) {
        if (items.isEmpty) return const Center(child: Text('В коллекции пока нет книг'));
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .58,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _CollectionBookCard(
            book: items[index],
            collectionId: collectionId,
          ),
        );
      },
    );
  }
}

class _CollectionBookCard extends ConsumerWidget {
  const _CollectionBookCard({required this.book, required this.collectionId});

  final Book book;
  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        Positioned.fill(
          child: BookCard(book: book, onTap: () => context.push('/reader/${book.id}')),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filledTonal(
            tooltip: 'Удалить из коллекции',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _remove(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить из коллекции?'),
        content: Text('«${book.title}» останется в библиотеке.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(databaseProvider).collectionDao.removeBookFromCollection(book.id, collectionId);
    ref
      ..invalidate(collectionBooksProvider(collectionId))
      ..invalidate(userCollectionsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Книга удалена из коллекции')));
    }
  }
}
