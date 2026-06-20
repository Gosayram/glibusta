import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_animations.dart';
import '../../../shared/widgets/book_card_skeleton.dart';
import '../../search/data/flibusta_models.dart';
import '../data/author_detail_provider.dart';

class AuthorDetailScreen extends ConsumerWidget {
  final String authorId;

  const AuthorDetailScreen({super.key, required this.authorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(authorDetailProvider(authorId));
    return Scaffold(
      body: asyncDetail.when(
        data: (AuthorDetailResponse detail) {
          if (detail.books.isEmpty && detail.seriesGroups.isEmpty) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(detail.name.isNotEmpty ? detail.name : 'Автор'),
                  pinned: true,
                ),
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, size: 64),
                        SizedBox(height: 16),
                        Text('Нет книг у этого автора'),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return _AuthorDetailContent(detail: detail);
        },
        loading: () => const BookListSkeleton(),
        error: (Object e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text('Не удалось загрузить автора', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(authorDetailProvider(authorId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorDetailContent extends StatefulWidget {
  final AuthorDetailResponse detail;

  const _AuthorDetailContent({required this.detail});

  @override
  State<_AuthorDetailContent> createState() => _AuthorDetailContentState();
}

class _AuthorDetailContentState extends State<_AuthorDetailContent> {
  bool _bioExpanded = false;

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final hasSeries = detail.seriesGroups.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(detail.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          pinned: true,
        ),

        SliverToBoxAdapter(
          child: _AuthorHeader(
            name: detail.name,
            avatarUrl: detail.avatarUrl,
            biography: detail.biography,
            bookCount: detail.books.length,
            seriesCount: detail.seriesGroups.length,
            bioExpanded: _bioExpanded,
            onToggleBio: () => setState(() => _bioExpanded = !_bioExpanded),
          ),
        ),

        if (hasSeries)
          for (final series in detail.seriesGroups) ...[
            SliverToBoxAdapter(child: _SeriesHeader(series: series)),
            SliverList.builder(
              itemCount: series.books.length,
              itemBuilder: (context, index) {
                final book = series.books[index];
                return _AuthorBookTile(book: book, index: index);
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ]
        else
          SliverList.builder(
            itemCount: detail.books.length,
            itemBuilder: (context, index) {
              final book = detail.books[index];
              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(book.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => context.push('/book/${book.id}'),
              );
            },
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ── Author Header ────────────────────────────────────────────────────────────

class _AuthorHeader extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String biography;
  final int bookCount;
  final int seriesCount;
  final bool bioExpanded;
  final VoidCallback onToggleBio;

  const _AuthorHeader({
    required this.name,
    this.avatarUrl,
    required this.biography,
    required this.bookCount,
    required this.seriesCount,
    required this.bioExpanded,
    required this.onToggleBio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBio = biography.isNotEmpty;
    final baseUrl = 'https://www.flibusta.is';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (avatarUrl != null)
                ClipOval(
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl!.startsWith('http') ? avatarUrl! : '$baseUrl$avatarUrl',
                      fit: BoxFit.cover,
                      errorWidget: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.person, size: 40, color: theme.colorScheme.onSurfaceVariant),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      _bookCountText(bookCount),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (seriesCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$seriesCount ${_seriesCountText(seriesCount)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasBio) ...[
            const SizedBox(height: 12),
            AnimatedCrossFade(
              firstChild: Text(
                biography,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              secondChild: Text(
                biography,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              crossFadeState: bioExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            GestureDetector(
              onTap: onToggleBio,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  bioExpanded ? 'Свернуть' : 'Подробнее',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _bookCountText(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return '$count книг';
    if (mod10 == 1) return '$count книга';
    if (mod10 >= 2 && mod10 <= 4) return '$count книги';
    return '$count книг';
  }

  String _seriesCountText(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'циклов';
    if (mod10 == 1) return 'цикл';
    if (mod10 >= 2 && mod10 <= 4) return 'цикла';
    return 'циклов';
  }
}

// ── Series Header ────────────────────────────────────────────────────────────

class _SeriesHeader extends StatelessWidget {
  final AuthorSeriesGroup series;

  const _SeriesHeader({required this.series});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.collections_bookmark, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  series.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          if (series.genres.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: series.genres.map<Widget>((AuthorGenreItem g) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    g.name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Author Book Tile ─────────────────────────────────────────────────────────

class _AuthorBookTile extends StatelessWidget {
  final AuthorBookItem book;
  final int index;

  const _AuthorBookTile({required this.book, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: book.index != null
          ? CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Text('${book.index}', style: theme.textTheme.labelSmall),
            )
          : null,
      title: Text(book.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: _buildSubtitle(theme),
      trailing: _buildRatingBadge(theme),
      onTap: () => context.push('/book/${book.id}'),
    ).animate().authorListItemFadeIn(delay: (index * 30).ms);
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final parts = <String>[];
    if (book.size != null) parts.add(book.size!);
    if (book.pages != null) parts.add('${book.pages} с.');
    if (book.formats.isNotEmpty) parts.add(book.formats.join(', '));
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget? _buildRatingBadge(ThemeData theme) {
    if (book.rating == null) return null;
    final rating = book.rating!;
    final color = _ratingColor(rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        rating.toStringAsFixed(1),
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _ratingColor(double rating) {
    if (rating >= 4.0) return const Color(0xFF02B369);
    if (rating >= 3.0) return const Color(0xFFF5AC3B);
    if (rating >= 2.0) return const Color(0xFFF1764C);
    return const Color(0xFFEC4938);
  }
}
