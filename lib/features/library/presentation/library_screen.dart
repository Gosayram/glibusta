import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../shared/models/book.dart';
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

    return FutureBuilder<Map<String, dynamic>>(
      future: _getBookStatusData(ref, books),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Skeletonizer(
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
          );
        }
        final progressMap = snapshot.data!['progress'] as Map<String, double>;
        final downloadedMap = snapshot.data!['downloaded'] as Map<String, bool>;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            // Determine grid layout based on width
            if (width < AppBreakpoints.compact) {
              // Phone: 2 columns
              return _buildGridView(context, books, progressMap, downloadedMap, crossAxisCount: 2);
            } else if (width < AppBreakpoints.expanded) {
              // Tablet: 3 columns
              return _buildGridView(context, books, progressMap, downloadedMap, crossAxisCount: 3);
            } else {
              // Desktop: adaptive card width
              return _buildDesktopGridView(context, books, progressMap, downloadedMap);
            }
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getBookStatusData(WidgetRef ref, List<Book> books) async {
    final bookIds = books.map((book) => book.id).toList();
    final database = ref.read(databaseProvider);

    final progressMap = <String, double>{};
    final downloadedMap = <String, bool>{};

    if (bookIds.isNotEmpty) {
      // Get reading progress for all books
      final progressRows = await (database.select(
        database.readingProgress,
      )..where((t) => t.bookId.isIn(bookIds))).get();
      for (final row in progressRows) {
        if (row.totalPages > 0) {
          progressMap[row.bookId] = row.currentPosition / row.totalPages;
        } else {
          progressMap[row.bookId] = 0.0;
        }
      }

      // Get download status for all books
      final downloadRows = await (database.select(
        database.downloads,
      )..where((t) => t.bookId.isIn(bookIds))).get();
      for (final row in downloadRows) {
        // Consider a book downloaded if status is completed
        downloadedMap[row.bookId] = row.status == DownloadStatusDb.completed;
      }
    }

    return {'progress': progressMap, 'downloaded': downloadedMap};
  }

  Widget _buildGridView(
    BuildContext context,
    List<Book> books,
    Map<String, double> progressMap,
    Map<String, bool> downloadedMap, {
    required int crossAxisCount,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return LibraryBookTile(
          book: book,
          progress: progressMap[book.id],
          isDownloaded: downloadedMap[book.id],
        );
      },
    );
  }

  Widget _buildDesktopGridView(
    BuildContext context,
    List<Book> books,
    Map<String, double> progressMap,
    Map<String, bool> downloadedMap,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return LibraryBookTile(
          book: book,
          progress: progressMap[book.id],
          isDownloaded: downloadedMap[book.id],
        );
      },
    );
  }
}

class LibraryBookTile extends ConsumerWidget {
  final Book book;
  final double? progress; // 0.0 to 1.0
  final bool? isDownloaded; // true if downloaded, false if not, null if unknown

  const LibraryBookTile({
    super.key,
    required this.book,
    this.progress,
    this.isDownloaded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Stack(
            children: [
              Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: book.coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Semantics(
                          label: 'Обложка: ${book.title}',
                          child: Image.network(
                            book.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.book,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.book,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
              ),
              // Progress indicator
              if (progress != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                      color: progress == 1.0
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                    ),
                    width: progress! * 48, // 48 is the width of the container
                  ),
                ),
              // Download status indicator
              if (isDownloaded == true)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.download_done,
                    size: 16,
                    color: Colors.green,
                  ),
                )
              else if (isDownloaded == false)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.cloud_download_outlined,
                    size: 16,
                    color: Colors.blue,
                  ),
                ),
            ],
          ),
          title: Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            semanticsLabel: book.title,
          ),
          subtitle: book.authorIds.isNotEmpty
              ? Text(
                  book.authorIds.join(', '),
                  style: theme.textTheme.bodySmall,
                )
              : null,
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'read', child: Text('Читать')),
              const PopupMenuItem(value: 'download', child: Text('Скачать')),
              const PopupMenuItem(value: 'bookmark', child: Text('Добавить закладку')),
              const PopupMenuItem(value: 'delete', child: Text('Удалить')),
            ],
          ),
          onTap: () {
            unawaited(context.push('/reader/${book.id}'));
          },
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'read':
        unawaited(context.push('/reader/${book.id}'));
      case 'download':
      // TODO: Implement download
      case 'bookmark':
      // TODO: Implement bookmark
      case 'delete':
      // TODO: Implement delete
    }
  }
}
