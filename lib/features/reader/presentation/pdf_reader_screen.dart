import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Returns whether [link] can be resolved within the opened document.
///
/// PDF URI actions are deliberately not forwarded to a platform launcher: a
/// local book must not be able to trigger a browser, intent, or other external
/// application. Only bounded in-document destinations are actionable.
@visibleForTesting
bool isSafePdfLink(PdfLink link, int pageCount) {
  final destination = link.dest;
  return link.url == null &&
      destination != null &&
      destination.pageNumber >= 1 &&
      destination.pageNumber <= pageCount;
}

/// Whether the PDF backend can extract any text from the opened document.
///
/// Image-only scans still render normally, but must not imply that search or
/// assistive-text features are available. Whitespace-only extraction is also
/// treated as unavailable because it cannot be searched or announced usefully.
@visibleForTesting
enum PdfTextAvailability {
  available,
  unavailable;

  static PdfTextAvailability fromPageTexts(Iterable<String> pageTexts) {
    return pageTexts.any((text) => text.trim().isNotEmpty)
        ? PdfTextAvailability.available
        : PdfTextAvailability.unavailable;
  }
}

/// The small opening sample keeps scan detection from extracting every page of
/// a large PDF before the reader becomes interactive.
@visibleForTesting
const pdfTextAvailabilitySamplePageLimit = 10;

/// Checks only the opening pages supplied by [pageTextLoaders].
///
/// Keeping this separate from the PDF backend makes the bounded-work contract
/// directly regression-testable without a large PDF fixture.
@visibleForTesting
Future<PdfTextAvailability> detectPdfTextAvailability(
  Iterable<Future<String> Function()> pageTextLoaders,
) async {
  for (final loadText in pageTextLoaders.take(pdfTextAvailabilitySamplePageLimit)) {
    if ((await loadText()).trim().isNotEmpty) {
      return PdfTextAvailability.available;
    }
  }
  return PdfTextAvailability.unavailable;
}

