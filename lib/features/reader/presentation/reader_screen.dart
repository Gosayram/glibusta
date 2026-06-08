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
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => _cycleTheme(ref),
          ),
          IconButton(
            icon: const Icon(Icons.text_format),
            onPressed: () => _increaseFontSize(ref),
          ),
        ],
      ),
      body: Center(
        child: Text('Reader for $bookId - coming soon'),
      ),
    );
  }

  void _cycleTheme(WidgetRef ref) {
    final current = ref.read(readerSettingsProvider).theme;
    final next = ReaderTheme.values[(current.index + 1) % ReaderTheme.values.length];
    ref.read(readerSettingsProvider.notifier).state = 
        ref.read(readerSettingsProvider).copyWith(theme: next);
  }

  void _increaseFontSize(WidgetRef ref) {
    final current = ref.read(readerSettingsProvider).fontSize;
    ref.read(readerSettingsProvider.notifier).state = 
        ref.read(readerSettingsProvider).copyWith(fontSize: current + 2);
  }
}

final readerSettingsProvider = StateProvider<ReaderSettings>((ref) {
  return const ReaderSettings();
});

final readingProgressProvider = StateProvider<ReadingProgress?>((ref) {
  return null;
});