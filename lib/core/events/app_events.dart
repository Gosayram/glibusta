import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Base event ---

abstract class AppEvent {
  const AppEvent();
  String get name => runtimeType.toString();
  DateTime get timestamp => DateTime.now();
  Map<String, dynamic> toJson() => {'type': name, 'ts': timestamp.toIso8601String()};
}

// --- Typed events ---

class BookDownloadedEvent extends AppEvent {
  const BookDownloadedEvent({
    required this.bookId,
    required this.filePath,
    required this.sizeBytes,
  });
  final String bookId;
  final String filePath;
  final int sizeBytes;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'bookId': bookId,
    'filePath': filePath,
    'sizeBytes': sizeBytes,
  };
}

class BookImportedEvent extends AppEvent {
  const BookImportedEvent({required this.bookId, required this.format});
  final String bookId;
  final String format;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'bookId': bookId,
    'format': format,
  };
}

class BookDeletedEvent extends AppEvent {
  const BookDeletedEvent({required this.bookId, required this.filePath});
  final String bookId;
  final String filePath;
}

class BookOpenedEvent extends AppEvent {
  const BookOpenedEvent({required this.bookId, required this.format});
  final String bookId;
  final String format;
}

class ProgressChangedEvent extends AppEvent {
  const ProgressChangedEvent({
    required this.bookId,
    required this.chapterIndex,
    required this.totalChapters,
    required this.progressPercent,
  });
  final String bookId;
  final int chapterIndex;
  final int totalChapters;
  final double progressPercent;
}

class BookmarkCreatedEvent extends AppEvent {
  const BookmarkCreatedEvent({
    required this.bookId,
    required this.chapterIndex,
    required this.label,
  });
  final String bookId;
  final int chapterIndex;
  final String label;
}

class BookmarkDeletedEvent extends AppEvent {
  const BookmarkDeletedEvent({required this.bookId, required this.bookmarkId});
  final String bookId;
  final String bookmarkId;
}

class NoteCreatedEvent extends AppEvent {
  const NoteCreatedEvent({required this.bookId, required this.chapterIndex});
  final String bookId;
  final int chapterIndex;
}

class NoteDeletedEvent extends AppEvent {
  const NoteDeletedEvent({required this.bookId, required this.noteId});
  final String bookId;
  final String noteId;
}

class QuoteSavedEvent extends AppEvent {
  const QuoteSavedEvent({required this.bookId, required this.text});
  final String bookId;
  final String text;
}

class SearchPerformedEvent extends AppEvent {
  const SearchPerformedEvent({
    required this.query,
    required this.resultCount,
    required this.isOffline,
  });
  final String query;
  final int resultCount;
  final bool isOffline;
}

class CacheClearedEvent extends AppEvent {
  const CacheClearedEvent({required this.bytesFreed});
  final int bytesFreed;
}

class ErrorOccurredEvent extends AppEvent {
  const ErrorOccurredEvent({required this.source, required this.message, this.stackTrace});
  final String source;
  final String message;
  final String? stackTrace;
}

class SettingsChangedEvent extends AppEvent {
  const SettingsChangedEvent({required this.key, required this.value});
  final String key;
  final String value;
}

class DownloadFailedEvent extends AppEvent {
  const DownloadFailedEvent({required this.bookId, required this.reason});
  final String bookId;
  final String reason;
}

class IndexingCompletedEvent extends AppEvent {
  const IndexingCompletedEvent({
    required this.booksIndexed,
    required this.duplicatesFound,
    required this.durationMs,
  });
  final int booksIndexed;
  final int duplicatesFound;
  final int durationMs;
}

// --- Ring buffer ---

class RingBuffer<T> {
  RingBuffer(this._capacity);
  final int _capacity;
  final Queue<T> _queue = Queue<T>();

  int get length => _queue.length;
  bool get isFull => _queue.length >= _capacity;

  void add(T item) {
    if (isFull) {
      _queue.removeFirst();
    }
    _queue.addLast(item);
  }

  List<T> toList() => _queue.toList();

  T? get last => _queue.isEmpty ? null : _queue.last;

  void clear() => _queue.clear();
}

// --- Event bus ---

class EventBus {
  EventBus({int historySize = 100}) : _history = RingBuffer<AppEvent>(historySize);

  final _controller = StreamController<AppEvent>.broadcast();
  final RingBuffer<AppEvent> _history;

  Stream<AppEvent> get stream => _controller.stream;

  List<AppEvent> get history => _history.toList();
  AppEvent? get lastEvent => _history.last;

  void fire(AppEvent event) {
    if (_controller.isClosed) return;
    _history.add(event);
    _controller.add(event);
  }

  Stream<T> on<T extends AppEvent>() {
    return stream.where((e) => e is T).cast<T>();
  }

  void dispose() {
    unawaited(_controller.close());
  }
}

// --- Riverpod providers ---

final eventBusProvider = Provider<EventBus>((ref) {
  final bus = EventBus(historySize: 200);
  ref.onDispose(bus.dispose);
  return bus;
});
