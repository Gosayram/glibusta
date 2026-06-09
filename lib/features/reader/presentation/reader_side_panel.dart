import 'dart:async';

import 'package:flutter/material.dart';

import '../data/parsers/normalized_book.dart';

class ReaderSidePanel extends StatelessWidget {
  const ReaderSidePanel({
    super.key,
    required this.book,
    required this.currentChapterIndex,
    required this.scrollController,
    required this.width,
  });

  final NormalizedBook book;
  final int currentChapterIndex;
  final ScrollController scrollController;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Содержание'),
                Tab(text: 'Закладки'),
                Tab(text: 'Заметки'),
                Tab(text: 'Цитаты'),
              ],
              isScrollable: true,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTableOfContents(context),
                  const Center(child: Text('Нет закладок')),
                  const Center(child: Text('Нет заметок')),
                  const Center(child: Text('Нет цитат')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableOfContents(BuildContext context) {
    return ListView.builder(
      itemCount: book.chapters.length,
      itemBuilder: (context, index) {
        final chapter = book.chapters[index];
        final isActive = index == currentChapterIndex;
        return ListTile(
          title: Text(
            chapter.title.isNotEmpty ? chapter.title : 'Глава ${index + 1}',
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          dense: true,
          onTap: () {
            if (scrollController.hasClients) {
              final maxScroll = scrollController.position.maxScrollExtent;
              final targetOffset = (index / book.chapters.length) * maxScroll;
              unawaited(
                scrollController.animateTo(
                  targetOffset,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              );
            }
          },
        );
      },
    );
  }
}
