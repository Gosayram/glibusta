import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../models/book.dart';
import 'book_cover_image.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final bool? isDownloaded;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BookCard({
    super.key,
    required this.book,
    this.isDownloaded,
    this.progress,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Книга: ${book.title}',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap ?? () => context.push('/book/${book.id}'),
          onLongPress: onLongPress,
          onSecondaryTapDown: (details) => _showContextMenu(
            context,
            details.globalPosition,
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BookCoverImage(book: book),
                      if (isDownloaded == true)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.download_done,
                            size: 16,
                            color: AppColors.success,
                          ),
                        )
                      else if (isDownloaded == false)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.cloud_download_outlined,
                            size: 16,
                            color: AppColors.info,
                          ),
                        ),
                      if (progress != null && progress! > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: progress,
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
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final items = <PopupMenuEntry<VoidCallback>>[
      PopupMenuItem<VoidCallback>(
        value: () => context.push('/book/${book.id}'),
        child: const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('О книге'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem<VoidCallback>(
        value: () => context.push('/reader/${book.id}'),
        child: const ListTile(
          leading: Icon(Icons.play_arrow),
          title: Text('Читать'),
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
}
