import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_platform.dart';

class SelectionAreaWrapper extends ConsumerWidget {
  final Widget child;

  const SelectionAreaWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(platformCapabilitiesProvider).supportsTextSelection) return child;
    return SelectionArea(child: child);
  }
}
