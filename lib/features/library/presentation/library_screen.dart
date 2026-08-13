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
import 'package:uuid/uuid.dart';

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
import '../../collections/presentation/user_collections_provider.dart';
import '../data/book_data_export.dart';
import '../data/book_delete_service.dart';
import '../data/book_import_service.dart';
import '../data/book_repository_impl.dart';
import '../data/inspectors/book_inspection_provider.dart';
import '../data/inspectors/book_inspection_result.dart';
import '../domain/book_repository.dart';
import 'continue_reading_provider.dart';
import 'library_sort.dart';
import 'library_view_mode_provider.dart';
import 'pinned_books_provider.dart';

part 'library_screen.g.dart';

const _pageSize = 50;

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
  ReadingStatus? _statusFilter;
  String? _selectedCollectionId;
  String? _selectedCollectionName;
  String? _selectedFormat;
  Set<String> _collectionBookIds = {};
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Set<String> _selectedBookIds = {};
  bool _showTrash = false;
  String? _openingBookId;

  final List<Book> _loadedBooks = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _paginationError;

  bool get _selectionMode => _selectedBookIds.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  BookSortField get _sortField {
    switch (_sort) {
      case LibrarySort.recentlyAdded:
        return BookSortField.addedAt;
      case LibrarySort.title:
        return BookSortField.title;
      case LibrarySort.author:
        // Author sort is performed client-side by `sortLibraryBooks`; there is
        // no author column on SavedBooks, so fall back to addedAt here.
        return BookSortField.addedAt;
      case LibrarySort.progress:
        return BookSortField.progress;
    }
  }

  bool get _sortAscending => _sort == LibrarySort.title || _sort == LibrarySort.progress;

  void _resetPagination() {
    _loadedBooks.clear();
    _hasMore = true;
    _isLoadingMore = false;
    _paginationError = null;
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    try {
      final repository = ref.read(bookRepositoryProvider);
      final query = _searchQuery.trim();
      final List<Book> newBooks;
      if (query.isNotEmpty) {
        newBooks = await repository.searchBooksPaged(
          query,
          limit: _pageSize,
          offset: _loadedBooks.length,
          formatFilter: _selectedFormat,
        );
      } else {
        newBooks = await repository.getPagedBooks(
          limit: _pageSize,
          offset: _loadedBooks.length,
          sortField: _sortField,
          ascending: _sortAscending,
          formatFilter: _selectedFormat,
          collectionId: _selectedCollectionId,
        );
      }
      if (!mounted) return;
      setState(() {
        if (newBooks.length < _pageSize) {
          _hasMore = false;
        }
        _loadedBooks.addAll(newBooks);
        _isLoadingMore = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _paginationError = e.toString();
      });
    }
  }

  void _invalidateAndReload(WidgetRef ref) {
    ref.invalidate(libraryBooksProvider);
    _resetPagination();
  }

  @override
  Widget build(BuildContext context) {
    final runningTasks = ref.watch(backgroundTaskProvider.notifier).running;
    final selectedCollectionId = _selectedCollectionId;

    if (_loadedBooks.isEmpty && !_isLoadingMore && _paginationError == null) {
      unawaited(_loadNextPage());
    }

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
          if (selectedCollectionId != null)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.collections_bookmark_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedCollectionName ?? 'Коллекция',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _selectedCollectionId = null;
                          _selectedCollectionName = null;
                        });
                        _resetPagination();
                        unawaited(_loadNextPage());
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (!_showTrash) _buildFormatFilterBar(context),
          Expanded(
            child: _showTrash
                ? _buildTrashView(context, ref)
                : BookDropZone(
                    onBooksDropped: (paths) => _handleBooksDropped(ref, paths),
                    child: RefreshIndicator(
                      onRefresh: () async {
                        _resetPagination();
                        ref.invalidate(libraryBooksProvider);
                        await _loadNextPage();
                      },
                      child: _buildPagedContent(context, ref),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagedContent(BuildContext context, WidgetRef ref) {
    if (_paginationError != null && _loadedBooks.isEmpty) {
      return ErrorStateWidget(
        message: 'Не удалось загрузить библиотеку',
        details: _paginationError,
        onRetry: () {
          _resetPagination();
        },
      );
    }

    if (_loadedBooks.isEmpty && _isLoadingMore) {
      return Skeletonizer.zone(
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
              title: Bone(width: 120, height: 12),
              subtitle: Bone(width: 80, height: 12),
            ),
          ),
        ),
      );
    }

    var filtered = _loadedBooks;
    if (_selectedCollectionId != null) {
      filtered = filtered.where((b) => _collectionBookIds.contains(b.id)).toList();
    }
    if (_statusFilter != null) {
      filtered = filtered.where((b) => b.readingStatus == _statusFilter).toList();
    }
    if (_sort == LibrarySort.author) {
      filtered = sortLibraryBooks(filtered, _sort);
    }

    return _buildBooksGrid(context, ref, filtered);
  }

  PreferredSizeWidget _buildNormalAppBar(WidgetRef ref) {
    return AppBar(
      title: _showTrash
          ? const Text('Корзина')
          : _isSearchOpen
          ? TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Поиск в библиотеке...',
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _resetPagination();
                });
                unawaited(_loadNextPage());
              },
            )
          : const Text('Библиотека'),
      automaticallyImplyLeading: false,
      leading: _showTrash
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Назад',
              onPressed: () => setState(() => _showTrash = false),
            )
          : null,
      actions: [
        if (!_showTrash) ...[
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
            tooltip: _isSearchOpen ? 'Закрыть поиск' : 'Поиск',
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchController.clear();
                  _searchQuery = '';
                  _resetPagination();
                  unawaited(_loadNextPage());
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
            onSelected: (sort) {
              setState(() {
                _sort = sort;
                _resetPagination();
              });
              unawaited(_loadNextPage());
            },
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
            icon: Icon(
              _selectedCollectionId != null
                  ? Icons.collections_bookmark
                  : Icons.collections_bookmark_outlined,
            ),
            tooltip: 'Коллекция',
            onPressed: () => _showCollectionFilterSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Корзина',
            onPressed: () => setState(() => _showTrash = true),
          ),
        ],
        if (_showTrash)
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Очистить корзину',
            onPressed: () => _purgeTrash(context, ref),
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

  Widget _buildFormatFilterBar(BuildContext context) {
    final formats = [
      (null, 'Все'),
      ('epub', 'EPUB'),
      ('fb2', 'FB2'),
      ('pdf', 'PDF'),
      ('mobi', 'MOBI'),
      ('txt', 'TXT'),
      ('djvu', 'DJVU'),
      ('docx', 'DOCX'),
      ('cbz', 'CBZ'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: formats.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final (formatValue, label) = formats[index];
              final isSelected = _selectedFormat == formatValue;
              return FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedFormat = formatValue;
                    _resetPagination();
                  });
                  unawaited(_loadNextPage());
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Непрочитано'),
                selected: _statusFilter == ReadingStatus.none,
                onSelected: (_) {
                  setState(() {
                    _statusFilter = _statusFilter == ReadingStatus.none ? null : ReadingStatus.none;
                    _resetPagination();
                  });
                  unawaited(_loadNextPage());
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              FilterChip(
                label: const Text('Читаю'),
                selected: _statusFilter == ReadingStatus.reading,
                onSelected: (_) {
                  setState(() {
                    _statusFilter = _statusFilter == ReadingStatus.reading
                        ? null
                        : ReadingStatus.reading;
                    _resetPagination();
                  });
                  unawaited(_loadNextPage());
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              FilterChip(
                label: const Text('Прочитано'),
                selected: _statusFilter == ReadingStatus.finished,
                onSelected: (_) {
                  setState(() {
                    _statusFilter = _statusFilter == ReadingStatus.finished
                        ? null
                        : ReadingStatus.finished;
                    _resetPagination();
                  });
                  unawaited(_loadNextPage());
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ],
    );
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

  Future<void> _selectCollection(String? collectionId, String? collectionName) async {
    if (collectionId == null) {
      setState(() {
        _selectedCollectionId = null;
        _selectedCollectionName = null;
        _collectionBookIds = {};
      });
      return;
    }
    final db = ref.read(databaseProvider);
    final books = await db.collectionDao.getBooksInCollection(collectionId);
    if (mounted) {
      setState(() {
        _selectedCollectionId = collectionId;
        _selectedCollectionName = collectionName;
        _collectionBookIds = books.map((b) => b.id).toSet();
      });
    }
  }

  void _selectAllBooks() {
    setState(() {
      _selectedBookIds
        ..clear()
        ..addAll(_loadedBooks.map((Book b) => b.id));
    });
  }

  Future<void> _batchDelete(BuildContext context, WidgetRef ref) async {
    final count = _selectedBookIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить $count ${_pluralBooks(count)}?'),
        content: const Text('Книги будут перемещены в корзину'),
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
    _invalidateAndReload(ref);
    if (context.mounted) {
      _showUndoSnackBar(context, ref, ids, count);
    }
  }

  void _showUndoSnackBar(
    BuildContext context,
    WidgetRef ref,
    List<String> bookIds,
    int count,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('$count ${_pluralBooks(count)} удалено'),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () async {
              final service = ref.read(bookDeleteServiceProvider);
              for (final id in bookIds) {
                await service.restoreFromTrash(id);
              }
              _invalidateAndReload(ref);
            },
          ),
          duration: const Duration(seconds: 10),
        ),
      );
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
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const Text('CSV'),
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
    } else if (format == 'csv') {
      final content = buildBookExportCsv(
        bookTitle: selectedBooks.map((b) => b.title).join(', '),
        highlights: allHighlights,
        bookmarks: allBookmarks,
        notes: allNotes,
      );
      file = File('${tmpDir.path}/glibusta_batch_export_$ts.csv');
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
        _invalidateAndReload(ref);
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
      _invalidateAndReload(ref);
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
      _invalidateAndReload(ref);
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

  Widget _buildTrashView(BuildContext context, WidgetRef ref) {
    final service = ref.read(bookDeleteServiceProvider);
    return FutureBuilder<List<SavedBook>>(
      future: service.getTrashBooks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final books = snapshot.data ?? [];
        if (books.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Корзина пуста',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: books.length,
          itemBuilder: (_, index) {
            final book = books[index];
            return ListTile(
              leading: const Icon(Icons.book_outlined),
              title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: 'Восстановить',
                    onPressed: () async {
                      await service.restoreFromTrash(book.id);
                      if (context.mounted) {
                        setState(() {});
                        _invalidateAndReload(ref);
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_forever,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: 'Удалить навсегда',
                    onPressed: () async {
                      await service.deleteBookCompletely(book.id);
                      if (context.mounted) {
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _purgeTrash(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить корзину?'),
        content: const Text('Все книги в корзине будут удалены навсегда'),
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
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final service = ref.read(bookDeleteServiceProvider);
    await service.purgeTrash();
    if (context.mounted) {
      setState(() {});
      unawaited(SmartDialog.showToast('Корзина очищена'));
    }
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

  void _showCollectionFilterSheet(BuildContext context, WidgetRef ref) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => _CollectionFilterSheet(
          selectedCollectionId: _selectedCollectionId,
          onSelect: (id, name) {
            Navigator.pop(ctx);
            unawaited(_selectCollection(id, name));
          },
        ),
      ),
    );
  }

  void _showCollectionPicker(BuildContext context, WidgetRef ref, Book book) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _CollectionPickerSheet(book: book),
      ),
    );
  }

  void _showEditMetadata(BuildContext context, WidgetRef ref, Book book) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => EditMetadataSheet(book: book),
      ).then((_) {
        if (mounted) {
          setState(() => _resetPagination());
        }
      }),
    );
  }

  Widget _buildBooksGrid(BuildContext context, WidgetRef ref, List<Book> books) {
    if (books.isEmpty && !_isLoadingMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Ваша библиотека пуста',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Добавьте книги через импорт или скачивание',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _importBook(context, ref),
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Импорт файла'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final shell = StatefulNavigationShell.of(context);
                  shell.goBranch(2, initialLocation: true);
                },
                icon: const Icon(Icons.explore_outlined),
                label: const Text('OPDS каталог'),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms),
      );
    }

    final pinnedIds = switch (ref.watch(pinnedBooksProvider)) {
      AsyncData(:final value) => value,
      _ => <String>[],
    };
    final pinnedBooksList = books.where((b) => pinnedIds.contains(b.id)).toList();
    final unpinnedBooks = books.where((b) => !pinnedIds.contains(b.id)).toList();

    final continueReadingAsync = ref.watch(continueReadingProvider);
    final continueBooks = switch (continueReadingAsync) {
      AsyncData(:final value) => value,
      _ => <ContinueReadingBook>[],
    };

    return RestorableCustomScrollView(
      restorationId: 'library-books-scroll',
      slivers: [
        if (continueBooks.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Продолжить чтение',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: continueBooks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final item = continueBooks[index];
                  return _ContinueReadingCard(
                    item: item,
                    onTap: () {
                      if (_openingBookId == item.book.id) return;
                      _openingBookId = item.book.id;
                      unawaited(
                        context.push('/reader/${item.book.id}').then((_) {
                          if (mounted) _openingBookId = null;
                        }),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
        ],
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
                          : () {
                              if (_openingBookId == book.id) return;
                              _openingBookId = book.id;
                              unawaited(
                                context.push('/reader/${book.id}').then((_) {
                                  if (mounted) _openingBookId = null;
                                }),
                              );
                            },
                      onLongPress: _selectionMode ? null : () => _enterSelectionMode(book.id),
                      onEditMetadata: () => _showEditMetadata(context, ref, book),
                      onAddToCollection: () => _showCollectionPicker(context, ref, book),
                    ),
                  );
                },
                childCount: pinnedBooksList.length,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
        ],
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
        if (_hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _isLoadingMore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Builder(
                        builder: (context) {
                          unawaited(_loadNextPage());
                          return const SizedBox.shrink();
                        },
                      ),
              ),
            ),
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
                    : () {
                        if (_openingBookId == books[index].id) return;
                        _openingBookId = books[index].id;
                        unawaited(
                          context.push('/reader/${books[index].id}').then((_) {
                            if (mounted) _openingBookId = null;
                          }),
                        );
                      },
                onLongPress: _selectionMode ? null : () => _enterSelectionMode(books[index].id),
                onEditMetadata: () => _showEditMetadata(context, ref, books[index]),
                onAddToCollection: () => _showCollectionPicker(context, ref, books[index]),
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
                      child: BookCoverImage(
                        book: book,
                        memCacheWidth: 96,
                        memCacheHeight: 136,
                      ),
                    ),
                    title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: book.authorNames.isNotEmpty
                        ? Text(book.authorNames.join(', '))
                        : null,
                    onTap: _selectionMode
                        ? () => _toggleSelection(book.id)
                        : () {
                            if (_openingBookId == book.id) return;
                            _openingBookId = book.id;
                            unawaited(
                              context.push('/reader/${book.id}').then((_) {
                                if (mounted) _openingBookId = null;
                              }),
                            );
                          },
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
                    : () {
                        if (_openingBookId == books[index].id) return;
                        _openingBookId = books[index].id;
                        unawaited(
                          context.push('/reader/${books[index].id}').then((_) {
                            if (mounted) _openingBookId = null;
                          }),
                        );
                      },
                onLongPress: _selectionMode ? null : () => _enterSelectionMode(books[index].id),
                onEditMetadata: () => _showEditMetadata(context, ref, books[index]),
                onAddToCollection: () => _showCollectionPicker(context, ref, books[index]),
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

