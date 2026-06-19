import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/daos/tag_dao.dart';
import '../../../shared/models/book.dart';
import '../data/book_repository_impl.dart';

part 'library_sort_provider.g.dart';

enum LibrarySortField {
  title,
  author,
  lastRead,
  progress,
  importTime,
}

enum LibrarySortOrder {
  asc,
  desc,
}

@riverpod
class LibrarySortConfig extends _$LibrarySortConfig {
  @override
  ({LibrarySortField field, LibrarySortOrder order}) build() {
    return (field: LibrarySortField.importTime, order: LibrarySortOrder.desc);
  }

  void updateField(LibrarySortField field) {
    if (state.field == field) {
      state = (
        field: field,
        order: state.order == LibrarySortOrder.asc ? LibrarySortOrder.desc : LibrarySortOrder.asc,
      );
    } else {
      state = (field: field, order: LibrarySortOrder.asc);
    }
  }

  void toggleOrder() {
    state = (
      field: state.field,
      order: state.order == LibrarySortOrder.asc ? LibrarySortOrder.desc : LibrarySortOrder.asc,
    );
  }
}

@riverpod
class LibraryTagFilter extends _$LibraryTagFilter {
  @override
  List<String> build() {
    return [];
  }

  void toggle(String tagId) {
    if (state.contains(tagId)) {
      state = state.where((id) => id != tagId).toList();
    } else {
      state = [...state, tagId];
    }
  }

  void clear() {
    state = [];
  }
}

@riverpod
Future<List<Book>> filteredLibraryBooks(Ref ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  final sortConfig = ref.watch(librarySortConfigProvider);
  final selectedTagIds = ref.watch(libraryTagFilterProvider);

  List<Book> books;

  if (selectedTagIds.isNotEmpty) {
    final tagDao = ref.read(tagDaoProvider);
    final bookIds = await tagDao.getBookIdsForTags(selectedTagIds);
    final bookIdSet = bookIds.toSet();
    books = await repository.getAllBooks();
    books = books.where((b) => bookIdSet.contains(b.id)).toList();
  } else {
    books = await repository.getAllBooks();
  }

  books.sort((a, b) {
    int comparison;
    switch (sortConfig.field) {
      case LibrarySortField.title:
        comparison = a.title.compareTo(b.title);
      case LibrarySortField.author:
        comparison = a.displayAuthor.compareTo(b.displayAuthor);
      case LibrarySortField.lastRead:
        final aDate = a.readingStatus == ReadingStatus.reading ? DateTime.now() : DateTime(2000);
        final bDate = b.readingStatus == ReadingStatus.reading ? DateTime.now() : DateTime(2000);
        comparison = aDate.compareTo(bDate);
      case LibrarySortField.progress:
        comparison = 0;
      case LibrarySortField.importTime:
        final aDate = a.dateAdded ?? DateTime(2000);
        final bDate = b.dateAdded ?? DateTime(2000);
        comparison = aDate.compareTo(bDate);
    }
    return sortConfig.order == LibrarySortOrder.asc ? comparison : -comparison;
  });

  return books;
}