class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({
    required this.filePath,
    this.initialPage = 1,
    @visibleForTesting this.testViewer,
    @visibleForTesting this.testTextAvailabilityLoader,
    super.key,
  });

  final String filePath;
  final int initialPage;

  /// Replaces the native PDFium-backed viewer in widget tests.
  ///
  /// Production callers leave this null and use [PdfViewer.file].
  final Widget? testViewer;

  /// Reports text availability without opening a native PDF document in tests.
  final Future<PdfTextAvailability> Function()? testTextAvailabilityLoader;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late final PdfViewerController _controller;
  PdfTextSearcher? _searcher;
  final _searchController = TextEditingController();
  bool _showSearch = false;
  int? _currentPage;
  int? _totalPages;
  PdfTextAvailability? _textAvailability;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    final textAvailabilityLoader = widget.testTextAvailabilityLoader;
    if (textAvailabilityLoader != null) {
      unawaited(_loadTestTextAvailability(textAvailabilityLoader));
    }
  }

  @override
  void dispose() {
    _searcher?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.filePath);
    if (!file.existsSync()) {
      return Scaffold(
        appBar: AppBar(title: const Text('PDF')),
        body: Center(child: Text('Файл не найден: ${widget.filePath}')),
      );
    }

    final searcher = _searcher ??= PdfTextSearcher(_controller);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _textAvailability == PdfTextAvailability.unavailable
                ? null
                : () => setState(() => _showSearch = !_showSearch),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'fit_width', child: Text('По ширине')),
              const PopupMenuItem(value: 'fit_page', child: Text('Вся страница')),
              const PopupMenuItem(value: 'first', child: Text('Первая страница')),
              const PopupMenuItem(value: 'last', child: Text('Последняя страница')),
              if (_currentPage != null && _totalPages != null)
                PopupMenuItem(
                  value: 'go_to',
                  child: Text('Перейти ($_currentPage/$_totalPages)'),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          widget.testViewer ??
              PdfViewer.file(
                widget.filePath,
                controller: _controller,
                initialPageNumber: widget.initialPage,
                params: PdfViewerParams(
                  backgroundColor: colorScheme.surface,
                  margin: 4,
                  textSelectionParams: const PdfTextSelectionParams(),
                  sizeDelegateProvider: const PdfViewerSizeDelegateProviderLegacy(
                    maxScale: 8.0,
                    minScale: 0.1,
                    useAlternativeFitScaleAsMinScale: true,
                    onePassRenderingScaleThreshold: 200 / 72,
                  ),
                  scrollPhysics: const FixedOverscrollPhysics(maxOverscroll: 120),
                  onPageChanged: (pageNumber) {
                    if (mounted) setState(() => _currentPage = pageNumber);
                  },
                  onDocumentChanged: (document) {
                    if (document != null && mounted) {
                      setState(() => _totalPages = document.pages.length);
                    }
                  },
                  onDocumentLoadFinished: (documentRef, loadSucceeded) {
                    if (!loadSucceeded || !mounted) return;
                    final doc = documentRef.resolveListenable().document;
                    if (doc != null && mounted) {
                      setState(() => _totalPages = doc.pages.length);
                      unawaited(_detectTextAvailability(doc));
                    }
                  },
                  pagePaintCallbacks: [
                    searcher.pageTextMatchPaintCallback,
                  ],
                  viewerOverlayBuilder: (context, size, handleLinkTap) {
                    return [
                      Positioned(
                        right: 8,
                        top: size.height * 0.1,
                        bottom: size.height * 0.1,
                        child: PdfViewerScrollThumb(controller: _controller),
                      ),
                      Positioned(
                        bottom: 8,
                        left: size.width * 0.1,
                        right: size.width * 0.1,
                        child: PdfViewerScrollThumb(
                          controller: _controller,
                          orientation: ScrollbarOrientation.bottom,
                        ),
                      ),
                    ];
                  },
                  pageOverlaysBuilder: (context, pageRect, page) {
                    return [
                      Positioned(
                        bottom: 4,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${page.pageNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                  loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: totalBytes != null ? bytesDownloaded / totalBytes : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            totalBytes != null
                                ? '${(bytesDownloaded / 1024).toStringAsFixed(0)} KB / ${(totalBytes / 1024).toStringAsFixed(0)} KB'
                                : 'Загрузка...',
                          ),
                        ],
                      ),
                    );
                  },
                  errorBannerBuilder: (context, error, stackTrace, documentRef) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ошибка загрузки PDF',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$error',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                  linkHandlerParams: PdfLinkHandlerParams(
                    onLinkTap: (link) {
                      final destination = link.dest;
                      if (isSafePdfLink(link, _controller.pageCount) && destination != null) {
                        unawaited(_controller.goToDest(destination));
                      }
                    },
                  ),
                  getPageRenderingScale: (context, page, controller, estimatedScale) {
                    final w = page.width * estimatedScale;
                    final h = page.height * estimatedScale;
                    if (w > 4096 || h > 4096) {
                      return (200 / 72.0).clamp(
                        estimatedScale * 0.5,
                        estimatedScale,
                      );
                    }
                    return estimatedScale;
                  },
                  buildContextMenu: (context, params) {
                    if (!params.isTextSelectionEnabled) return null;
                    return PopupMenuButton<String>(
                      onSelected: (value) {
                        params.dismissContextMenu();
                        if (value == 'copy') {
                          unawaited(
                            params.textSelectionDelegate.copyTextSelection(),
                          );
                        } else if (value == 'clear') {
                          unawaited(
                            params.textSelectionDelegate.clearTextSelection(),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'copy',
                          child: Text('Копировать'),
                        ),
                        const PopupMenuItem(
                          value: 'clear',
                          child: Text('Снять выделение'),
                        ),
                      ],
                    );
                  },
                ),
              ),
          if (_showSearch)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _SearchOverlay(
                searcher: searcher,
                searchController: _searchController,
                onClose: () => setState(() => _showSearch = false),
              ),
            ),
          if (_textAvailability == PdfTextAvailability.unavailable)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Semantics(
                excludeSemantics: true,
                liveRegion: true,
                label: 'В PDF не найден извлекаемый текст. Поиск и копирование недоступны.',
                child: const _NoExtractablePdfTextNotice(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _detectTextAvailability(PdfDocument document) async {
    try {
      final availability = await detectPdfTextAvailability(
        document.pages.map(
          (page) =>
              () async => (await page.loadStructuredText()).fullText,
        ),
      );
      if (!mounted) return;
      setState(() {
        _textAvailability = availability;
        if (availability == PdfTextAvailability.available) return;
        _showSearch = false;
      });
    } on Object {
      // Keep the viewer usable when a malformed page cannot expose text. It is
      // more accurate to leave availability unknown than to label it a scan.
    }
  }

  Future<void> _loadTestTextAvailability(
    Future<PdfTextAvailability> Function() loadTextAvailability,
  ) async {
    try {
      final availability = await loadTextAvailability();
      if (!mounted) return;
      setState(() {
        _textAvailability = availability;
        if (availability == PdfTextAvailability.unavailable) {
          _showSearch = false;
        }
      });
    } on Object {
      // A test loader has the same best-effort semantics as native extraction.
    }
  }

  String get _appBarTitle {
    if (_currentPage != null && _totalPages != null) {
      return 'Стр. $_currentPage / $_totalPages';
    }
    return 'PDF';
  }

  Future<void> _handleMenuAction(String action) async {
    if (!_controller.isReady) return;
    switch (action) {
      case 'fit_width':
        final zoom = _controller.viewSize.width / _controller.documentSize.width;
        await _controller.setZoom(_controller.visibleRect.center, zoom);
        break;
      case 'fit_page':
        final altScale = _controller.alternativeFitScale;
        if (altScale != null) {
          await _controller.goTo(
            _controller.calcMatrixFor(
              _controller.visibleRect.center,
              zoom: altScale,
            ),
          );
        }
        break;
      case 'first':
        await _controller.goToPage(pageNumber: 1);
        break;
      case 'last':
        await _controller.goToPage(pageNumber: _controller.pageCount);
        break;
      case 'go_to':
        final page = await _showGoToPageDialog();
        if (page != null) {
          await _controller.goToPage(pageNumber: page);
        }
        break;
    }
  }

  Future<int?> _showGoToPageDialog() async {
    final ctrl = TextEditingController(
      text: _currentPage?.toString() ?? '',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Перейти к странице'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 – ${_totalPages ?? "?"}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final p = int.tryParse(ctrl.text);
              if (p != null && p > 0) Navigator.pop(context, p);
            },
            child: const Text('Перейти'),
          ),
        ],
      ),
    );
    return result;
  }
}

