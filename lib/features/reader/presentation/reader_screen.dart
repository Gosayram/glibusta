import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/reader.dart';

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Читалка'),
      ),
      body: Center(
        child: Text('Reader for $bookId - coming soon'),
      ),
    );
  }
}

final readerSettingsProvider = StateProvider<ReaderSettings>((ref) {
  return const ReaderSettings();
});

final readingProgressProvider = StateProvider<ReadingProgress?>((ref) {
  return null;
});