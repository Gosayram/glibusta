import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/book.dart';

class SelectedBookNotifier extends Notifier<Book?> {
  @override
  Book? build() => null;

  void select(Book? book) => state = book;
}

final selectedBookForPanelProvider = NotifierProvider<SelectedBookNotifier, Book?>(
  SelectedBookNotifier.new,
);

class MacOSRightPanel extends ConsumerWidget {
  const MacOSRightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Book? selectedBook = ref.watch(selectedBookForPanelProvider);
    final theme = Theme.of(context);

    if (selectedBook == null) {
      return SizedBox(
        width: 300,
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Выберите книгу',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 300,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 48),
                child: TabBar(
                  tabs: const [
                    Tab(text: 'О книге'),
                    Tab(text: 'Заметки'),
                    Tab(text: 'Закладки'),
                  ],
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorColor: theme.colorScheme.primary,
                  tabAlignment: TabAlignment.fill,
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _BookDetailsTab(book: selectedBook),
                    const _NotesTab(),
                    const _BookmarksTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookDetailsTab extends StatelessWidget {
  final Book book;
  const _BookDetailsTab({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (book.coverUrl != null)
          Center(
            child: ClipRRect(
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
            ),
          )
        else
          Center(
            child: Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.book, size: 48),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          book.title,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (book.authorIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            book.authorIds.join(', '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (book.description != null) ...[
          const SizedBox(height: 16),
          Text(
            book.description!,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_add_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('Нет заметок', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _BookmarksTab extends StatelessWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('Нет закладок', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
