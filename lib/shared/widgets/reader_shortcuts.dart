import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReaderShortcuts extends StatefulWidget {
  const ReaderShortcuts({super.key, required this.child});

  final Widget child;

  @override
  State<ReaderShortcuts> createState() => _ReaderShortcutsState();
}

class _ReaderShortcutsState extends State<ReaderShortcuts> {
  static const _shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowRight): NextPageIntent(),
    SingleActivator(LogicalKeyboardKey.arrowLeft): PreviousPageIntent(),
    SingleActivator(LogicalKeyboardKey.add): IncreaseFontSizeIntent(),
    SingleActivator(LogicalKeyboardKey.minus): DecreaseFontSizeIntent(),
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