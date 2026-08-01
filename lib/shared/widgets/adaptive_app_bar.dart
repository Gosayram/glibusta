import 'package:flutter/material.dart';

import '../../core/platform/app_platform.dart';

/// Horizontal inset reserved on macOS so a back button clears the window's
/// traffic-light (close/minimize/zoom) controls, which sit at roughly x=14–66.
const double kMacTrafficLightsInset = 52.0;

/// Back button that is indented past the macOS traffic lights on macOS and a
/// plain [BackButton] elsewhere. Use as `leading` or via [AdaptiveAppBar].
class AdaptiveBackButton extends StatelessWidget {
  const AdaptiveBackButton({super.key, this.color, this.onPressed, this.style});

  final Color? color;
  final VoidCallback? onPressed;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final button = BackButton(color: color, onPressed: onPressed, style: style);
    if (!hasNativeMenuBar) return button;
    return Padding(
      padding: const EdgeInsets.only(left: kMacTrafficLightsInset),
      child: button,
    );
  }
}

/// Drop-in [AppBar] for screens rendered full-width above the macOS sidebar.
/// On macOS the leading back button is indented past the traffic lights via
/// [AdaptiveBackButton]; other platforms behave exactly like [AppBar].
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveAppBar({
    super.key,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.centerTitle,
    this.backgroundColor,
    this.foregroundColor,
    this.surfaceTintColor,
    this.scrolledUnderElevation,
    this.forceMaterialTransparency = false,
  });

  final Widget? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? surfaceTintColor;
  final double? scrolledUnderElevation;
  final bool forceMaterialTransparency;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final useMacInset = hasNativeMenuBar && automaticallyImplyLeading;
    return AppBar(
      key: key,
      title: title,
      actions: actions,
      automaticallyImplyLeading: !useMacInset && automaticallyImplyLeading,
      leading: useMacInset ? const AdaptiveBackButton() : null,
      leadingWidth: useMacInset ? kToolbarHeight + kMacTrafficLightsInset : null,
      bottom: bottom,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      surfaceTintColor: surfaceTintColor,
      scrolledUnderElevation: scrolledUnderElevation,
      forceMaterialTransparency: forceMaterialTransparency,
    );
  }
}
