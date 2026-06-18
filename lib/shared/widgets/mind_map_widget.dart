import 'package:flutter/material.dart';

class MindMapNode {
  const MindMapNode({
    required this.label,
    this.children = const [],
    this.color,
  });

  final String label;
  final List<MindMapNode> children;
  final Color? color;
}

class MindMapWidget extends StatelessWidget {
  const MindMapWidget({
    required this.root,
    this.onNodeTap,
    super.key,
  });

  final MindMapNode root;
  final void Function(MindMapNode node)? onNodeTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: _buildNode(context, root, 0),
      ),
    );
  }

  Widget _buildNode(BuildContext context, MindMapNode node, int depth) {
    final theme = Theme.of(context);
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
      Colors.teal,
      Colors.orange,
    ];
    final nodeColor = node.color ?? colors[depth % colors.length];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onNodeTap?.call(node),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: nodeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: nodeColor, width: 2),
            ),
            child: Text(
              node.label,
              style: TextStyle(
                fontSize: depth == 0 ? 16 : 13,
                fontWeight: depth == 0 ? FontWeight.bold : FontWeight.w500,
                color: nodeColor,
              ),
            ),
          ),
        ),
        if (node.children.isNotEmpty) ...[
          Container(width: 2, height: 20, color: nodeColor.withValues(alpha: 0.3)),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < node.children.length; i++) ...[
                if (i > 0) ...[
                  Container(width: 1, height: 20, color: nodeColor.withValues(alpha: 0.2)),
                ],
                _buildNode(context, node.children[i], depth + 1),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class MindMapBottomSheet extends StatelessWidget {
  const MindMapBottomSheet({required this.nodes, super.key});

  final List<MindMapNode> nodes;

  static Future<void> show(BuildContext context, List<MindMapNode> nodes) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: MindMapBottomSheet(nodes: nodes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Mind Map',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: nodes.isEmpty
              ? const Center(child: Text('Нет данных для карты'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: nodes.map((node) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: MindMapWidget(root: node),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