class _NoExtractablePdfTextNotice extends StatelessWidget {
  const _NoExtractablePdfTextNotice();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'В PDF не найден извлекаемый текст. Поиск и копирование недоступны.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SearchOverlay extends StatefulWidget {
  final PdfTextSearcher searcher;
  final TextEditingController searchController;
  final VoidCallback onClose;

  const _SearchOverlay({
    required this.searcher,
    required this.searchController,
    required this.onClose,
  });

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  void _listener() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.searcher.addListener(_listener);
  }

  @override
  void dispose() {
    widget.searcher.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = widget.searcher.matches;
    final currentIndex = widget.searcher.currentIndex;
    final count = matches.length;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Поиск в тексте...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: widget.searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              widget.searchController.clear();
                              widget.searcher.resetTextSearch();
                              setState(() {});
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) {
                    widget.searcher.startTextSearch(
                      value,
                      searchImmediately: true,
                    );
                  },
                  onSubmitted: (value) {
                    widget.searcher.startTextSearch(
                      value,
                      searchImmediately: true,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (count > 0)
                Text(
                  '${currentIndex != null ? currentIndex + 1 : 0}/$count',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 22),
                onPressed: count > 0 ? () => widget.searcher.goToPrevMatch() : null,
                tooltip: 'Предыдущее',
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                onPressed: count > 0 ? () => widget.searcher.goToNextMatch() : null,
                tooltip: 'Следующее',
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                onPressed: () {
                  widget.searcher.resetTextSearch();
                  widget.onClose();
                },
                tooltip: 'Закрыть',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
