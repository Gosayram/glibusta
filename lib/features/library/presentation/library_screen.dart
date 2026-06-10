import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../shared/models/book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_drop_zone.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../data/book_import_service.dart';
import '../data/book_repository_impl.dart';

part 'library_screen.g.dart';

@riverpod
Future<List<Book>> libraryBooks(Ref ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getAllBooks();
}

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(libraryBooksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Библиотека'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Импортировать книгу',
            onPressed: () => _importBook(context, ref),
          ),
        ],
      ),
      body: BookDropZone(
        onBooksDropped: (paths) => _handleBooksDropped(ref, paths),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: KeyedSubtree(
            key: ValueKey(
              booksAsync.isLoading
                  ? 'loading'
                  : booksAsync.hasError
                  ? 'error'
                  : 'data_${booksAsync.value?.length ?? 0}',
            ),
            child: booksAsync.when(
              data: (List<Book> books) => _buildBooksGrid(context, ref, books),
              loading: () => Skeletonizer(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: 6,
                  itemBuilder: (_, _) => const Card(
                    child: ListTile(
                      leading: Bone.circle(size: 48),
                      title: Bone.text(words: 3),
                      subtitle: Bone.text(words: 2),
                    ),
                  ),
                ),
              ),
              error: (Object e, _) => ErrorStateWidget(
                message: 'Не удалось загрузить библиотеку',
                details: e.toString(),
                onRetry: () => ref.invalidate(libraryBooksProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBooksDropped(WidgetRef ref, List<String> paths) {
    final service = ref.read(bookImportServiceProvider);
    for (final path in paths) {
      unawaited(
        service.importFile(path).then((result) {
          if (result.isSuccess) {
            ref.invalidate(libraryBooksProvider);
          }
        }),
      );
    }
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['fb2', 'epub'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final service = ref.read(bookImportServiceProvider);
    for (final file in result.files) {
      if (file.path != null) {
        final importResult = await service.importFile(file.path!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                importResult.isSuccess
                    ? 'Импортировано: ${importResult.title}'
                    : importResult.isDuplicate
                    ? 'Дубликат: ${importResult.title}'
                    : 'Ошибка: ${importResult.error}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
    ref.invalidate(libraryBooksProvider);
  }

  Widget _buildBooksGrid(BuildContext context, WidgetRef ref, List<Book> books) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Библиотека пуста', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text(
              'Найдите и скачайте книги, или импортируйте файлы',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => context.go('/catalog'),
              child: const Text('Перейти в каталог'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _importBook(context, ref),
              child: const Text('Импортировать файл'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCard(
          book: book,
          onTap: () => unawaited(context.push('/reader/${book.id}')),
          onLongPress: () => _showBookMenu(context, ref, book),
        );
      },
    );
  }

  void _showBookMenu(BuildContext context, WidgetRef ref, Book book) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: const Text('Читать'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(context.push('/reader/${book.id}'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Скачать'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_add),
                title: const Text('Добавить закладку'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Удалить'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
