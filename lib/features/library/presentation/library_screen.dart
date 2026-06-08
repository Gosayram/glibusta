import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/book.dart';
import '../data/book_repository_impl.dart';

final libraryBooksProvider = FutureProvider<List<Book>>((ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getAllBooks();
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(libraryBooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Библиотека'),
        automaticallyImplyLeading: false,
      ),
      body: booksAsync.when(
        data: (List<Book> books) {
          if (books.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_books, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Библиотека пуста',
                      style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    'Найдите и скачайте книги',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: books.length,
            itemBuilder: (BuildContext context, int index) {
              final book = books[index];
              return LibraryBookTile(book: book);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }
}

class LibraryBookTile extends StatelessWidget {
  final Book book;

  const LibraryBookTile({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: book.coverUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    book.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.book,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                )
              : Icon(
                  Icons.book,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
        ),
        title: Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: book.authorIds.isNotEmpty
            ? Text(
                book.authorIds.join(', '),
                style: theme.textTheme.bodySmall,
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push('/reader/${book.id}');
        },
      ),
    );
  }
}
