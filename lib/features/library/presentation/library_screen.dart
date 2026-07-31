import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/file_picker_service.dart';
import '../../../core/services/background_task_provider.dart';
import '../../../core/services/tag_service.dart';
import '../../../core/services/task_queue_service.dart';
import '../../../shared/models/book.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover_image.dart';
import '../../../shared/widgets/book_drop_zone.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/restorable_scroll_view.dart';
import '../data/book_data_export.dart';
import '../data/book_delete_service.dart';
import '../data/book_import_service.dart';
import '../data/book_repository_impl.dart';
import '../data/inspectors/book_inspection_provider.dart';
import '../data/inspectors/book_inspection_result.dart';
import 'library_sort.dart';
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
  LibrarySort _sort = LibrarySort.recentlyAdded;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Set<String> _selectedBookIds = {};

  bool get _selectionMode => _selectedBookIds.isNotEmpty;

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
      appBar: _selectionMode ? _buildSelectionAppBar(ref) : _buildNormalAppBar(ref),
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
                        return _buildBooksGrid(context, ref, sortLibraryBooks(filtered, _sort));
                      },
                      loading: () => Skeletonizer.zone(
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

  PreferredSizeWidget _buildNormalAppBar(WidgetRef ref) {
    return AppBar(
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
        PopupMenuButton<LibrarySort>(
          icon: const Icon(Icons.sort),
          tooltip: 'Сортировка: ${_sort.label}',
          initialValue: _sort,
          onSelected: (sort) => setState(() => _sort = sort),
          itemBuilder: (context) => [
            for (final sort in LibrarySort.values)
              CheckedPopupMenuItem(
                value: sort,
                checked: sort == _sort,
                child: Text(sort.label),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Добавить книги',
          onPressed: () => _showImportSheet(context, ref),
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(WidgetRef ref) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Отмена',
        onPressed: _exitSelectionMode,
      ),
      title: Text('${_selectedBookIds.length} выбрано'),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: 'Выбрать все',
          onPressed: _selectAllBooks,
        ),
        IconButton(
          icon: const Icon(Icons.upload_file),
          tooltip: 'Экспорт данных',
          onPressed: () => _batchExport(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Удалить',
          onPressed: () => _batchDelete(context, ref),
        ),
      ],
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

  void _enterSelectionMode(String bookId) {
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _selectedBookIds.add(bookId));
  }

  void _toggleSelection(String bookId) {
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() => _selectedBookIds.clear());
  }

  void _selectAllBooks() {
    final booksAsync = ref.read(libraryBooksProvider);
    final books = switch (booksAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (books == null) return;
    setState(() {
      _selectedBookIds
        ..clear()
        ..addAll(books.map((Book b) => b.id));
    });
  }

  Future<void> _batchDelete(BuildContext context, WidgetRef ref) async {
    final count = _selectedBookIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить $count ${_pluralBooks(count)}?'),
        content: const Text('Книги будут удалены из библиотеки'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final service = ref.read(bookDeleteServiceProvider);
    final ids = _selectedBookIds.toList();
    _exitSelectionMode();
    for (final id in ids) {
      await service.removeFromLibrary(id);
    }
    ref.invalidate(libraryBooksProvider);
    if (context.mounted) {
      unawaited(SmartDialog.showToast('$count ${_pluralBooks(count)} удалено'));
    }
  }

  Future<void> _batchExport(BuildContext context, WidgetRef ref) async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Формат экспорта'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'json'),
            child: const Text('JSON'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'txt'),
            child: const Text('TXT'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'md'),
            child: const Text('Markdown'),
          ),
        ],
      ),
    );
    if (format == null || !context.mounted) return;

    final db = ref.read(databaseProvider);
    final booksAsync = ref.read(libraryBooksProvider);
    final allBooks = switch (booksAsync) {
      AsyncData(:final value) => value,
      _ => <Book>[],
    };
    final selectedBooks = allBooks.where((Book b) => _selectedBookIds.contains(b.id)).toList();

    final allHighlights = <TextHighlight>[];
    final allBookmarks = <Bookmark>[];
    final allNotes = <Note>[];

    for (final book in selectedBooks) {
      final highlights = await db.highlightDao.getHighlightsForBook(book.id);
      final bookmarks = await (db.select(
        db.bookmarks,
      )..where((b) => b.bookId.equals(book.id))).get();
      final notes = await (db.select(
        db.notes,
      )..where((n) => n.bookId.equals(book.id))).get();
      allHighlights.addAll(highlights);
      allBookmarks.addAll(bookmarks);
      allNotes.addAll(notes);
    }

    if (allHighlights.isEmpty && allBookmarks.isEmpty && allNotes.isEmpty) {
      if (context.mounted) {
        unawaited(SmartDialog.showToast('Нет данных для экспорта'));
      }
      return;
    }

    final tmpDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    late final File file;

    if (format == 'txt') {
      final content = buildBookExportTxt(
        bookTitle: selectedBooks.map((b) => b.title).join(', '),
        highlights: allHighlights,
        bookmarks: allBookmarks,
        notes: allNotes,
      );
      file = File('${tmpDir.path}/glibusta_batch_export_$ts.txt');
      await file.writeAsString(content);
    } else if (format == 'md') {
      final content = buildBookExportMarkdown(
        bookTitle: selectedBooks.map((b) => b.title).join(', '),
        highlights: allHighlights,
        bookmarks: allBookmarks,
        notes: allNotes,
      );
      file = File('${tmpDir.path}/glibusta_batch_export_$ts.md');
      await file.writeAsString(content);
    } else {
      final jsonMap = {
        'books': selectedBooks.map((b) => b.title).toList(),
        'exported_at': DateTime.now().toIso8601String(),
        'highlights_count': allHighlights.length,
        'bookmarks_count': allBookmarks.length,
        'notes_count': allNotes.length,
        'highlights': allHighlights
            .map(
              (h) => {
                'book_id': h.bookId,
                'selected_text': h.selectedText,
                'color': h.color,
                'note': h.noteText,
                'created_at': h.createdAt.toIso8601String(),
              },
            )
            .toList(),
        'bookmarks': allBookmarks
            .map(
              (b) => {
                'book_id': b.bookId,
                'chapter_index': b.chapterIndex,
                'selected_text': b.selectedText,
                'note': b.note,
                'created_at': b.createdAt.toIso8601String(),
              },
            )
            .toList(),
        'notes': allNotes
            .map(
              (n) => {
                'book_id': n.bookId,
                'content': n.content,
                'created_at': n.createdAt.toIso8601String(),
              },
            )
            .toList(),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonMap);
      file = File('${tmpDir.path}/glibusta_batch_export_$ts.json');
      await file.writeAsString(jsonStr);
    }

    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Экспорт данных: ${selectedBooks.length} книг',
      ),
    );
    _exitSelectionMode();
  }

  String _pluralBooks(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'книга';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'книги';
    }
    return 'книг';
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
          unawaited(SmartDialog.showToast('Дубликат: ${inspection.title ?? inspection.reason}'));
        }
        return;
      }

      if (inspection.decision == ImportDecision.corrupted) {
        if (context.mounted) {
          unawaited(SmartDialog.showToast('Ошибка: ${inspection.reason}'));
        }
        return;
      }

      if (inspection.decision == ImportDecision.unsupported) {
        if (context.mounted) {
          unawaited(SmartDialog.showToast('Формат не поддерживается'));
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
        unawaited(
          SmartDialog.showToast(
            importResult.isSuccess
                ? 'Импортировано: ${importResult.title}'
                : importResult.needsEncodingSelection
                ? 'Нужен выбор кодировки'
                : 'Ошибка: ${importResult.error}',
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
              onPressed: () {
                final shell = StatefulNavigationShell.of(context);
                shell.goBranch(2, initialLocation: true);
              },
              child: const Text('Перейти в каталог'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _importBook(context, ref),
              child: const Text('Импортировать файл'),
            ),
          ],
        ).animate().fadeIn(duration: 250.ms),
      );
    }

    final pinnedIds = switch (ref.watch(pinnedBooksProvider)) {
      AsyncData(:final value) => value,
      _ => <String>[],
    };
    final pinnedBooksList = books.where((b) => pinnedIds.contains(b.id)).toList();
    final unpinnedBooks = books.where((b) => !pinnedIds.contains(b.id)).toList();

    return RestorableCustomScrollView(
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
                  return _wrapWithSelection(
                    context,
                    ref,
                    book,
                    BookCard(
                      key: ValueKey(book.id),
                      book: book,
                      onTap: _selectionMode
                          ? () => _toggleSelection(book.id)
                          : () => unawaited(context.push('/reader/${book.id}')),
                      onLongPress: _selectionMode ? null : () => _enterSelectionMode(book.id),
                    ),
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
            (context, index) => _wrapWithSelection(
              context,
              ref,
              books[index],
              BookCard(
                key: ValueKey(books[index].id),
                book: books[index],
                onTap: _selectionMode
                    ? () => _toggleSelection(books[index].id)
                    : () => unawaited(context.push('/reader/${books[index].id}')),
                onLongPress: _selectionMode ? null : () => _enterSelectionMode(books[index].id),
              ),
            ),
            childCount: books.length,
          ),
        );
      case LibraryViewMode.list:
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final book = books[index];
              return _wrapWithSelection(
                context,
                ref,
                book,
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: SizedBox(
                      width: 48,
                      height: 68,
                      child: BookCoverImage(book: book),
                    ),
                    title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: book.authorNames.isNotEmpty
                        ? Text(book.authorNames.join(', '))
                        : null,
                    onTap: _selectionMode
                        ? () => _toggleSelection(book.id)
                        : () => unawaited(context.push('/reader/${book.id}')),
                    onLongPress: _selectionMode ? null : () => _enterSelectionMode(book.id),
                  ),
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
            (context, index) => _wrapWithSelection(
              context,
              ref,
              books[index],
              BookCard(
                key: ValueKey(books[index].id),
                book: books[index],
                onTap: _selectionMode
                    ? () => _toggleSelection(books[index].id)
                    : () => unawaited(context.push('/reader/${books[index].id}')),
                onLongPress: _selectionMode ? null : () => _enterSelectionMode(books[index].id),
              ),
            ),
            childCount: books.length,
          ),
        );
    }
  }

  Widget _wrapWithSelection(
    BuildContext context,
    WidgetRef ref,
    Book book,
    Widget child,
  ) {
    if (!_selectionMode) return child;
    final selected = _selectedBookIds.contains(book.id);
    return Stack(
      children: [
        child,
        Positioned(
          top: 4,
          right: 4,
          child: AnimatedOpacity(
            opacity: selected ? 1 : 0.5,
            duration: const Duration(milliseconds: 150),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: Icon(
                selected ? Icons.check : Icons.circle_outlined,
                size: 20,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
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
    unawaited(_loadTags());
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
                              unawaited(context.push('/settings/tags'));
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
      unawaited(SmartDialog.showToast('Теги сохранены'));
    }
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    final parsed = int.tryParse(clean, radix: 16);
    if (parsed == null) return const Color(0xFFFFEB3B);
    return Color(0xFF000000 | parsed);
  }
}
