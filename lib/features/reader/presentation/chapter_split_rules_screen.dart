import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../data/chapter_split_rule.dart';
import '../data/chapter_split_service.dart';

class ChapterSplitRulesScreen extends ConsumerStatefulWidget {
  const ChapterSplitRulesScreen({super.key});

  @override
  ConsumerState<ChapterSplitRulesScreen> createState() => _ChapterSplitRulesScreenState();
}

class _ChapterSplitRulesScreenState extends ConsumerState<ChapterSplitRulesScreen> {
  late final ChapterSplitService _service;
  final _testController = TextEditingController();
  ChapterSplitRule? _testResult;

  @override
  void initState() {
    super.initState();
    _service = ref.read(chapterSplitServiceProvider);
  }

  @override
  void dispose() {
    _testController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chapter Split Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRuleDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Test Pattern'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _testController,
                    decoration: const InputDecoration(
                      labelText: 'Paste sample text',
                      border: OutlineInputBorder(),
                      hintText: 'Chapter 1: The Beginning\nChapter 2: The End',
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _testPattern,
                        child: const Text('Test'),
                      ),
                      if (_testResult != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Matched: ${_testResult!.name}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Presets'),
          ...ChapterSplitRule.presets.map(
            (rule) => _RuleTile(
              rule: rule,
              onTest: () => _testWithRule(rule),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Custom Rules'),
          ..._service.rules
              .where((r) => !r.isPreset)
              .map(
                (rule) => _RuleTile(
                  rule: rule,
                  onTest: () => _testWithRule(rule),
                  onDelete: () => _deleteRule(rule),
                  onEdit: () => _showEditRuleDialog(context, rule),
                ),
              ),
        ],
      ),
    );
  }

  void _testPattern() {
    final text = _testController.text;
    if (text.isEmpty) return;
    setState(() {
      _testResult = _service.detectPattern(text);
    });
  }

  void _testWithRule(ChapterSplitRule rule) {
    final text = _testController.text;
    if (text.isEmpty) return;
    final matches = text.split('\n').where((line) => rule.matchesLine(line.trim())).toList();
    setState(() {
      _testResult = rule;
    });
    unawaited(SmartDialog.showToast('Pattern "${rule.name}" matches ${matches.length} lines'));
  }

  void _showAddRuleDialog(BuildContext context) {
    final nameController = TextEditingController();
    final patternController = TextEditingController();
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add Custom Rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'Pattern (regex)',
                  border: OutlineInputBorder(),
                  hintText: r'^Chapter\s+\d+',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && patternController.text.isNotEmpty) {
                  _service.addRule(
                    ChapterSplitRule(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: nameController.text,
                      pattern: patternController.text,
                    ),
                  );
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRuleDialog(BuildContext context, ChapterSplitRule rule) {
    final nameController = TextEditingController(text: rule.name);
    final patternController = TextEditingController(text: rule.pattern);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Edit Rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                  labelText: 'Pattern (regex)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && patternController.text.isNotEmpty) {
                  _service.updateRule(
                    ChapterSplitRule(
                      id: rule.id,
                      name: nameController.text,
                      pattern: patternController.text,
                      isPreset: rule.isPreset,
                    ),
                  );
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRule(ChapterSplitRule rule) {
    _service.deleteRule(rule.id);
    setState(() {});
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onTest,
    this.onDelete,
    this.onEdit,
  });

  final ChapterSplitRule rule;
  final VoidCallback onTest;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(rule.name),
        subtitle: Text(
          rule.pattern,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 20),
              onPressed: onTest,
              tooltip: 'Test',
            ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
          ],
        ),
      ),
    );
  }
}
