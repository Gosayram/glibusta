import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../src/rust/api/api/api.dart' as rust_api;
import 'djvu_zoom.dart';

/// Loads the number of pages in a DjVu document.
typedef DjvuPageCountLoader = Future<int> Function(String path);

/// Renders one DjVu page to a bounded PNG thumbnail.
typedef DjvuThumbnailLoader =
    Future<Uint8List> Function({
      required String path,
      required int pageIndex,
      required int maxWidth,
    });

class DjvuReaderScreen extends StatefulWidget {
  const DjvuReaderScreen({
    super.key,
    required this.filePath,
    this.pageCountLoader = _defaultPageCountLoader,
    this.thumbnailLoader = _defaultThumbnailLoader,
  });

  final String filePath;
  final DjvuPageCountLoader pageCountLoader;
  final DjvuThumbnailLoader thumbnailLoader;

  @override
  State<DjvuReaderScreen> createState() => _DjvuReaderScreenState();
}

class _DjvuReaderScreenState extends State<DjvuReaderScreen> {
  int _totalPages = 0;
  int _currentPage = 1;
  Uint8List? _currentImage;
  bool _loading = true;
  String? _error;
  int _documentRequest = 0;
  int _pageRequest = 0;
  final TransformationController _zoomController = TransformationController();
  double _reportedZoom = DjvuZoom.min;

  @override
  void dispose() {
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _zoomController.addListener(_onZoomChanged);
    unawaited(_loadDocument());
  }

  @override
  void didUpdateWidget(covariant DjvuReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath == widget.filePath) return;

    _documentRequest++;
    _pageRequest++;
    _resetZoom();
    setState(() {
      _totalPages = 0;
      _currentPage = 1;
      _currentImage = null;
      _loading = true;
      _error = null;
    });
    unawaited(_loadDocument());
  }

  Future<void> _loadDocument() async {
    final documentRequest = ++_documentRequest;
    final file = File(widget.filePath);
    if (!file.existsSync()) {
      if (!mounted || documentRequest != _documentRequest) return;
      setState(() {
        _error = 'Файл не найден';
        _loading = false;
      });
      return;
    }
    try {
      final count = await widget.pageCountLoader(widget.filePath);
      if (!mounted || documentRequest != _documentRequest) return;
      if (count <= 0) {
        setState(() {
          _error = 'В документе нет страниц';
          _loading = false;
        });
        return;
      }
      setState(() => _totalPages = count);
      await _renderPage(_currentPage, documentRequest);
    } on Object catch (e) {
      if (!mounted || documentRequest != _documentRequest) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _renderPage(int pageNum, [int? documentRequest]) async {
    final expectedDocumentRequest = documentRequest ?? _documentRequest;
    final pageRequest = ++_pageRequest;
    setState(() => _loading = true);
    try {
      final png = await widget.thumbnailLoader(
        path: widget.filePath,
        pageIndex: pageNum - 1,
        maxWidth: 1080,
      );
      if (!mounted || expectedDocumentRequest != _documentRequest || pageRequest != _pageRequest) {
        return;
      }
      setState(() {
        _currentImage = png;
        _loading = false;
        _error = null;
      });
    } on Object catch (e) {
      if (!mounted || expectedDocumentRequest != _documentRequest || pageRequest != _pageRequest) {
        return;
      }
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    _resetZoom();
    setState(() => _currentPage = page);
    unawaited(_renderPage(page));
  }

  double get _zoom => _zoomController.value.getMaxScaleOnAxis();

  void _onZoomChanged() {
    final zoom = _zoom;
    if ((zoom - _reportedZoom).abs() < 0.001) return;
    _reportedZoom = zoom;
    if (mounted) setState(() {});
  }

  void _setZoom(double zoom) {
    final boundedZoom = zoom.clamp(DjvuZoom.min, DjvuZoom.max);
    _zoomController.value = Matrix4.identity()
      ..scaleByDouble(boundedZoom, boundedZoom, boundedZoom, 1);
  }

  void _resetZoom() => _setZoom(DjvuZoom.reset());

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_totalPages > 0 ? 'Стр. $_currentPage / $_totalPages' : 'DjVu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Уменьшить масштаб',
            onPressed: _zoom > DjvuZoom.min ? () => _setZoom(DjvuZoom.zoomOut(_zoom)) : null,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Увеличить масштаб',
            onPressed: _zoom < DjvuZoom.max ? () => _setZoom(DjvuZoom.zoomIn(_zoom)) : null,
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Сбросить масштаб',
            onPressed: _zoom > DjvuZoom.min ? _resetZoom : null,
          ),
        ],
      ),
      body: _buildBody(context, colorScheme),
    );
  }

  int _cacheDim(BuildContext context, double displaySize) {
    return (displaySize * MediaQuery.devicePixelRatioOf(context)).round();
  }

  Widget _buildBody(BuildContext context, ColorScheme colorScheme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_loading && _currentImage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Semantics(
            image: true,
            label: _totalPages > 0
                ? 'Страница $_currentPage из $_totalPages. Масштаб ${(100 * _zoom).round()}%.'
                : 'Страница DjVu.',
            child: InteractiveViewer(
              transformationController: _zoomController,
              minScale: DjvuZoom.min,
              maxScale: DjvuZoom.max,
              child: _currentImage != null
                  ? Image.memory(
                      _currentImage!,
                      fit: BoxFit.contain,
                      cacheWidth: _cacheDim(context, MediaQuery.sizeOf(context).width),
                      cacheHeight: _cacheDim(context, MediaQuery.sizeOf(context).height),
                      errorBuilder: (_, _, _) => const Center(
                        child: Text('Ошибка рендеринга страницы'),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
        if (_totalPages > 1)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                  ),
                  Text('$_currentPage / $_totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _totalPages
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<int> _defaultPageCountLoader(String path) async {
  return rust_api.djvuPageCount(path: path);
}

Future<Uint8List> _defaultThumbnailLoader({
  required String path,
  required int pageIndex,
  required int maxWidth,
}) async {
  return rust_api.renderDjvuThumbnail(
    path: path,
    pageIndex: BigInt.from(pageIndex),
    maxWidth: BigInt.from(maxWidth),
  );
}
