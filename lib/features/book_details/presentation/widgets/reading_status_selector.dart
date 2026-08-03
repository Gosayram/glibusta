import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/models/book.dart';
import '../../../library/presentation/library_screen.dart' show libraryBooksProvider;
import '../book_details_providers.dart';

class ReadingStatusSelector extends ConsumerWidget {
  final String bookId;

  const ReadingStatusSelector({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedBookAsync = ref.watch(savedBookProvider(bookId));
    final theme = Theme.of(context);

    final currentStatus =
        savedBookAsync.whenOrNull(
          data: (book) {
            if (book == null) return ReadingStatus.none;
            return ReadingStatus.values.firstWhere(
              (e) => e.name == book.readingStatus,
              orElse: () => ReadingStatus.none,
            );
          },
        ) ??
        ReadingStatus.none;

    final statuses = ReadingStatus.values.where((s) => s != ReadingStatus.none).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статус чтения',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < statuses.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _StatusChip(
                    status: statuses[i],
                    isSelected: currentStatus == statuses[i],
                    onTap: () => _updateStatus(context, ref, statuses[i]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _updateStatus(BuildContext context, WidgetRef ref, ReadingStatus status) {
    final db = ref.read(databaseProvider);
    unawaited(
      db.bookDao
          .updateReadingStatus(bookId, status.name)
          .then(
            (_) {
              ref.invalidate(savedBookProvider(bookId));
              ref.invalidate(libraryBooksProvider);
              unawaited(SmartDialog.showToast('Статус: ${status.label}'));
            },
            onError: (_) {
              ref.invalidate(savedBookProvider(bookId));
              unawaited(SmartDialog.showToast('Не удалось изменить статус'));
            },
          ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ReadingStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _statusStyle(status);

    return Material(
      color: isSelected ? color.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : theme.colorScheme.outlineVariant,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _statusStyle(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.wantToRead:
        return (Icons.bookmark_border, Colors.blue);
      case ReadingStatus.reading:
        return (Icons.auto_stories, Colors.green);
      case ReadingStatus.finished:
        return (Icons.check_circle_outline, Colors.purple);
      default:
        return (Icons.remove_circle_outline, Colors.grey);
    }
  }
}
