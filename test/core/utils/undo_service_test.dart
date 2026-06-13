import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/utils/undo_service.dart';

void main() {
  group('UndoStack', () {
    test('starts empty', () {
      final stack = UndoStack();
      expect(stack.isEmpty, isTrue);
      expect(stack.length, 0);
      expect(stack.actions, isEmpty);
      stack.dispose();
    });

    test('push adds action', () {
      final stack = UndoStack();
      stack.push(
        UndoAction(
          description: 'test',
          undo: () async {},
          timestamp: DateTime.now(),
        ),
      );
      expect(stack.length, 1);
      expect(stack.isEmpty, isFalse);
      stack.dispose();
    });

    test('undoLast returns true and executes action', () async {
      var undone = false;
      final stack = UndoStack();
      stack.push(
        UndoAction(
          description: 'test',
          undo: () async => undone = true,
          timestamp: DateTime.now(),
        ),
      );
      final result = await stack.undoLast();
      expect(result, isTrue);
      expect(undone, isTrue);
      expect(stack.isEmpty, isTrue);
      stack.dispose();
    });

    test('undoLast returns false when empty', () async {
      final stack = UndoStack();
      final result = await stack.undoLast();
      expect(result, isFalse);
      stack.dispose();
    });

    test('respects maxSize', () {
      final stack = UndoStack(maxSize: 2);
      for (var i = 0; i < 5; i++) {
        stack.push(
          UndoAction(
            description: 'item $i',
            undo: () async {},
            timestamp: DateTime.now(),
          ),
        );
      }
      expect(stack.length, 2);
      expect(stack.actions.last.description, 'item 4');
      stack.dispose();
    });

    test('clear empties stack', () {
      final stack = UndoStack();
      stack.push(
        UndoAction(
          description: 'test',
          undo: () async {},
          timestamp: DateTime.now(),
        ),
      );
      stack.clear();
      expect(stack.isEmpty, isTrue);
      stack.dispose();
    });

    test('undoLast handles undo failure gracefully', () async {
      final stack = UndoStack();
      stack.push(
        UndoAction(
          description: 'fail',
          undo: () async => throw Exception('fail'),
          timestamp: DateTime.now(),
        ),
      );
      final result = await stack.undoLast();
      expect(result, isFalse);
      expect(stack.isEmpty, isTrue);
      stack.dispose();
    });
  });

  group('UndoService', () {
    test('push and undoLast', () async {
      final service = UndoService();
      var undone = false;
      service.push('desc', () async => undone = true);
      expect(service.isEmpty, isFalse);
      final result = await service.undoLast();
      expect(result, isTrue);
      expect(undone, isTrue);
      expect(service.isEmpty, isTrue);
    });

    test('clear empties', () {
      final service = UndoService();
      service.push('test', () async {});
      service.clear();
      expect(service.isEmpty, isTrue);
    });
  });
}
