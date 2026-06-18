import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/platform/adaptive_context.dart';
import '../../../core/platform/file_picker_service.dart';
import '../../../core/services/background_task_provider.dart';
import '../../../core/services/tag_service.dart';
import '../../../core/services/task_queue_service.dart';
import '../../../shared/models/book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover_image.dart';
import '../../../shared/widgets/book_drop_zone.dart';
import '../../../shared/widgets/delete_book_dialog.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/library_master_detail.dart';
import '../../reader/data/per_book_settings_service.dart';
import '../data/book_delete_service.dart';
import '../data/book_import_service.dart';
import '../data/book_repository_impl.dart';
import '../data/inspectors/book_inspection_provider.dart';
import '../data/inspectors/book_inspection_result.dart';
import 'library_view_mode_provider.dart';
import 'pinned_books_provider.dart';

part 'library_screen.g.dart';

@riverpod
Future<List<Book>> libraryBooks(Ref ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getAllBooks();
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isSearchOpen = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(libraryBooksProvider);
    final runningTasks = ref.watch(backgroundTaskProvider.notifier).running;

    return Scaffold(
      appBar: AppBar(
        title: _isSearchOpen
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск в библиотеке...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              )
            : const Text('Библиотека'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
            tooltip: _isSearchOpen ? 'Закрыть поиск' : 'Поиск',
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _searchFocusNode.requestFocus();
                }
              });
            },
          ),
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
            icon: const Icon(Icons.add),
            tooltip: 'Добавить книги',
            onPressed: () => _showImportSheet(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          if (runningTasks.isNotEmpty)
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          Expanded(
            child: BookDropZone(
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
                      data: (List<Book> books) {
                        final query = _searchQuery.toLowerCase();
                        final filtered = query.isEmpty
                            ? books
                            : books.where((b) {
                                final titleMatch = b.title.toLowerCase().contains(query);
                                final authorMatch = b.displayAuthor.toLowerCase().contains(query);
                                final descMatch =
                                    b.description?.toLowerCase().contains(query) ?? false;
                                return titleMatch || authorMatch || descMatch;
                              }).toList();
                        return _buildBooksGrid(context, ref, filtered);
                      },
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
                          itemBuilder: (_, _) => Card(
                            child: ListTile(
                              leading: const Bone.circle(size: 48),
                              title: Text(BoneMock.name),
                              subtitle: Text(BoneMock.subtitle),
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
          ),
        ],
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
    try {
      final service = ref.read(bookImportServiceProvider);
      for (final path in paths) {
        unawaited(_inspectAndImport(ref, path, service));
      }
    } on Object catch (e) {
      AppLogger().warning('Import failed: $e', name: 'Library', error: e);
    }
  }

  Future<void> _inspectAndImport(
    WidgetRef ref,
    String path,
    BookImportService service,
  ) async {
    try {
      final inspection = await ref.read(bookFileInspectionProvider(path).future);
      final result = await ref
          .read(taskQueueProvider)
          .run<ImportResult>(
            type: BackgroundTaskType.import,
            message: 'Импорт: ${inspection.title ?? path.split('/').last}',
            task: () => service.importFromInspection(inspection),
          );
      if (result.isSuccess || result.needsEncodingSelection) {
        ref.invalidate(libraryBooksProvider);
      }
    } on Object catch (e) {
      AppLogger().warning('Import failed: $e', name: 'Library', error: e);
    }
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    try {
      final picker = BookFilePicker();
      final filePath = await picker.pickBookFile();
      if (filePath == null) return;

      final inspection = await ref.read(bookFileInspectionProvider(filePath).future);

      if (inspection.decision == ImportDecision.duplicate) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Дубликат: ${inspection.title ?? inspection.reason}')),
          );
        }
        return;
      }

      if (inspection.decision == ImportDecision.corrupted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${inspection.reason}')),
          );
        }
        return;
      }

      if (inspection.decision == ImportDecision.unsupported) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Формат не поддерживается')),
          );
        }
        return;
      }

      final service = ref.read(bookImportServiceProvider);
      final importResult = await ref
          .read(taskQueueProvider)
          .run<ImportResult>(
            type: BackgroundTaskType.import,
            message: 'Импорт: ${inspection.title ?? filePath.split('/').last}',
            task: () => service.importFromInspection(inspection),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              importResult.isSuccess
                  ? 'Импортировано: ${importResult.title}'
                  : importResult.needsEncodingSelection
                  ? 'Нужен выбор кодировки'
                  : 'Ошибка: ${importResult.error}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      ref.invalidate(libraryBooksProvider);
    } on Object catch (e) {
      AppLogger().warning('Import failed: $e', name: 'Library', error: e);
    }
  }

  Future<void> _importFolder(BuildContext context, WidgetRef ref) async {
    try {
      final picker = BookFilePicker();
      final dirPath = await picker.pickDirectory();
      if (dirPath == null) return;

      final service = ref.read(bookImportServiceProvider);
      final batchResult = await ref
          .read(taskQueueProvider)
          .run<ImportBatchResult>(
            type: BackgroundTaskType.directoryScan,
            message: 'Импорт папки...',
            task: () => service.importDirectory(dirPath),
          );
      if (context.mounted) {
        _showImportSummaryDialog(context, batchResult);
      }
      ref.invalidate(libraryBooksProvider);
    } on Object catch (e) {
      AppLogger().warning('Import failed: $e', name: 'Library', error: e);
    }
  }

  void _showImportSummaryDialog(BuildContext context, ImportBatchResult batch) {
    final failures = batch.failures;
    final hasErrors = failures.isNotEmpty;
    final hasCircuitBroken = batch.circuitBroken;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            hasCircuitBroken
                ? Icons.warning_amber_rounded
                : hasErrors
                ? Icons.info_outline
                : Icons.check_circle_outline,
            color: hasCircuitBroken
                ? Theme.of(ctx).colorScheme.error
                : hasErrors
                ? Theme.of(ctx).colorScheme.secondary
                : Theme.of(ctx).colorScheme.primary,
            size: 32,
          ),
          title: Text(
            hasCircuitBroken
                ? 'Импорт приостановлен'
                : hasErrors
                ? 'Импорт завершён с ошибками'
                : 'Импорт завершён',
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow(
                  Icons.check,
                  'Импортировано',
                  '${batch.successCount}',
                  Theme.of(ctx).colorScheme.primary,
                ),
                _summaryRow(
                  Icons.copy,
                  'Дубликатов',
                  '${batch.duplicateCount}',
                  Theme.of(ctx).colorScheme.secondary,
                ),
                if (hasErrors)
                  _summaryRow(
                    Icons.error_outline,
                    'Ошибок',
                    '${batch.failureCount}',
                    Theme.of(ctx).colorScheme.error,
                  ),
                if (hasCircuitBroken) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Импорт остановлен после 3 ошибок подряд. '
                    'Возможно, повреждённые файлы или неподдерживаемый формат.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.error,
                    ),
                  ),
                ],
                if (hasErrors) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Ошибки:',
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  ...failures
                      .take(5)
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '  ${f.path.split('/').last}: ${f.result.error ?? "неизвестная ошибка"}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  if (failures.length > 5)
                    Text(
                      '  ... и ещё ${failures.length - 5}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  void _showImportSheet(BuildContext context, WidgetRef ref) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Добавить книги',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.file_open),
                title: const Text('Файлы'),
                subtitle: const Text('EPUB, FB2, TXT'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_importBook(context, ref));
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Папка'),
                subtitle: const Text('Все книги из папки'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_importFolder(context, ref));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
                onPressed: () => context.push('/catalog'),
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
                  subtitle: book.authorNames.isNotEmpty ? Text(book.authorNames.join(', ')) : null,
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
                leading: const Icon(Icons.info_outline),
                title: const Text('Подробности'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(context.push('/book/${book.id}'));
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
                leading: const Icon(Icons.label_outline),
                title: const Text('Теги'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTagPicker(context, ref, book);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Переместить в папку'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFolderPicker(context, ref, book);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Поделиться'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareBook(context, book);
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Сбросить настройки чтения'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final svc = ref.read(perBookSettingsServiceProvider);
                  await svc.resetToGlobal(book.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Настройки сброшены')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Удалить'),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_confirmDelete(context, ref, book));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagPicker(BuildContext context, WidgetRef ref, Book book) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TagPickerSheet(book: book),
    );
  }

  void _showFolderPicker(BuildContext context, WidgetRef ref, Book book) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Выбор папки将在 реализован')),
    );
  }

  void _shareBook(BuildContext context, Book book) {
    if (book.source.sourceUrl.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Поделиться «${book.title}»')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Book book) async {
    final result = await DeleteBookDialog.show(context, bookTitle: book.title);
    if (result == null || !context.mounted) return;

    final service = ref.read(bookDeleteServiceProvider);
    if (result.deleteFile) {
      await service.deleteBookCompletely(book.id);
    } else {
      await service.removeFromLibrary(book.id);
    }
    ref.invalidate(libraryBooksProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.deleteFile
                ? '«${book.title}» удалена с диска'
                : '«${book.title}» удалена из списка',
          ),
        ),
      );
    }
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
    if (_controller != null) return _controller!;
    _controller = ScrollController(
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

class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet({required this.book});

  final Book book;

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  late Set<String> _selectedTagIds;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = {};
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tagService = ref.read<TagService>(tagServiceProvider);
    final bookTags = await tagService.getTagsForBook(widget.book.id);
    if (mounted) {
      setState(() {
        _selectedTagIds = bookTags.map((t) => t.id).toSet();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(allTagsProvider);

    return DraggableScrollableSheet(
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scrollController) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Теги',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tagsAsync.when(
                data: (tags) {
                  if (tags.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.label_off, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Нет тегов'),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.push('/settings/tags');
                            },
                            child: const Text('Создать тег'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: tags.length,
                    itemBuilder: (_, index) {
                      final tag = tags[index];
                      final isSelected = _selectedTagIds.contains(tag.id);
                      return CheckboxListTile(
                        secondary: CircleAvatar(
                          backgroundColor: _parseColor(tag.color),
                          radius: 12,
                        ),
                        title: Text(tag.name),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedTagIds.add(tag.id);
                            } else {
                              _selectedTagIds.remove(tag.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка: $e')),
              ),
            ),
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _saveTags(ctx),
                    child: const Text('Сохранить'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTags(BuildContext ctx) async {
    final tagService = ref.read(tagServiceProvider);
    await tagService.setBookTags(widget.book.id, _selectedTagIds.toList());
    if (ctx.mounted) {
      Navigator.pop(ctx);
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Теги сохранены')),
      );
    }
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }
}
