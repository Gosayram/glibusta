#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  final l10nDir = Directory('lib/l10n');
  if (!l10nDir.existsSync()) {
    print('Error: lib/l10n directory not found');
    exit(1);
  }

  final arbFiles =
      l10nDir.listSync().whereType<File>().where((f) => f.path.endsWith('.arb')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (arbFiles.isEmpty) {
    print('No ARB files found');
    exit(1);
  }

  print('Found ${arbFiles.length} ARB files:');
  for (final f in arbFiles) {
    print('  ${f.path.split('/').last}');
  }

  final allKeys = <String, Set<String>>{};
  final baseKeys = <String>{};

  for (final file in arbFiles) {
    final content = file.readAsStringSync();
    final keys = _extractKeys(content);
    final fileName = file.path.split('/').last;

    allKeys[fileName] = keys;

    if (fileName == 'app_en.arb') {
      baseKeys.addAll(keys);
    }
  }

  final baseFile = arbFiles.firstWhere(
    (f) => f.path.split('/').last == 'app_en.arb',
    orElse: () => arbFiles.first,
  );
  baseKeys.addAll(allKeys[baseFile.path.split('/').last] ?? {});

  print('\nBase keys (${baseKeys.length}):');
  for (final key in baseKeys.toList()..sort()) {
    print('  $key');
  }

  final issues = <String>[];

  for (final entry in allKeys.entries) {
    final fileName = entry.key;
    final keys = entry.value;

    if (fileName == 'app_en.arb') continue;

    final missing = baseKeys.difference(keys);
    final extra = keys.difference(baseKeys);

    if (missing.isNotEmpty) {
      issues.add('$fileName: missing ${missing.length} keys: ${missing.join(', ')}');
    }
    if (extra.isNotEmpty) {
      issues.add('$fileName: extra ${extra.length} keys: ${extra.join(', ')}');
    }
  }

  if (issues.isEmpty) {
    print('\nAll ARB files are in sync!');
  } else {
    print('\nIssues found:');
    for (final issue in issues) {
      print('  $issue');
    }
  }

  final untranslatedFile = File('untranslated_messages.txt');
  final untranslated = <String>[];

  for (final entry in allKeys.entries) {
    final fileName = entry.key;
    if (fileName == 'app_en.arb') continue;

    final missing = baseKeys.difference(entry.value);
    for (final key in missing) {
      untranslated.add('$fileName: $key');
    }
  }

  if (untranslated.isNotEmpty) {
    untranslatedFile.writeAsStringSync('${untranslated.join('\n')}\n');
    print('\nUntranslated messages written to untranslated_messages.txt');
  } else {
    if (untranslatedFile.existsSync()) {
      untranslatedFile.deleteSync();
    }
    print('\nNo untranslated messages found');
  }
}

Set<String> _extractKeys(String content) {
  final keys = <String>{};
  final regex = RegExp(r'"(@?[a-zA-Z_][a-zA-Z0-9_]*)"\s*:');
  for (final match in regex.allMatches(content)) {
    final key = match.group(1);
    if (key != null && !key.startsWith('@')) {
      keys.add(key);
    }
  }
  return keys;
}
