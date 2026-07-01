import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../search/data/flibusta_api_client.dart';
import '../../search/data/flibusta_models.dart';

part 'recent_books_provider.g.dart';

@riverpod
Future<RecentBooksResponse> recentBooks(Ref ref) async {
  final client = ref.watch(flibustaApiClientProvider);
  return client.getRecentBooks();
}
