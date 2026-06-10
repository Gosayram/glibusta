import 'package:flutter/material.dart';

import '../../core/utils/platform_detector.dart';

class SelectionAreaWrapper extends StatelessWidget {
  final Widget child;

  const SelectionAreaWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!PlatformDetector.isDesktop) return child;
    return SelectionArea(child: child);
  }
}
