import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../data/book_details_repository_impl.dart';

part 'book_details_screen.g.dart';

@riverpod
Future<BookDetails> bookDetails(Ref ref, String bookId) async {
  final repository = ref.watch(bookDetailsRepositoryProvider);
  return repository.getBookDetails(bookId);
}

class BookDetailsScreen extends ConsumerWidget {
  final String bookId;

  const BookDetailsScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(bookDetailsProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('О книге'),
      ),
      body: detailsAsync.when(
        data: (BookDetails details) => _buildDetails(context, ref, details),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text('Ошибка загрузки: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(bookDetailsProvider(bookId)),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context, WidgetRef ref, BookDetails details) {
    final book = details.book;
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
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
                      child: Icon(
                        Icons.book,
                        size: 48,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  const SizedBox(width: 16),
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
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1),
              const SizedBox(height: 24),
              if (details.availableFormats.isNotEmpty) ...[
                Text(
                  'Доступные форматы',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: details.availableFormats.map((format) {
                    return ActionChip(
                      label: Text(format.name.toUpperCase()),
                      onPressed: () {
                        unawaited(_downloadBook(context, ref, book, format));
                      },
                    );
                  }).toList(),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: 24),
              ],
              if (book.description != null || details.description != null) ...[
                Text(
                  'Описание',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  details.description ?? book.description ?? '',
                  style: theme.textTheme.bodyMedium,
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      unawaited(context.push('/reader/${book.id}'));
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Читать'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: details.availableFormats.isNotEmpty
                      ? () {
                          unawaited(
                            _downloadBook(context, ref, book, details.availableFormats.first),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Скачать'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadBook(
    BuildContext context,
    WidgetRef ref,
    Book book,
    BookFormat format,
  ) async {
    final repository = ref.read(bookDetailsRepositoryProvider);
    try {
      await repository.getDownloadUrl(book.id, format);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Загрузка ${format.name.toUpperCase()} начата'),
            action: SnackBarAction(
              label: 'Открыть',
              onPressed: () {
                unawaited(context.push('/downloads'));
              },
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }
}
