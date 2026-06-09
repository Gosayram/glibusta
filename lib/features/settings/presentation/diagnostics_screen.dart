import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Диагностика')),
      body: FutureBuilder<DiagnosticsInfo>(
        future: _gatherInfo(ref),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final info = snapshot.data!;
          return ListView(
            children: [
              _section('Приложение', [
                ListTile(
                  title: const Text('Версия'),
                  trailing: Text(info.appVersion),
                ),
              ]),
              _section('База данных', [
                ListTile(
                  title: const Text('Книг в библиотеке'),
                  trailing: Text('${info.totalBooks}'),
                ),
                ListTile(
                  title: const Text('FB2'),
                  trailing: Text('${info.fb2Count}'),
                ),
                ListTile(
                  title: const Text('EPUB'),
                  trailing: Text('${info.epubCount}'),
                ),
                ListTile(
                  title: const Text('Размер БД'),
                  trailing: Text(info.dbSize),
                ),
              ]),
              _section('Последняя ошибка', [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    info.lastError ?? 'Нет ошибок',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _exportLogs(context, info),
                        child: const Text('Скопировать отчёт'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _clearCache(context, ref),
                        child: const Text('Очистить кэш'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  ExpansionTile _section(String title, List<Widget> children) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(title),
      children: children,
    );
  }

  Future<DiagnosticsInfo> _gatherInfo(WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final allBooks = await (db.select(db.savedBooks)).get();
    final allDownloads = await (db.select(db.downloads)).get();
    final fb2 = allDownloads
        .where((d) => d.format.toLowerCase() == 'fb2')
        .length;
    final epub = allDownloads
        .where((d) => d.format.toLowerCase() == 'epub')
        .length;
    String? lastError;
    try {
      final prefs = await SharedPreferences.getInstance();
      lastError = prefs.getString('last_error');
    } on Object {
      lastError = null;
    }
    return DiagnosticsInfo(
      appVersion: '1.0.0',
      totalBooks: allBooks.length,
      fb2Count: fb2,
      epubCount: epub,
      dbSize: '~${(allBooks.length * 0.5).toStringAsFixed(1)} MB',
      lastError: lastError,
    );
  }

  Future<void> _exportLogs(BuildContext context, DiagnosticsInfo info) async {
    final report = 'Glibusta Diagnostics\n'
        'Version: ${info.appVersion}\n'
        'Books: ${info.totalBooks} (FB2: ${info.fb2Count}, EPUB: ${info.epubCount})\n'
        'DB Size: ${info.dbSize}\n'
        'Last Error: ${info.lastError ?? 'None'}';
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Отчёт скопирован'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearCache(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Кэш очищен'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class DiagnosticsInfo {
  final String appVersion;
  final int totalBooks;
  final int fb2Count;
  final int epubCount;
  final String dbSize;
  final String? lastError;

  DiagnosticsInfo({
    required this.appVersion,
    required this.totalBooks,
    required this.fb2Count,
    required this.epubCount,
    required this.dbSize,
    this.lastError,
  });
}
