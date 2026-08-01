import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../search/data/flibusta_models.dart';
import '../../search/data/flibusta_source.dart';

part 'recent_books_provider.g.dart';

@riverpod
Future<RecentBooksResponse> recentBooks(Ref ref) async {
  final client = ref.watch(flibustaSourceProvider);
  return client.getRecentBooks();
}
