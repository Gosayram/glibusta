import 'package:flutter/material.dart';

class SelectionAreaWrapper extends StatelessWidget {
  final Widget child;
  final SelectableRegionContextMenuBuilder? contextMenuBuilder;

  const SelectionAreaWrapper({
    super.key,
    required this.child,
    this.contextMenuBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: contextMenuBuilder,
      child: child,
    );
  }
}
