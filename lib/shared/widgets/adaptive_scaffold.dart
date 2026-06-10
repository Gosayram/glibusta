import 'package:flutter/material.dart';

import '../../core/utils/app_breakpoints.dart';

class AdaptiveScaffold extends StatelessWidget {
  final Widget compact;
  final Widget medium;
  final Widget expanded;

  const AdaptiveScaffold({
    super.key,
    required this.compact,
    required this.medium,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppBreakpoints.compact) return compact;
    if (width < AppBreakpoints.medium) return medium;
    return expanded;
  }
}
