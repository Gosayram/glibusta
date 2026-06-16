import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BookCardSkeleton extends StatelessWidget {
  const BookCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Skeleton.replace(
              child: SizedBox.expand(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Skeleton.unite(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(BoneMock.title),
                  const SizedBox(height: 4),
                  Text(BoneMock.subtitle),
                ],
              ),
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
        itemBuilder: (_, _) => ListTile(
          leading: const Bone.circle(size: 40),
          title: Text(BoneMock.name),
          subtitle: Text(BoneMock.subtitle),
        ),
      ),
    );
  }
}
