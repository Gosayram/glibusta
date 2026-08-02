import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Skeleton placeholder for a book card used in grids (catalog, popular, etc.).
class BookCardSkeleton extends StatelessWidget {
  const BookCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Bone()),
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(width: 120, height: 12),
                SizedBox(height: 6),
                Bone(width: 80, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder for a book list item (list-tile style).
class BookListSkeleton extends StatelessWidget {
  const BookListSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (_, _) => const ListTile(
          leading: Bone.circle(size: 40),
          title: Bone(width: 120, height: 12),
          subtitle: Bone(width: 80, height: 12),
        ),
      ),
    );
  }
}
