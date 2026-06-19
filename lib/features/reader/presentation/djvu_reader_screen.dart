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
              Text(
                'DjVu is recognized as a separate paginated format.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'A built-in DjVu engine will be integrated separately via a native renderer '
                '(DjVuLibre or MuPDF). The EPUB/FB2/RTF reader is not used for this format.',
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
