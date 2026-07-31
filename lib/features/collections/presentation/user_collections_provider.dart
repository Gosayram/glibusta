import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';

final userCollectionsProvider = FutureProvider<List<Collection>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.collectionDao.getAllCollections();
});
