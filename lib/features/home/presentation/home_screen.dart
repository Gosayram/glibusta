import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Glibusta'),
        automaticallyImplyLeading: false,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _SectionHeader(title: 'Продолжить чтение'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _ContinueReadingCard(
                        title: 'Пример книги',
                        author: 'Автор',
                        progress: 0.65,
                        onTap: () => context.go('/reader/1'),
                      ),
                      const SizedBox(width: 12),
                      _ContinueReadingCard(
                        title: 'Другая книга',
                        author: 'Другой автор',
                        progress: 0.32,
                        onTap: () => context.go('/reader/2'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Недавно добавленные'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _RecentlyAddedCard(
                        title: 'Новая книга',
                        onTap: () => context.go('/book/1'),
                      ),
                      const SizedBox(width: 12),
                      _RecentlyAddedCard(
                        title: 'Ещё одна книга',
                        onTap: () => context.go('/book/2'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Быстрые действия'),
                const SizedBox(height: 8),
                _QuickActionRow(
                  children: [
                    _QuickAction(
                      icon: Icons.download,
                      label: 'Загрузки',
                      onTap: () => context.go('/downloads'),
                    ),
                    _QuickAction(
                      icon: Icons.bookmark,
                      label: 'Закладки',
                      onTap: () => context.go('/bookmarks'),
                    ),
                    _QuickAction(
                      icon: Icons.settings,
                      label: 'Настройки',
                      onTap: () => context.go('/settings'),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final String title;
  final String author;
  final double progress;
  final VoidCallback? onTap;

  const _ContinueReadingCard({
    required this.title,
    required this.author,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.menu_book,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  author,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _RecentlyAddedCard extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _RecentlyAddedCard({
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_stories,
                  size: 32,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _QuickActionRow extends StatelessWidget {
  final List<Widget> children;

  const _QuickActionRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filled(
          icon: Icon(icon),
          onPressed: onTap,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
