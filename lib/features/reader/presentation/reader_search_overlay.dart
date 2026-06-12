import 'package:flutter/material.dart';

import '../data/book_search_service.dart';
import '../domain/reader.dart';

class BookSearchOverlay extends StatefulWidget {
  const BookSearchOverlay({
    super.key,
    required this.searchService,
    required this.onJumpToResult,
    required this.onDismiss,
    required this.theme,
  });

  final BookSearchService searchService;
  final void Function(ReaderPosition position, String query) onJumpToResult;
  final VoidCallback onDismiss;
  final ReaderTheme theme;

  @override
  State<BookSearchOverlay> createState() => _BookSearchOverlayState();
}

class _BookSearchOverlayState extends State<BookSearchOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<BookSearchResult> _results = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final results = widget.searchService.search(query);
    setState(() {
      _results = results;
      _hasSearched = query.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.theme == ReaderTheme.dark ||
        widget.theme == ReaderTheme.oled ||
        widget.theme == ReaderTheme.bedtime ||
        widget.theme == ReaderTheme.system;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              color: bgColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: textColor,
                    onPressed: widget.onDismiss,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: TextStyle(color: textColor, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Поиск по книге…',
                        hintStyle: TextStyle(color: hintColor),
                        border: InputBorder.none,
                      ),
                      onChanged: _performSearch,
                      onSubmitted: _performSearch,
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      color: textColor,
                      onPressed: () {
                        _controller.clear();
                        _performSearch('');
                      },
                    ),
                ],
              ),
            ),
            if (_hasSearched && _results.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 48, color: hintColor),
                      const SizedBox(height: 12),
                      Text(
                        'Ничего не найдено',
                        style: TextStyle(color: textColor, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else if (_hasSearched)
              Expanded(
                child: ColoredBox(
                  color: bgColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return _buildResultTile(result, textColor, hintColor);
                    },
                  ),
                ),
              )
            else
              Expanded(
                child: ColoredBox(
                  color: bgColor,
                  child: Center(
                    child: Text(
                      'Введите запрос для поиска',
                      style: TextStyle(color: hintColor, fontSize: 14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(
    BookSearchResult result,
    Color textColor,
    Color hintColor,
  ) {
    return InkWell(
      onTap: () {
        widget.onJumpToResult(
          ReaderPosition(
            bookId: '',
            chapterIndex: result.chapterIndex,
            paragraphIndex: result.paragraphIndex,
            updatedAt: DateTime.now(),
          ),
          _controller.text.trim(),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.chapterTitle.isNotEmpty
                  ? result.chapterTitle
                  : 'Глава ${result.chapterIndex + 1}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.matchText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: textColor.withValues(alpha: 0.1)),
          ],
        ),
      ),
    );
  }
}
