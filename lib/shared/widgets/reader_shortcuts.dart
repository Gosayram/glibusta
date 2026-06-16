import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReaderShortcuts extends StatefulWidget {
  const ReaderShortcuts({
    super.key,
    required this.child,
    this.onNextPage,
    this.onPreviousPage,
    this.onIncreaseFontSize,
    this.onDecreaseFontSize,
    this.onSearch,
    this.onBookmarks,
    this.onLibrary,
    this.onSettings,
    this.onClosePanel,
  });

  final Widget child;
  final VoidCallback? onNextPage;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onIncreaseFontSize;
  final VoidCallback? onDecreaseFontSize;
  final VoidCallback? onSearch;
  final VoidCallback? onBookmarks;
  final VoidCallback? onLibrary;
  final VoidCallback? onSettings;
  final VoidCallback? onClosePanel;

  @override
  State<ReaderShortcuts> createState() => _ReaderShortcutsState();
}

class _ReaderShortcutsState extends State<ReaderShortcuts> {
  late Map<ShortcutActivator, Intent> _shortcuts;

  @override
  void initState() {
    super.initState();
    _shortcuts = {
      const SingleActivator(LogicalKeyboardKey.arrowRight): const NextPageIntent(),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): const PreviousPageIntent(),
      const SingleActivator(LogicalKeyboardKey.space): const NextPageIntent(),
      const SingleActivator(LogicalKeyboardKey.add): const IncreaseFontSizeIntent(),
      const SingleActivator(LogicalKeyboardKey.equal): const IncreaseFontSizeIntent(),
      const SingleActivator(LogicalKeyboardKey.minus): const DecreaseFontSizeIntent(),
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true): const SearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyB, meta: true): const BookmarksIntent(),
      const SingleActivator(LogicalKeyboardKey.keyL, meta: true): const LibraryIntent(),
      const SingleActivator(LogicalKeyboardKey.comma, meta: true): const SettingsIntent(),
      const SingleActivator(LogicalKeyboardKey.escape): const ClosePanelIntent(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          NextPageIntent: CallbackAction<NextPageIntent>(
            onInvoke: (_) => widget.onNextPage?.call(),
          ),
          PreviousPageIntent: CallbackAction<PreviousPageIntent>(
            onInvoke: (_) => widget.onPreviousPage?.call(),
          ),
          IncreaseFontSizeIntent: CallbackAction<IncreaseFontSizeIntent>(
            onInvoke: (_) => widget.onIncreaseFontSize?.call(),
          ),
          DecreaseFontSizeIntent: CallbackAction<DecreaseFontSizeIntent>(
            onInvoke: (_) => widget.onDecreaseFontSize?.call(),
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (_) => widget.onSearch?.call(),
          ),
          BookmarksIntent: CallbackAction<BookmarksIntent>(
            onInvoke: (_) => widget.onBookmarks?.call(),
          ),
          LibraryIntent: CallbackAction<LibraryIntent>(
            onInvoke: (_) => widget.onLibrary?.call(),
          ),
          SettingsIntent: CallbackAction<SettingsIntent>(
            onInvoke: (_) => widget.onSettings?.call(),
          ),
          ClosePanelIntent: CallbackAction<ClosePanelIntent>(
            onInvoke: (_) => widget.onClosePanel?.call(),
          ),
        },
        child: widget.child,
      ),
    );
  }
}

class NextPageIntent extends Intent {
  const NextPageIntent();
}

class PreviousPageIntent extends Intent {
  const PreviousPageIntent();
}

class IncreaseFontSizeIntent extends Intent {
  const IncreaseFontSizeIntent();
}

class DecreaseFontSizeIntent extends Intent {
  const DecreaseFontSizeIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class BookmarksIntent extends Intent {
  const BookmarksIntent();
}

class LibraryIntent extends Intent {
  const LibraryIntent();
}

class SettingsIntent extends Intent {
  const SettingsIntent();
}

class ClosePanelIntent extends Intent {
  const ClosePanelIntent();
}
