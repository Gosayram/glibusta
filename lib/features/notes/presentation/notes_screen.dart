import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/app_animations.dart';
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
                onDelete: () => _deleteNote(context, ref, note),
              ).animate().listTileTransition(delay: (index * 50).ms);
            },
          );
        },
        loading: () => Skeletonizer(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (_, _) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Skeleton.unite(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(BoneMock.title),
                      const SizedBox(height: 8),
                      Text(BoneMock.paragraph),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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

  Future<void> _deleteNote(BuildContext context, WidgetRef ref, Note note) async {
    final database = ref.read(databaseProvider);
    final repository = NoteRepository(database);
    await repository.deleteNote(note.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Заметка удалена'),
        action: SnackBarAction(
          label: 'Отмена',
          onPressed: () {
            unawaited(repository.insertNote(note));
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

Color _parseColorSafe(String? hex) {
  if (hex == null || hex.isEmpty || hex.length < 7) return Colors.amber;
  try {
    return Color(int.parse('0xFF${hex.substring(1)}'));
  } on Object catch (_) {
    return Colors.amber;
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
    return RepaintBoundary(
      child: Dismissible(
        key: Key(note.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          return showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удалить заметку?'),
              content: const Text('Это действие можно отменить'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Удалить'),
                ),
              ],
            ),
          );
        },
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
            color: _parseColorSafe(note.highlightColor),
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
      ),
    );
  }
}
