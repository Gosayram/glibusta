import 'package:flutter/material.dart';

class AdaptiveSplitView extends StatelessWidget {
  const AdaptiveSplitView({
    required this.master,
    required this.detail,
    this.breakpoint = 900,
    this.masterFlex = 2,
    this.detailFlex = 3,
    this.masterMinWidth = 300,
    super.key,
  });

  final Widget master;
  final Widget detail;
  final double breakpoint;
  final int masterFlex;
  final int detailFlex;
  final double masterMinWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: constraints.maxWidth * masterFlex / (masterFlex + detailFlex),
                child: master,
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: detailFlex,
                child: detail,
              ),
            ],
          );
        }
        return master;
      },
    );
  }
}

class AdaptiveSplitScreenState extends StatefulWidget {
  const AdaptiveSplitScreenState({
    required this.masterBuilder,
    required this.detailBuilder,
    this.breakpoint = 900,
    super.key,
  });

  final Widget Function(BuildContext context, void Function(String?) onSelect) masterBuilder;
  final Widget Function(BuildContext context, String? selectedId) detailBuilder;
  final double breakpoint;

  @override
  State<AdaptiveSplitScreenState> createState() => _AdaptiveSplitScreenState();
}

class _AdaptiveSplitScreenState extends State<AdaptiveSplitScreenState> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= widget.breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.35,
                child: widget.masterBuilder(context, (id) {
                  setState(() => _selectedId = id);
                }),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: widget.detailBuilder(context, _selectedId),
              ),
            ],
          );
        }

        if (_selectedId != null) {
          return widget.detailBuilder(context, _selectedId);
        }
        return widget.masterBuilder(context, (id) {
          setState(() => _selectedId = id);
        });
      },
    );
  }

  void clearSelection() {
    setState(() => _selectedId = null);
  }
}
