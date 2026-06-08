import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Источник'),
            subtitle: Text('flibusta.site'),
          ),
          const ListTile(
            title: Text('Язык'),
            subtitle: Text('Русский'),
          ),
          const ListTile(
            title: Text('Тема'),
            subtitle: Text('Системная'),
          ),
          const ListTile(
            title: Text('Параллельные загрузки'),
            subtitle: Text('3'),
          ),
        ],
      ),
    );
  }
}