import '../domain/reader.dart';

/// In-memory back/forward history for explicit intra-book link navigation.
///
/// It intentionally contains only positions reached through a reader link;
/// normal scrolling and page turns must not make the system Back action behave
/// like browser history.
final class ReaderLinkHistory {
  final List<ReaderPosition> _back = [];
  final List<ReaderPosition> _forward = [];

  bool get canGoBack => _back.isNotEmpty;
  bool get canGoForward => _forward.isNotEmpty;

  void pushOrigin(ReaderPosition position) {
    _back.add(position);
    _forward.clear();
  }

  ReaderPosition? goBack(ReaderPosition currentPosition) {
    if (_back.isEmpty) return null;
    _forward.add(currentPosition);
    return _back.removeLast();
  }

  ReaderPosition? goForward(ReaderPosition currentPosition) {
    if (_forward.isEmpty) return null;
    _back.add(currentPosition);
    return _forward.removeLast();
  }

  void clear() {
    _back.clear();
    _forward.clear();
  }
}
