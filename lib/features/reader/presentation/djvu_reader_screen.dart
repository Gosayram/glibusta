import 'package:flutter/material.dart';

class DjvuReaderScreen extends StatelessWidget {
  const DjvuReaderScreen({super.key, required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DjVu')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_outlined, size: 56),
              const SizedBox(height: 16),
              // TODO(i18n): Replace hardcoded Russian strings with localized versions.
              Text(
                'DjVu распознан как отдельный постраничный формат.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // TODO(i18n): Replace hardcoded Russian strings with localized versions.
              const Text(
                'Встроенный DjVu-движок будет подключаться отдельно через native renderer '
                '(DjVuLibre или MuPDF). EPUB/FB2/RTF reader для этого формата не используется.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                filePath,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
