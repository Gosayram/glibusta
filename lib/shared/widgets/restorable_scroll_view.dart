import 'package:flutter/material.dart';

class RestorableCustomScrollView extends StatefulWidget {
  final String restorationId;
  final List<Widget> slivers;

  const RestorableCustomScrollView({
    super.key,
    required this.restorationId,
    required this.slivers,
  });

  @override
  State<RestorableCustomScrollView> createState() => _RestorableCustomScrollViewState();
}

class _RestorableCustomScrollViewState extends State<RestorableCustomScrollView>
    with RestorationMixin {
  final RestorableDouble _offset = RestorableDouble(0);
  ScrollController? _controller;

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool restoredFromOldBucket) {
    registerForRestoration(_offset, 'scroll_offset');
  }

  @override
  void dispose() {
    _controller?.removeListener(_saveOffset);
    _controller?.dispose();
    _offset.dispose();
    super.dispose();
  }

  ScrollController _getController() {
    if (_controller != null) return _controller!;
    _controller = ScrollController(
      initialScrollOffset: _offset.value,
      keepScrollOffset: false,
    )..addListener(_saveOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
    return _controller!;
  }

  void _saveOffset() {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    _offset.value = controller.position.pixels;
  }

  void _restoreOffset() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.hasClients) return;
    final maxOffset = controller.position.maxScrollExtent;
    final offset = _offset.value.clamp(0.0, maxOffset);
    if (offset > 0 && (controller.position.pixels - offset).abs() > 1) {
      controller.jumpTo(offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(controller: _getController(), slivers: widget.slivers);
  }
}

class RestorableListView extends StatefulWidget {
  final String restorationId;
  final List<Widget> children;

  const RestorableListView({
    super.key,
    required this.restorationId,
    required this.children,
  });

  @override
  State<RestorableListView> createState() => _RestorableListViewState();
}

class _RestorableListViewState extends State<RestorableListView> with RestorationMixin {
  final RestorableDouble _offset = RestorableDouble(0);
  ScrollController? _controller;

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool restoredFromOldBucket) {
    registerForRestoration(_offset, 'scroll_offset');
  }

  @override
  void dispose() {
    _controller?.removeListener(_saveOffset);
    _controller?.dispose();
    _offset.dispose();
    super.dispose();
  }

  ScrollController _getController() {
    if (_controller != null) return _controller!;
    _controller = ScrollController(
      initialScrollOffset: _offset.value,
      keepScrollOffset: false,
    )..addListener(_saveOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
    return _controller!;
  }

  void _saveOffset() {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    _offset.value = controller.position.pixels;
  }

  void _restoreOffset() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.hasClients) return;
    final maxOffset = controller.position.maxScrollExtent;
    final offset = _offset.value.clamp(0.0, maxOffset);
    if (offset > 0 && (controller.position.pixels - offset).abs() > 1) {
      controller.jumpTo(offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _getController(),
      itemCount: widget.children.length,
      itemBuilder: (context, index) => widget.children[index],
    );
  }
}
