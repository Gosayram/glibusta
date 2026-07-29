import 'dart:async';

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
    this.currentChapterIndex,
    this.initialQuery,
  });

  final BookSearchService searchService;
  final void Function(ReaderPosition position, String query) onJumpToResult;
  final VoidCallback onDismiss;
  final ReaderTheme theme;
  final int? currentChapterIndex;
  final String? initialQuery;

  @override
  State<BookSearchOverlay> createState() => _BookSearchOverlayState();
}

class _BookSearchOverlayState extends State<BookSearchOverlay> {
  static const _contextExcerptLength = 96;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _debounce = _SearchDebounce();
  List<BookSearchResult> _results = [];
  bool _hasSearched = false;
  bool _isSearching = false;
  bool _searchCurrentChapter = false;
  bool _matchCase = false;
  var _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _onQueryChanged(widget.initialQuery!);
      }
    });
  }

  @override
  void dispose() {
    _debounce.cancel();
    widget.searchService.cancelPending();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    // The trailing clear action depends on the controller value, which does not
    // rebuild this widget by itself.
    setState(() {});
    if (query.trim().isEmpty) {
      _debounce.cancel();
      unawaited(_performSearch(''));
      return;
    }
    _debounce.run(() => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    final requestId = ++_searchRequestId;
    if (query.trim().isEmpty) {
      widget.searchService.cancelPending();
      setState(() {
        _results = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }
    widget.searchService.cancelPending();
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });
    final results = await widget.searchService.search(
      query,
      chapterIndex: _searchCurrentChapter ? widget.currentChapterIndex : null,
      matchCase: _matchCase,
    );
    if (!mounted || requestId != _searchRequestId) return;
    setState(() {
      _results = results;
      _isSearching = false;
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
                      onChanged: _onQueryChanged,
                      onSubmitted: _performSearch,
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      color: textColor,
                      onPressed: () {
                        _debounce.cancel();
                        _controller.clear();
                        unawaited(_performSearch(''));
                      },
                    ),
                  if (widget.currentChapterIndex != null)
                    IconButton(
                      icon: Icon(
                        _searchCurrentChapter ? Icons.book : Icons.menu_book,
                        size: 20,
                      ),
                      color: _searchCurrentChapter ? Colors.blue : textColor,
                      tooltip: _searchCurrentChapter ? 'Текущая глава' : 'Вся книга',
                      onPressed: () {
                        setState(() => _searchCurrentChapter = !_searchCurrentChapter);
                        if (_controller.text.isNotEmpty) {
                          unawaited(_performSearch(_controller.text));
                        }
                      },
                    ),
                  IconButton(
                    icon: Text(
                      'Aa',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _matchCase ? FontWeight.w700 : FontWeight.w400,
                        color: _matchCase ? Colors.blue : textColor,
                      ),
                    ),
                    tooltip: _matchCase ? 'С учётом регистра' : 'Без регистра',
                    onPressed: () {
                      setState(() => _matchCase = !_matchCase);
                      if (_controller.text.isNotEmpty) {
                        unawaited(_performSearch(_controller.text));
                      }
                    },
                  ),
                ],
              ),
            ),
            if (_results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  '${_results.length} результатов в ${widget.searchService.totalParagraphs} абзацах',
                  style: TextStyle(color: hintColor, fontSize: 12),
                ),
              ),
            if (_isSearching)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hasSearched && _results.isEmpty)
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
    final chapterTitle = result.chapterTitle.isNotEmpty
        ? result.chapterTitle
        : 'Глава ${result.chapterIndex + 1}';
    final beforeContext = _contextExcerpt(result.beforeContext, keepEnd: true);
    final afterContext = _contextExcerpt(result.afterContext);

    return Semantics(
      button: true,
      label: _semanticsLabel(
        chapterTitle: chapterTitle,
        result: result,
        beforeContext: beforeContext,
        afterContext: afterContext,
      ),
      onTap: () => _jumpToResult(result),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => _jumpToResult(result),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapterTitle,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                if (beforeContext.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    beforeContext,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hintColor,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
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
                if (afterContext.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    afterContext,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hintColor,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Divider(height: 1, color: textColor.withValues(alpha: 0.1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _jumpToResult(BookSearchResult result) {
    widget.onJumpToResult(
      ReaderPosition(
        bookId: '',
        chapterIndex: result.chapterIndex,
        paragraphIndex: result.paragraphIndex,
        updatedAt: DateTime.now(),
      ),
      _controller.text.trim(),
    );
  }

  String _contextExcerpt(String text, {bool keepEnd = false}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= _contextExcerptLength) return normalized;
    if (keepEnd) {
      return '…${normalized.substring(normalized.length - _contextExcerptLength)}';
    }
    return '${normalized.substring(0, _contextExcerptLength)}…';
  }

  String _semanticsLabel({
    required String chapterTitle,
    required BookSearchResult result,
    required String beforeContext,
    required String afterContext,
  }) {
    final parts = <String>[
      'Результат поиска. $chapterTitle.',
      result.matchText,
      if (beforeContext.isNotEmpty) 'Перед: $beforeContext.',
      if (afterContext.isNotEmpty) 'После: $afterContext.',
    ];
    return parts.join(' ');
  }
}

class _SearchDebounce {
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
