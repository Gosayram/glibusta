import 'package:flutter/material.dart';

class LazyIndexedStack extends StatefulWidget {
  final int index;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final List<bool> _loaded;
  late final List<Widget?> _children;

  @override
  void initState() {
    super.initState();
    _loaded = List<bool>.filled(widget.itemCount, false);
    _children = List<Widget?>.filled(widget.itemCount, null);
    _load(widget.index);
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _load(widget.index);
    }
  }

  void _load(int index) {
    if (!_loaded[index]) {
      _loaded[index] = true;
      _children[index] = widget.itemBuilder(context, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.itemCount; i++) _children[i] ?? const SizedBox.shrink(),
      ],
    );
  }
}
