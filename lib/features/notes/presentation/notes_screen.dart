import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/note_repository.dart';

final notesStreamProvider = StreamProvider.family<List<Note>, String>((ref, bookId) {
  final database = ref.watch(databaseProvider);
  final repository = NoteRepository(database);
  return repository.watchNotes(bookId);
});

class NotesScreen extends ConsumerWidget {
  final String bookId;

  const NotesScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Нет заметок', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    'Добавьте заметку во время чтения',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return NoteTile(
                note: note,
                onTap: () {
                  _showNoteDialog(context, ref, note);
                },
                onDelete: () {
                  _deleteNote(ref, note.id);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }

  void _showNoteDialog(BuildContext context, WidgetRef ref, Note note) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заметка'),
        content: Text(note.content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _deleteNote(WidgetRef ref, String id) {
    final database = ref.read(databaseProvider);
    final repository = NoteRepository(database);
    repository.deleteNote(id);
  }
}

class NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const NoteTile({
    super.key,
    required this.note,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        leading: Icon(
          Icons.note,
          color: Color(int.parse('0xFF${note.highlightColor.substring(1)}')),
        ),
        title: Text(
          note.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Стр. ${note.chapterIndex + 1}, абзац ${note.paragraphIndex + 1}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: onTap,
      ),
    );
  }
}
