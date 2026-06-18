import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/tables.dart';

class GroupFolder {
  const GroupFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.color,
    this.icon,
    this.sortOrder = 0,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final int? parentId;
  final int? color;
  final String? icon;
  final int sortOrder;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GroupFolder copyWith({
    String? name,
    int? parentId,
    int? color,
    String? icon,
    int? sortOrder,
    bool? isDeleted,
  }) {
    return GroupFolder(
      id: id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class FolderDao {
  FolderDao(this._db);

  final AppDatabase _db;

  Future<List<GroupFolder>> getAllFolders() async {
    final rows =
        await (_db.select(_db.groups)
              ..where((t) => t.isDeleted.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();

    return rows.map(_rowToFolder).toList();
  }

  Future<List<GroupFolder>> getSubFolders(int parentId) async {
    final rows =
        await (_db.select(_db.groups)
              ..where((t) => t.parentId.equals(parentId) & t.isDeleted.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();

    return rows.map(_rowToFolder).toList();
  }

  Future<GroupFolder?> getFolder(int id) async {
    final row = await (_db.select(_db.groups)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row != null ? _rowToFolder(row) : null;
  }

  Future<int> createFolder(GroupFolder folder) async {
    return _db
        .into(_db.groups)
        .insert(
          GroupsCompanion.insert(
            name: folder.name,
            parentId: Value(folder.parentId),
            color: Value(folder.color),
            icon: Value(folder.icon),
            sortOrder: Value(folder.sortOrder),
          ),
        );
  }

  Future<void> updateFolder(GroupFolder folder) async {
    await (_db.update(_db.groups)..where((t) => t.id.equals(folder.id))).write(
      GroupsCompanion(
        name: Value(folder.name),
        parentId: Value(folder.parentId),
        color: Value(folder.color),
        icon: Value(folder.icon),
        sortOrder: Value(folder.sortOrder),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(int folderId) async {
    await (_db.update(_db.groups)..where((t) => t.id.equals(folderId))).write(
      GroupsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restoreToRoot(List<String> bookIds) async {
    for (final bookId in bookIds) {
      await (_db.update(_db.books)..where((t) => t.id.equals(bookId))).write(
        BooksCompanion(
          groupId: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> renameFolder(int folderId, String newName) async {
    await (_db.update(_db.groups)..where((t) => t.id.equals(folderId))).write(
      GroupsCompanion(
        name: Value(newName),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reorderFolders(List<int> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.groups)..where((t) => t.id.equals(orderedIds[i]))).write(
        GroupsCompanion(
          sortOrder: Value(i),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  List<String> getBreadcrumb(List<GroupFolder> allFolders, int? folderId) {
    if (folderId == null) return [];
    final path = <String>[];
    var currentId = folderId;

    while (currentId != null) {
      final folder = allFolders.firstWhere(
        (f) => f.id == currentId,
        orElse: () => const GroupFolder(id: 0, name: ''),
      );
      if (folder.id == 0) break;
      path.insert(0, folder.name);
      currentId = folder.parentId;
    }

    return path;
  }

  GroupFolder _rowToFolder(GroupsRow row) {
    return GroupFolder(
      id: row.id,
      name: row.name,
      parentId: row.parentId,
      color: row.color,
      icon: row.icon,
      sortOrder: row.sortOrder,
      isDeleted: row.isDeleted,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

final folderDaoProvider = Provider<FolderDao>((ref) {
  final db = ref.watch(databaseProvider);
  return FolderDao(db);
});
