import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/platform/adaptive_context.dart';
import '../../../core/platform/file_picker_service.dart';
import '../../../shared/models/book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover_image.dart';
import '../../../shared/widgets/book_drop_zone.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/library_master_detail.dart';
import '../data/book_import_service.dart';
import '../data/book_repository_impl.dart';
import 'library_view_mode_provider.dart';
import 'pinned_books_provider.dart';

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
            icon: Icon(
              _viewModeIcon(
                switch (ref.watch(libraryViewModeProvider)) {
                  AsyncData(:final value) => value,
                  _ => LibraryViewMode.grid,
                },
              ),
            ),
            tooltip: 'Вид',
            onPressed: () => ref.read(libraryViewModeProvider.notifier).cycle(),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Импортировать папку',
            onPressed: () => _importFolder(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Импортировать книгу',
            onPressed: () => _importBook(context, ref),
          ),
        ],
      ),
      body: BookDropZone(
        onBooksDropped: (paths) => _handleBooksDropped(ref, paths),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(libraryBooksProvider);
          },
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
      ),
    );
  }

  IconData _viewModeIcon(LibraryViewMode mode) {
    switch (mode) {
      case LibraryViewMode.grid:
        return Icons.grid_view;
      case LibraryViewMode.list:
        return Icons.view_list;
      case LibraryViewMode.compact:
        return Icons.view_compact;
    }
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
    final picker = BookFilePicker();
    final filePath = await picker.pickBookFile();
    if (filePath == null) return;

    final service = ref.read(bookImportServiceProvider);
    final importResult = await service.importFile(filePath);
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
    ref.invalidate(libraryBooksProvider);
  }

  Future<void> _importFolder(BuildContext context, WidgetRef ref) async {
    final picker = BookFilePicker();
    final dirPath = await picker.pickDirectory();
    if (dirPath == null) return;

    final service = ref.read(bookImportServiceProvider);
    final batchResult = await service.importDirectory(dirPath);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Импортировано: ${batchResult.successCount}, '
            'дубликатов: ${batchResult.duplicateCount}, '
            'ошибок: ${batchResult.failureCount}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    ref.invalidate(libraryBooksProvider);
  }

  Widget _buildBooksGrid(BuildContext context, WidgetRef ref, List<Book> books) {
    if (books.isEmpty) {
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: child,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Библиотека пуста',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Найдите и скачайте книги, или импортируйте файлы',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
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
        ),
      );
    }

    if (context.isCompact) {
      // Phone: fall through to grid view below
    } else {
      return LibraryMasterDetail(books: books);
    }

    final pinnedIds = switch (ref.watch(pinnedBooksProvider)) {
      AsyncData(:final value) => value,
      _ => <String>[],
    };
    final pinnedBooksList = books.where((b) => pinnedIds.contains(b.id)).toList();
    final unpinnedBooks = books.where((b) => !pinnedIds.contains(b.id)).toList();

    return _RestorableCustomScrollView(
      restorationId: 'library-books-scroll',
      slivers: [
        // Pinned section
        if (pinnedBooksList.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Icon(
                    Icons.push_pin,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Закреплённые',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = pinnedBooksList[index];
                  return BookCard(
                    key: ValueKey(book.id),
                    book: book,
                    onTap: () => unawaited(context.push('/reader/${book.id}')),
                    onLongPress: () => _showBookMenu(context, ref, book),
                  );
                },
                childCount: pinnedBooksList.length,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
        ],
        // All books section
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Text(
              pinnedBooksList.isNotEmpty ? 'Все книги' : '',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _buildBookSliver(context, ref, unpinnedBooks),
        ),
      ],
    );
  }

  Widget _buildBookSliver(BuildContext context, WidgetRef ref, List<Book> books) {
    final viewMode = switch (ref.watch(libraryViewModeProvider)) {
      AsyncData(:final value) => value,
      _ => LibraryViewMode.grid,
    };
    switch (viewMode) {
      case LibraryViewMode.grid:
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => BookCard(
              key: ValueKey(books[index].id),
              book: books[index],
              onTap: () => unawaited(context.push('/reader/${books[index].id}')),
              onLongPress: () => _showBookMenu(context, ref, books[index]),
            ),
            childCount: books.length,
          ),
        );
      case LibraryViewMode.list:
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final book = books[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: SizedBox(
                    width: 48,
                    height: 68,
                    child: BookCoverImage(book: book),
                  ),
                  title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: book.authorIds.isNotEmpty ? Text(book.authorIds.join(', ')) : null,
                  onTap: () => unawaited(context.push('/reader/${book.id}')),
                  onLongPress: () => _showBookMenu(context, ref, book),
                ),
              );
            },
            childCount: books.length,
          ),
        );
      case LibraryViewMode.compact:
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.55,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => BookCard(
              key: ValueKey(books[index].id),
              book: books[index],
              onTap: () => unawaited(context.push('/reader/${books[index].id}')),
              onLongPress: () => _showBookMenu(context, ref, books[index]),
            ),
            childCount: books.length,
          ),
        );
    }
  }

  void _showBookMenu(BuildContext context, WidgetRef ref, Book book) {
    final pinnedState = ref.read(pinnedBooksProvider.notifier);
    final isPinned = pinnedState.isPinned(book.id);

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
                leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                title: Text(isPinned ? 'Открепить' : 'Закрепить'),
                subtitle: isPinned ? null : const Text('Максимум 5 книг'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(pinnedState.toggle(book.id));
                },
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

class _RestorableCustomScrollView extends StatefulWidget {
  final String restorationId;
  final List<Widget> slivers;

  const _RestorableCustomScrollView({
    required this.restorationId,
    required this.slivers,
  });

  @override
  State<_RestorableCustomScrollView> createState() => _RestorableCustomScrollViewState();
}

class _RestorableCustomScrollViewState extends State<_RestorableCustomScrollView>
    with RestorationMixin {
  final RestorableDouble _offset = RestorableDouble(0);
  ScrollController? _controller;

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool restoredFromOldBucket) {
    registerForRestoration(_offset, 'scroll_offset');
  }

  @override
  void dispose() {
    _controller?.removeListener(_saveOffset);
    _controller?.dispose();
    _offset.dispose();
    super.dispose();
  }

  ScrollController _getController() {
    _controller ??= ScrollController(
      initialScrollOffset: _offset.value,
      keepScrollOffset: false,
    )..addListener(_saveOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
    return _controller!;
  }

  void _saveOffset() {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    _offset.value = controller.position.pixels;
  }

  void _restoreOffset() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.hasClients) return;
    final maxOffset = controller.position.maxScrollExtent;
    final offset = _offset.value.clamp(0.0, maxOffset);
    if (offset > 0 && (controller.position.pixels - offset).abs() > 1) {
      controller.jumpTo(offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(controller: _getController(), slivers: widget.slivers);
  }
}
