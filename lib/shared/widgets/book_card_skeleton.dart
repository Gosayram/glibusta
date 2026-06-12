import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BookCardSkeleton extends StatelessWidget {
  const BookCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Bone(width: double.infinity, height: double.infinity),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 3),
                SizedBox(height: 4),
                Bone.text(words: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
          title: Bone.text(words: 4),
          subtitle: Bone.text(words: 2),
        ),
      ),
    );
  }
}
