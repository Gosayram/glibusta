import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({
    required this.filePath,
    this.initialPage = 1,
    super.key,
  });

  final String filePath;
  final int initialPage;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late final PdfViewerController _controller;
  int? _currentPage;
  int? _totalPages;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _currentPage != null && _totalPages != null ? 'Стр. $_currentPage / $_totalPages' : 'PDF',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'fit_width',
                child: Text('По ширине'),
              ),
              const PopupMenuItem(
                value: 'fit_page',
                child: Text('Вся страница'),
              ),
            ],
          ),
        ],
      ),
      body: PdfViewer.file(
        widget.filePath,
        controller: _controller,
        initialPageNumber: widget.initialPage,
        params: PdfViewerParams(
          textSelectionParams: const PdfTextSelectionParams(
            enabled: true,
          ),
          backgroundColor: colorScheme.surface,
          margin: 4,
          maxScale: 8.0,
          minScale: 0.2,
          useAlternativeFitScaleAsMinScale: true,
          onePassRenderingScaleThreshold: 200 / 72,
          limitRenderingCache: true,
          enableKeyboardNavigation: true,
          scrollByMouseWheel: 0.2,
          onPageChanged: (pageNumber) {
            if (mounted) setState(() => _currentPage = pageNumber);
          },
          onDocumentChanged: (document) {
            if (document != null && mounted) {
              setState(() => _totalPages = document.pages.length);
            }
          },
          viewerOverlayBuilder: (context, size, handleLinkTap) {
            return [
              PdfViewerScrollThumb(
                controller: _controller,
                orientation: ScrollbarOrientation.right,
              ),
              PdfViewerScrollThumb(
                controller: _controller,
                orientation: ScrollbarOrientation.bottom,
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
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    totalBytes != null
                        ? 'Загрузка: ${(bytesDownloaded / 1024).toStringAsFixed(0)} KB / ${(totalBytes / 1024).toStringAsFixed(0)} KB'
                        : 'Загрузка...',
                    style: theme.textTheme.bodySmall,
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    'Ошибка загрузки PDF',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
          linkHandlerParams: PdfLinkHandlerParams(
            onLinkTap: (link) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ссылка: ${link.url}')),
              );
            },
          ),
          getPageRenderingScale: (context, page, controller, estimatedScale) {
            final width = page.width * estimatedScale;
            final height = page.height * estimatedScale;
            if (width > 4096 || height > 4096) {
              return (200 / 72.0).clamp(estimatedScale * 0.5, estimatedScale);
            }
            return estimatedScale;
          },
        ),
      ),
    );
  }

  void _zoomIn() {
    if (!_controller.isReady) return;
    final center = _controller.visibleRect.center;
    final zoom = _controller.currentZoom * 1.25;
    _controller.setZoom(center, zoom);
  }

  void _zoomOut() {
    if (!_controller.isReady) return;
    final center = _controller.visibleRect.center;
    final zoom = _controller.currentZoom * 0.8;
    _controller.setZoom(center, zoom);
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'fit_width':
        if (!_controller.isReady) return;
        final zoom = _controller.viewSize.width / _controller.documentSize.width;
        final center = _controller.visibleRect.center;
        _controller.setZoom(center, zoom);
        break;
      case 'fit_page':
        if (!_controller.isReady) return;
        final altScale = _controller.alternativeFitScale;
        if (altScale != null) {
          _controller.goTo(
            _controller.calcMatrixFor(
              _controller.visibleRect.center,
              zoom: altScale,
            ),
          );
        }
        break;
    }
  }
}
