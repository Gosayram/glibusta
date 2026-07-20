import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;

class SelectionAreaWrapper extends StatelessWidget {
  final Widget child;
  final SelectableRegionContextMenuBuilder? contextMenuBuilder;
  final ValueChanged<SelectedContent?>? onSelectionChanged;

  const SelectionAreaWrapper({
    super.key,
    required this.child,
    this.contextMenuBuilder,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: contextMenuBuilder,
      onSelectionChanged: onSelectionChanged,
      child: child,
    );
  }
}
