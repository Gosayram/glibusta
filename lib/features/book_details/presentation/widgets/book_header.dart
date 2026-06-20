import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/formats/format_capability.dart';
import '../../../../shared/models/book.dart';
import '../../../../shared/models/download_task.dart';
import '../../../../shared/widgets/app_animations.dart';
import '../../../../shared/widgets/book_cover_image.dart';

class BookHeader extends StatelessWidget {
  final Book book;
  final BookDetails details;

  const BookHeader({super.key, required this.book, required this.details});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 130,
              height: 190,
              child: BookCoverImage(book: book),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                book.title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (book.displayAuthor.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  book.displayAuthor,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (book.publishDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  book.publishDate!.year.toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (details.availableFormats.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final capService = const FormatCapabilityService();
                    return Wrap(
                      spacing: 6,
                      children: details.availableFormats.map((f) {
                        final warning = capService.warningLabel(f);
                        final isSupported = warning == null;
                        return Tooltip(
                          message: warning ?? f.name.toUpperCase(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSupported
                                  ? theme.colorScheme.secondaryContainer
                                  : theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              f.name.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isSupported
                                    ? theme.colorScheme.onSecondaryContainer
                                    : theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    ).animate().contentFadeIn();
  }
}
