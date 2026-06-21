import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'note_repository.dart';

final notesStreamProvider = StreamProvider.family<List<Note>, String>((ref, bookId) {
  final database = ref.watch(databaseProvider);
  final repository = NoteRepository(database);
  return repository.watchNotes(bookId);
});
