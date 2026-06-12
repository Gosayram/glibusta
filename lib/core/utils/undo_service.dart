import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UndoAction {
  const UndoAction({
    required this.description,
    required this.undo,
    required this.timestamp,
  });

  final String description;
  final Future<void> Function() undo;
  final DateTime timestamp;
}

class UndoStack {
  UndoStack({this.maxSize = 20});

  final int maxSize;
  final List<UndoAction> _stack = [];
  Timer? _autoClearTimer;

  List<UndoAction> get actions => List.unmodifiable(_stack);
  bool get isEmpty => _stack.isEmpty;
  int get length => _stack.length;

  void push(UndoAction action) {
    _stack.add(action);
    if (_stack.length > maxSize) {
      _stack.removeAt(0);
    }
    _resetAutoClear();
  }

  Future<bool> undoLast() async {
    if (_stack.isEmpty) return false;
    final action = _stack.removeLast();
    try {
      await action.undo();
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  void clear() {
    _stack.clear();
    _autoClearTimer?.cancel();
  }

  void _resetAutoClear() {
    _autoClearTimer?.cancel();
    _autoClearTimer = Timer(const Duration(minutes: 5), clear);
  }

  void dispose() {
    _autoClearTimer?.cancel();
  }
}

class UndoService {
  UndoService() {
    _undoStack = UndoStack();
  }

  late final UndoStack _undoStack;

  List<UndoAction> get actions => _undoStack.actions;
  bool get isEmpty => _undoStack.isEmpty;

  void push(String description, Future<void> Function() undo) {
    _undoStack.push(
      UndoAction(
        description: description,
        undo: undo,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<bool> undoLast() => _undoStack.undoLast();

  void clear() => _undoStack.clear();
}

class UndoHelper {
  static void showUndoSnackBar(
    BuildContext context, {
    required String message,
    required Future<void> Function() onUndo,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () async {
            await onUndo();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Действие отменено')),
              );
            }
          },
        ),
      ),
    );
  }
}

// --- Riverpod providers ---

final undoServiceProvider = Provider<UndoService>((ref) {
  final service = UndoService();
  ref.onDispose(service.clear);
  return service;
});