class EditMetadataSheet extends ConsumerStatefulWidget {
  const EditMetadataSheet({required this.book, super.key});

  final Book book;

  @override
  ConsumerState<EditMetadataSheet> createState() => _EditMetadataSheetState();
}

class _EditMetadataSheetState extends ConsumerState<EditMetadataSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _descriptionController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book.title);
    _authorController = TextEditingController(text: widget.book.authorNames.join(', '));
    _descriptionController = TextEditingController(text: widget.book.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Редактировать метаданные',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: 'Автор',
                    hintText: 'Иванов, Петров',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final authorNames = _authorController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final updated = widget.book.copyWith(
        title: _titleController.text.trim(),
        authorIds: authorNames,
        authorNames: authorNames,
        description: _descriptionController.text.trim(),
      );

      final repository = ref.read(bookRepositoryProvider);
      await repository.updateBook(updated);
      ref.invalidate(libraryBooksProvider);

      if (mounted) {
        Navigator.pop(context);
        unawaited(SmartDialog.showToast('Метаданные сохранены'));
      }
    } on Object catch (e) {
      if (mounted) {
        unawaited(SmartDialog.showToast('Ошибка сохранения: $e'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CollectionFilterSheet extends ConsumerWidget {
  const _CollectionFilterSheet({
    required this.selectedCollectionId,
    required this.onSelect,
  });

  final String? selectedCollectionId;
  final void Function(String? id, String? name) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(userCollectionsProvider);

    return DraggableScrollableSheet(
      minChildSize: 0.3,
      maxChildSize: 0.7,
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
                      'Фильтр по коллекции',
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
              child: collectionsAsync.when(
                data: (collections) {
                  return ListView(
                    controller: scrollController,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.library_books_outlined),
                        title: const Text('Все книги'),
                        trailing: selectedCollectionId == null
                            ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () => onSelect(null, null),
                      ),
                      if (collections.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Нет коллекций. Создайте их на экране «Коллекции».',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      for (final col in collections)
                        ListTile(
                          leading: Icon(
                            Icons.folder,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(col.name),
                          trailing: selectedCollectionId == col.id
                              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () => onSelect(col.id, col.name),
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionPickerSheet extends ConsumerStatefulWidget {
  const _CollectionPickerSheet({required this.book});

  final Book book;

  @override
  ConsumerState<_CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends ConsumerState<_CollectionPickerSheet> {
  late Set<String> _selectedCollectionIds;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedCollectionIds = {};
    unawaited(_loadCollections());
  }

  Future<void> _loadCollections() async {
    final db = ref.read(databaseProvider);
    final bookCollections = await db.collectionDao.getCollectionsForBook(widget.book.id);
    if (mounted) {
      setState(() {
        _selectedCollectionIds = bookCollections.map((c) => c.id).toSet();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(userCollectionsProvider);

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
                      'Добавить в коллекцию',
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
              child: collectionsAsync.when(
                data: (collections) {
                  if (collections.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.collections_bookmark_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text('Нет коллекций'),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              unawaited(_createCollectionFromPicker());
                            },
                            child: const Text('Создать коллекцию'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: collections.length,
                    itemBuilder: (_, index) {
                      final col = collections[index];
                      final isSelected = _selectedCollectionIds.contains(col.id);
                      return CheckboxListTile(
                        secondary: Icon(
                          Icons.folder,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(col.name),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedCollectionIds.add(col.id);
                            } else {
                              _selectedCollectionIds.remove(col.id);
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
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_createCollectionFromPicker());
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Новая'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => _saveCollections(ctx),
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCollectionFromPicker() async {
    final controller = TextEditingController();
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая коллекция'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Название коллекции',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result != null && result.isNotEmpty && mounted) {
      final db = ref.read(databaseProvider);
      await db.collectionDao.insertCollection(
        CollectionsCompanion.insert(id: const Uuid().v4(), name: result),
      );
      ref.invalidate(userCollectionsProvider);
      if (mounted) {
        unawaited(SmartDialog.showToast('Коллекция «$result» создана'));
      }
    }
  }

  Future<void> _saveCollections(BuildContext ctx) async {
    final db = ref.read(databaseProvider);
    final existing = await db.collectionDao.getCollectionsForBook(widget.book.id);
    final existingIds = existing.map((c) => c.id).toSet();

    for (final id in _selectedCollectionIds.difference(existingIds)) {
      await db.collectionDao.addBookToCollection(widget.book.id, id);
    }
    for (final id in existingIds.difference(_selectedCollectionIds)) {
      await db.collectionDao.removeBookFromCollection(widget.book.id, id);
    }

    if (ctx.mounted) {
      Navigator.pop(ctx);
      unawaited(SmartDialog.showToast('Коллекции обновлены'));
    }
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.item, required this.onTap});

  final ContinueReadingBook item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BookCoverImage(
                  book: item.book,
                  memCacheWidth: 240,
                  memCacheHeight: 360,
                ),
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: item.progress,
              minHeight: 3,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 4),
            Text(
              item.book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
