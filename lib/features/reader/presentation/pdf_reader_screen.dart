import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

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
  void dispose() {
    _controller.dispose();
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

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
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
      body: PdfViewer.file(
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
            }
          },
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${page.pageNumber}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Ошибка загрузки PDF', style: Theme.of(context).textTheme.titleMedium),
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
              final url = link.url;
              if (url != null) {
                unawaited(launchUrl(url));
              }
            },
          ),
          getPageRenderingScale: (context, page, controller, estimatedScale) {
            final w = page.width * estimatedScale;
            final h = page.height * estimatedScale;
            if (w > 4096 || h > 4096) {
              return (200 / 72.0).clamp(estimatedScale * 0.5, estimatedScale);
            }
            return estimatedScale;
          },
          buildContextMenu: (context, params) {
            if (!params.isTextSelectionEnabled) return null;
            return PopupMenuButton<String>(
              onSelected: (value) {
                params.dismissContextMenu();
                if (value == 'copy') {
                  unawaited(params.textSelectionDelegate.copyTextSelection());
                } else if (value == 'clear') {
                  unawaited(params.textSelectionDelegate.clearTextSelection());
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'copy', child: Text('Копировать')),
                const PopupMenuItem(value: 'clear', child: Text('Снять выделение')),
              ],
            );
          },
        ),
      ),
    );
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
            _controller.calcMatrixFor(_controller.visibleRect.center, zoom: altScale),
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
    final ctrl = TextEditingController(text: _currentPage?.toString() ?? '');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Перейти к странице'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: '1 – ${_totalPages ?? "?"}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
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
