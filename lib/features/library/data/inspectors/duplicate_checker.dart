import '../../../../core/database/app_database.dart';

final class DuplicateChecker {
  DuplicateChecker(this._database);

  final AppDatabase _database;

  Future<bool> exists(String hash) async {
    final row = await (_database.select(
      _database.savedBooks,
    )..where((t) => t.contentHash.equals(hash))).getSingleOrNull();
    return row != null;
  }
}
