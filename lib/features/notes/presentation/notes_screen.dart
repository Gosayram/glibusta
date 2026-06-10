import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/error_state_widget.dart';
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.note_alt_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет заметок',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Заметки появятся при чтении книг',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: () => context.go('/library'),
                    child: const Text('Открыть библиотеку'),
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
        error: (e, _) => ErrorStateWidget(
          message: 'Не удалось загрузить заметки',
          details: e.toString(),
          onRetry: () => ref.invalidate(notesStreamProvider(bookId)),
        ),
      ),
    );
  }

  void _showNoteDialog(BuildContext context, WidgetRef ref, Note note) {
    unawaited(
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
      ),
    );
  }

  void _deleteNote(WidgetRef ref, String id) {
    final database = ref.read(databaseProvider);
    final repository = NoteRepository(database);
    unawaited(repository.deleteNote(id));
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
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
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
