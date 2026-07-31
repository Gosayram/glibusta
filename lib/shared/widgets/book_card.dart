import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../features/library/presentation/library_screen.dart';
import '../models/book.dart';
import 'adaptive_panel.dart';
import 'book_cover_image.dart';

class BookCard extends StatefulWidget {
  final Book book;
  final bool? isDownloaded;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEditMetadata;
  final VoidCallback? onAddToCollection;

  const BookCard({
    super.key,
    required this.book,
    this.isDownloaded,
    this.progress,
    this.onTap,
    this.onLongPress,
    this.onEditMetadata,
    this.onAddToCollection,
  });

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = widget.book.displayAuthor;
    final format = widget.book.availableFormats.isNotEmpty
        ? widget.book.availableFormats.first.name.toUpperCase()
        : null;

    return RepaintBoundary(
      child: Semantics(
        label: 'Книга: ${widget.book.title}${author.isNotEmpty ? ', $author' : ''}',
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap ?? () => context.push('/book/${widget.book.id}'),
            onLongPress: widget.onLongPress ?? () => _showStatusMenu(context),
            onSecondaryTapDown: (details) => _showContextMenu(
              context,
              details.globalPosition,
            ),
            child: AnimatedScale(
              scale: _hovered ? 1.025 : 1,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          BookCoverImage(book: widget.book),
                          if (widget.book.readingStatus != ReadingStatus.none)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: _StatusBadge(status: widget.book.readingStatus),
                            ),
                          if (widget.isDownloaded == true)
                            const Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                Icons.download_done,
                                size: 16,
                                color: AppColors.success,
                              ),
                            )
                          else if (widget.isDownloaded == false)
                            const Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                Icons.cloud_download_outlined,
                                size: 16,
                                color: AppColors.info,
                              ),
                            ),
                          if (widget.progress != null && widget.progress! > 0)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(
                                value: widget.progress,
                                minHeight: 3,
                                backgroundColor: Colors.black26,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.secondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                      child: Text(
                        widget.book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (author.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
                        child: Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (format != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            format,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showStatusMenu(BuildContext context) {
    unawaited(
      showAdaptivePanel<void>(
        context: context,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.book.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ...ReadingStatus.values
                  .where((s) => s != ReadingStatus.none)
                  .map(
                    (status) => ListTile(
                      leading: Icon(
                        _statusIcon(status),
                        color: widget.book.readingStatus == status
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(status.label),
                      trailing: widget.book.readingStatus == status
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        _updateReadingStatus(context, status);
                      },
                    ),
                  ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final items = <PopupMenuEntry<VoidCallback>>[
      PopupMenuItem<VoidCallback>(
        value: () => context.push('/book/${widget.book.id}'),
        child: const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('О книге'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem<VoidCallback>(
        value: () => context.push('/reader/${widget.book.id}'),
        child: const ListTile(
          leading: Icon(Icons.play_arrow),
          title: Text('Читать'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem<VoidCallback>(
        value: () => _showStatusMenu(context),
        child: ListTile(
          leading: Icon(_statusIcon(widget.book.readingStatus)),
          title: const Text('Статус'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      if (widget.onEditMetadata != null)
        PopupMenuItem<VoidCallback>(
          value: widget.onEditMetadata,
          child: const ListTile(
            leading: Icon(Icons.edit),
            title: Text('Редактировать'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (widget.onAddToCollection != null)
        PopupMenuItem<VoidCallback>(
          value: widget.onAddToCollection,
          child: const ListTile(
            leading: Icon(Icons.collections_bookmark_outlined),
            title: Text('Добавить в коллекцию'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
    ];

    unawaited(
      showMenu<VoidCallback>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx,
          position.dy,
        ),
        items: items,
      ).then((callback) {
        callback?.call();
      }),
    );
  }

  void _updateReadingStatus(BuildContext context, ReadingStatus status) {
    final container = ProviderScope.containerOf(context);
    final db = container.read(databaseProvider);
    unawaited(
      db.bookDao
          .updateReadingStatus(widget.book.id, status.name)
          .then(
            (_) {
              container.invalidate(libraryBooksProvider);
            },
            onError: (_) {
              container.invalidate(libraryBooksProvider);
            },
          ),
    );
  }

  IconData _statusIcon(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.none:
        return Icons.remove_circle_outline;
      case ReadingStatus.wantToRead:
        return Icons.bookmark_border;
      case ReadingStatus.reading:
        return Icons.auto_stories;
      case ReadingStatus.finished:
        return Icons.check_circle_outline;
      case ReadingStatus.dropped:
        return Icons.cancel_outlined;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final ReadingStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      ReadingStatus.wantToRead => (Icons.bookmark_border, Colors.blue),
      ReadingStatus.reading => (Icons.auto_stories, Colors.green),
      ReadingStatus.finished => (Icons.check_circle_outline, Colors.purple),
      ReadingStatus.dropped => (Icons.cancel_outlined, Colors.grey),
      ReadingStatus.none => (Icons.remove_circle_outline, Colors.transparent),
    };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 10, color: Colors.white),
    );
  }
}
