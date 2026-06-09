import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookDropZone extends ConsumerWidget {
  final Widget child;
  final void Function(List<String> paths) onBooksDropped;

  const BookDropZone({
    super.key,
    required this.child,
    required this.onBooksDropped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropTarget(
      onDragDone: (details) {
        final paths = details.files.map((f) => f.path).toList();
        onBooksDropped(paths);
      },
      child: Semantics(
        label: 'Зона для импорта книг перетаскиванием',
        child: child,
      ),
    );
  }
}
