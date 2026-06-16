import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/app_animations.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../data/quote_repository.dart';

final quotesStreamProvider = StreamProvider.family<List<Quote>, String>((ref, bookId) {
  final database = ref.watch(databaseProvider);
  final repository = QuoteRepository(database);
  return repository.watchQuotes(bookId);
});

class QuotesScreen extends ConsumerWidget {
  final String bookId;

  const QuotesScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(quotesStreamProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Цитаты'),
      ),
      body: quotesAsync.when(
        data: (quotes) {
          if (quotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.format_quote,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет цитат',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Выделяйте текст при чтении, чтобы сохранять цитаты',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: () => context.go('/library'),
                    child: const Text('Открыть библиотеку'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: quotes.length,
            itemBuilder: (context, index) {
              final quote = quotes[index];
              return QuoteTile(
                quote: quote,
                onTap: () => _showQuoteDetail(context, ref, quote),
                onDelete: () => _deleteQuote(context, ref, quote),
              ).animate().listTileTransition(delay: (index * 50).ms);
            },
          );
        },
        loading: () => Skeletonizer(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (_, _) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Skeleton.unite(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(BoneMock.name),
                      const SizedBox(height: 8),
                      Text(BoneMock.paragraph),
                      const SizedBox(height: 8),
                      Text(BoneMock.title),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        error: (e, _) => ErrorStateWidget(
          message: 'Не удалось загрузить цитаты',
          details: e.toString(),
          onRetry: () => ref.invalidate(quotesStreamProvider(bookId)),
        ),
      ),
    );
  }

  void _showQuoteDetail(BuildContext context, WidgetRef ref, Quote quote) {
    final controller = TextEditingController(text: quote.note ?? '');
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Цитата'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.selectedText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ваш комментарий...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
            FilledButton(
              onPressed: () {
                final note = controller.text.trim();
                _updateQuoteNote(ref, quote.id, note.isEmpty ? null : note);
                Navigator.of(context).pop();
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateQuoteNote(WidgetRef ref, String id, String? note) {
    final database = ref.read(databaseProvider);
    final repository = QuoteRepository(database);
    unawaited(repository.updateQuote(id: id, note: note));
  }

  Future<void> _deleteQuote(BuildContext context, WidgetRef ref, Quote quote) async {
    final database = ref.read(databaseProvider);
    final repository = QuoteRepository(database);
    await repository.deleteQuote(quote.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Цитата удалена'),
        action: SnackBarAction(
          label: 'Отмена',
          onPressed: () {
            unawaited(repository.insertQuote(quote));
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class QuoteTile extends StatelessWidget {
  final Quote quote;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const QuoteTile({
    super.key,
    required this.quote,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(quote.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить цитату?'),
            content: const Text('Это действие можно отменить'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
      },
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        leading: const Icon(Icons.format_quote),
        title: Text(
          quote.selectedText,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Стр. ${quote.chapterIndex + 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (quote.note != null && quote.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                quote.note!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        isThreeLine: quote.note != null && quote.note!.isNotEmpty,
        onTap: onTap,
      ),
    );
  }
}
