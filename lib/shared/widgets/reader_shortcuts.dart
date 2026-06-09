import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReaderShortcuts extends StatefulWidget {
  const ReaderShortcuts({super.key, required this.child});

  final Widget child;

  @override
  State<ReaderShortcuts> createState() => _ReaderShortcutsState();
}

class _ReaderShortcutsState extends State<ReaderShortcuts> {
  static final Map<ShortcutActivator, Intent> _shortcuts = {
    // Navigation
    SingleActivator(LogicalKeyboardKey.arrowRight): NextPageIntent(),
    SingleActivator(LogicalKeyboardKey.arrowLeft): PreviousPageIntent(),
    SingleActivator(LogicalKeyboardKey.space): NextPageIntent(),

    // Font size
    SingleActivator(LogicalKeyboardKey.add): IncreaseFontSizeIntent(),
    SingleActivator(LogicalKeyboardKey.equal): IncreaseFontSizeIntent(), // For Cmd+= on some keyboards
    SingleActivator(LogicalKeyboardKey.minus): DecreaseFontSizeIntent(),

    // macOS shortcuts - using SingleActivator with character
    SingleActivator(LogicalKeyboardKey.keyF, meta: true): SearchIntent(),
    SingleActivator(LogicalKeyboardKey.keyB, meta: true): BookmarksIntent(),
    SingleActivator(LogicalKeyboardKey.keyL, meta: true): LibraryIntent(),
    SingleActivator(LogicalKeyboardKey.comma, meta: true): SettingsIntent(),
    SingleActivator(LogicalKeyboardKey.escape): ClosePanelIntent(),
  };

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          NextPageIntent: NextPageAction(),
          PreviousPageIntent: PreviousPageAction(),
          IncreaseFontSizeIntent: IncreaseFontSizeAction(),
          DecreaseFontSizeIntent: DecreaseFontSizeAction(),
          SearchIntent: SearchAction(),
          BookmarksIntent: BookmarksAction(),
          LibraryIntent: LibraryAction(),
          SettingsIntent: SettingsAction(),
          ClosePanelIntent: ClosePanelAction(),
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

class NextPageAction extends Action<NextPageIntent> {
  @override
  Object? invoke(Intent intent) {
    // Navigate to next page
    return null;
  }
}

class PreviousPageAction extends Action<PreviousPageIntent> {
  @override
  Object? invoke(Intent intent) {
    // Navigate to previous page
    return null;
  }
}

class IncreaseFontSizeAction extends Action<IncreaseFontSizeIntent> {
  @override
  Object? invoke(Intent intent) {
    // Increase font size
    return null;
  }
}

class DecreaseFontSizeAction extends Action<DecreaseFontSizeIntent> {
  @override
  Object? invoke(Intent intent) {
    // Decrease font size
    return null;
  }
}

class SearchAction extends Action<SearchIntent> {
  @override
  Object? invoke(Intent intent) {
    // Open search
    return null;
  }
}

class BookmarksAction extends Action<BookmarksIntent> {
  @override
  Object? invoke(Intent intent) {
    // Go to bookmarks
    return null;
  }
}

class LibraryAction extends Action<LibraryIntent> {
  @override
  Object? invoke(Intent intent) {
    // Go to library
    return null;
  }
}

class SettingsAction extends Action<SettingsIntent> {
  @override
  Object? invoke(Intent intent) {
    // Open settings
    return null;
  }
}

class ClosePanelAction extends Action<ClosePanelIntent> {
  @override
  Object? invoke(Intent intent) {
    // Close panel/sidebar
    return null;
  }
}