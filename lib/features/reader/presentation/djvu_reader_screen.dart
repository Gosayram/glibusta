import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../src/rust/api/api/api.dart' as rust_api;

class DjvuReaderScreen extends StatefulWidget {
  const DjvuReaderScreen({super.key, required this.filePath});

  final String filePath;

  @override
  State<DjvuReaderScreen> createState() => _DjvuReaderScreenState();
}

class _DjvuReaderScreenState extends State<DjvuReaderScreen> {
  int _totalPages = 0;
  int _currentPage = 1;
  Uint8List? _currentImage;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDocument());
  }

  Future<void> _loadDocument() async {
    final file = File(widget.filePath);
    if (!file.existsSync()) {
      setState(() {
        _error = 'Файл не найден';
        _loading = false;
      });
      return;
    }
    try {
      final count = await rust_api.djvuPageCount(path: widget.filePath);
      if (!mounted) return;
      setState(() => _totalPages = count);
      await _renderPage(_currentPage);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _renderPage(int pageNum) async {
    setState(() => _loading = true);
    try {
      final png = await rust_api.renderDjvuThumbnail(
        path: widget.filePath,
        pageIndex: BigInt.from(pageNum - 1),
        maxWidth: BigInt.from(1080),
      );
      if (!mounted) return;
      setState(() {
        _currentImage = png;
        _loading = false;
        _error = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    _currentPage = page;
    unawaited(_renderPage(page));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_totalPages > 0 ? 'Стр. $_currentPage / $_totalPages' : 'DjVu'),
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
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
          child: InteractiveViewer(
            child: _currentImage != null
                ? Image.memory(
                    _currentImage!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Text('Ошибка рендеринга страницы'),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
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
