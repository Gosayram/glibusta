import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/adaptive_context.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/search_query.dart';
import '../../../shared/widgets/book_card.dart';
import '../../../shared/widgets/book_cover_image.dart';
import 'search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = SearchController();
  final _genreController = TextEditingController();
  final _languageController = TextEditingController();
  Timer? _searchDebounce;
  Timer? _genreDebounce;
  Timer? _languageDebounce;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(searchControllerProvider.notifier).loadHistory());
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _genreController.text = widget.initialCategory!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setGenreFilter(widget.initialCategory!);
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _genreDebounce?.cancel();
    _languageDebounce?.cancel();
    _genreController.dispose();
    _languageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      ref.read(searchControllerProvider.notifier).clearResults();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(ref.read(searchControllerProvider.notifier).search(value.trim()));
    });
  }

  void _setFormatFilter(BookFormat? format) {
    final filters = ref.read(searchControllerProvider).filters;
    ref
        .read(searchControllerProvider.notifier)
        .setFilters(
          filters.copyWith(format: format),
        );
  }

  void _setGenreFilter(String value) {
    final filters = ref.read(searchControllerProvider).filters;
    ref
        .read(searchControllerProvider.notifier)
        .setFilters(
          filters.copyWith(genre: value.trim().isEmpty ? null : value.trim()),
        );
  }

  void _setLanguageFilter(String value) {
    final filters = ref.read(searchControllerProvider).filters;
    ref
        .read(searchControllerProvider.notifier)
        .setFilters(
          filters.copyWith(
            language: value.trim().isEmpty ? null : value.trim(),
          ),
        );
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _genreDebounce?.cancel();
    _languageDebounce?.cancel();
    _genreController.clear();
    _languageController.clear();
    ref.read(searchControllerProvider.notifier).setFilters(const SearchFilters());
  }

  void _setDateRange(DateTime? from, DateTime? to) {
    final filters = ref.read(searchControllerProvider).filters;
    ref
        .read(searchControllerProvider.notifier)
        .setFilters(
          filters.copyWith(
            dateFrom: from,
            dateTo: to,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: SearchAnchor.bar(
          searchController: _searchController,
          viewHintText: 'Поиск книг...',
          onChanged: _onSearchChanged,
          onSubmitted: (value) {
            _searchDebounce?.cancel();
            if (value.trim().isNotEmpty) {
              _searchController.closeView(value.trim());
              unawaited(ref.read(searchControllerProvider.notifier).search(value.trim()));
            }
          },
          suggestionsBuilder: (context, controller) {
            if (state.history.isEmpty) {
              return [
                const ListTile(
                  enabled: false,
                  title: Text('Нет недавних запросов'),
                ),
              ];
            }

            return state.history.map(
              (query) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(query),
                onTap: () {
                  controller.closeView(query);
                  unawaited(ref.read(searchControllerProvider.notifier).search(query));
                },
              ),
            );
          },
          viewLeading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _searchController.closeView(null);
            },
          ),
          barLeading: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          viewTrailing: [
            if (state.history.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Очистить историю поиска',
                onPressed: () {
                  unawaited(ref.read(searchControllerProvider.notifier).clearHistory());
                },
              ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                ref.read(searchControllerProvider.notifier).clearResults();
              },
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: context.isCompact
          ? _buildPhoneLayout(context, state)
          : _buildTabletLayout(context, state),
    );
  }

  Widget _buildPhoneLayout(BuildContext context, SearchState state) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Material(
          child: InkWell(
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _filtersExpanded ? Icons.filter_list_off : Icons.filter_list,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Фильтры',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!_filtersExpanded && state.filters.hasFilters) ...[
                    const SizedBox(width: 8),
                    _buildActiveFilterChips(context, state),
                  ],
                  const Spacer(),
                  Icon(
                    _filtersExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _filtersExpanded ? _buildFilters(context, state) : const SizedBox.shrink(),
        ),
        const Divider(height: 1),
        if (state.isLoading && state.books.isEmpty && state.authors.isEmpty)
          const LinearProgressIndicator(),
        if (state.error != null) _buildErrorCard(context, state),
        Expanded(
          child: _buildResults(context, state),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context, SearchState state) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: _filtersExpanded ? 300 : 0,
          child: _filtersExpanded
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      right: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 24),
                    child: _buildFilters(context, state),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _filtersExpanded ? Icons.filter_list_off : Icons.filter_list,
                        size: 20,
                      ),
                      tooltip: _filtersExpanded ? 'Скрыть фильтры' : 'Показать фильтры',
                      onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
                    ),
                    if (!_filtersExpanded && state.filters.hasFilters) ...[
                      const SizedBox(width: 4),
                      _buildActiveFilterChips(context, state),
                    ],
                  ],
                ),
              ),
              if (state.isLoading && state.books.isEmpty && state.authors.isEmpty)
                const LinearProgressIndicator(),
              if (state.error != null) _buildErrorCard(context, state),
              Expanded(
                child: _buildResults(context, state),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChips(BuildContext context, SearchState state) {
    final filters = state.filters;
    final chips = <Widget>[];
    if (filters.format != null) {
      chips.add(
        _buildMiniChip(context, filters.format!.name.toUpperCase(), () {
          ref.read(searchControllerProvider.notifier).setFilters(filters.copyWith(format: null));
        }),
      );
    }
    if (filters.genre != null && filters.genre!.isNotEmpty) {
      chips.add(
        _buildMiniChip(context, filters.genre!, () {
          _genreController.clear();
          ref.read(searchControllerProvider.notifier).setFilters(filters.copyWith(genre: null));
        }),
      );
    }
    if (filters.language != null && filters.language!.isNotEmpty) {
      chips.add(
        _buildMiniChip(context, filters.language!, () {
          _languageController.clear();
          ref.read(searchControllerProvider.notifier).setFilters(filters.copyWith(language: null));
        }),
      );
    }
    return Flexible(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(spacing: 6, children: chips),
      ),
    );
  }

  Widget _buildMiniChip(BuildContext context, String label, VoidCallback onRemove) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer)),
      backgroundColor: cs.secondaryContainer,
      deleteIcon: Icon(Icons.close, size: 14, color: cs.onSecondaryContainer),
      onDeleted: onRemove,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(left: 8, right: 2),
    );
  }

  Widget _buildErrorCard(BuildContext context, SearchState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Не удалось выполнить поиск',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Проверьте подключение к интернету и попробуйте снова',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () {
                  final query = state.lastQuery;
                  if (query.isNotEmpty) {
                    unawaited(ref.read(searchControllerProvider.notifier).search(query));
                  }
                },
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, SearchState state) {
    final filters = state.filters;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Формат',
          style: theme.textTheme.titleSmall?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFormatChip(
              context,
              label: 'Все',
              selected: filters.format == null,
              onTap: () => _setFormatFilter(null),
            ),
            ...BookFormat.values
                .where((f) => f != BookFormat.unknown)
                .map(
                  (format) => _buildFormatChip(
                    context,
                    label: format.name.toUpperCase(),
                    selected: filters.format == format,
                    onTap: () => _setFormatFilter(
                      filters.format == format ? null : format,
                    ),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Параметры',
          style: theme.textTheme.titleSmall?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _genreController,
                decoration: const InputDecoration(
                  labelText: 'Жанр',
                  hintText: 'фантастика',
                  isDense: true,
                  prefixIcon: Icon(Icons.category_outlined, size: 20),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (value) {
                  _genreDebounce?.cancel();
                  _setGenreFilter(value);
                },
                onChanged: (value) {
                  _genreDebounce?.cancel();
                  _genreDebounce = Timer(const Duration(milliseconds: 500), () {
                    _setGenreFilter(value);
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _languageController,
                decoration: const InputDecoration(
                  labelText: 'Язык',
                  hintText: 'ru',
                  isDense: true,
                  prefixIcon: Icon(Icons.translate, size: 20),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (value) {
                  _languageDebounce?.cancel();
                  _setLanguageFilter(value);
                },
                onChanged: (value) {
                  _languageDebounce?.cancel();
                  _languageDebounce = Timer(const Duration(milliseconds: 500), () {
                    _setLanguageFilter(value);
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  filters.dateFrom != null
                      ? 'С: ${filters.dateFrom!.day}.${filters.dateFrom!.month}.${filters.dateFrom!.year}'
                      : 'Дата от',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: filters.dateFrom ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    _setDateRange(picked, filters.dateTo);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  filters.dateTo != null
                      ? 'По: ${filters.dateTo!.day}.${filters.dateTo!.month}.${filters.dateTo!.year}'
                      : 'Дата до',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: filters.dateTo ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    _setDateRange(filters.dateFrom, picked);
                  }
                },
              ),
            ),
          ],
        ),
        if (filters.hasFilters) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Сбросить фильтры'),
              onPressed: _clearFilters,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormatChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? cs.onPrimary : cs.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, SearchState state) {
    if (state.books.isEmpty && state.authors.isEmpty && !state.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Начните поиск',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ).animate().fadeIn(duration: 250.ms),
      );
    }

    final resultChildren = _buildResultChildren(context, state);

    return RefreshIndicator(
      onRefresh: () async {
        final query = ref.read(searchControllerProvider).lastQuery;
        if (query.isNotEmpty) {
          await ref.read(searchControllerProvider.notifier).search(query);
        }
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
            unawaited(ref.read(searchControllerProvider.notifier).loadMore());
          }
          return false;
        },
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.viewPaddingOf(context).bottom + 24,
          ),
          itemCount: resultChildren.length,
          itemBuilder: (context, index) => resultChildren[index],
        ),
      ),
    );
  }

  List<Widget> _buildResultChildren(BuildContext context, SearchState state) {
    final children = <Widget>[];

    if (state.authors.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Авторы',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
      for (final author in state.authors) {
        children.add(
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  author.name.isNotEmpty ? author.name[0].toUpperCase() : '?',
                ),
              ),
              title: Text(author.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => unawaited(context.push('/author/${author.id}')),
            ),
          ),
        );
      }
      children.add(const SizedBox(height: 8));
    }

    if (state.books.isNotEmpty) {
      if (state.authors.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Книги',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      }
      if (context.isCompact) {
        for (final book in state.books) {
          children.add(
            BookListItem(
              book: book,
              onTap: () => unawaited(context.push('/reader/${book.id}')),
            ),
          );
        }
      } else {
        children.add(
          GridView.builder(
            padding: EdgeInsets.all(context.isExpanded ? 24 : 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: context.isExpanded ? 220 : 180,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: state.books.length,
            itemBuilder: (context, index) {
              final book = state.books[index];
              return BookCard(
                key: ValueKey(book.id),
                book: book,
                onTap: () => unawaited(context.push('/reader/${book.id}')),
              );
            },
          ),
        );
      }
      if (state.hasMore) {
        children.add(
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
    }

    if (state.isLoading && state.books.isEmpty && state.authors.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return children;
  }
}

class BookListItem extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;

  const BookListItem({super.key, required this.book, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: SizedBox(
          width: 48,
          height: 64,
          child: BookCoverImage(book: book, width: 48, height: 64),
        ),
        title: Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.displayAuthor.isNotEmpty)
              Text(
                book.displayAuthor,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (book.availableFormats.isNotEmpty)
              Wrap(
                spacing: 4,
                children: book.availableFormats
                    .map(
                      (f) => Chip(
                        label: Text(
                          f.name.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}
