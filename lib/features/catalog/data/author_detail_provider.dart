import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../features/search/data/flibusta_api_client.dart';

part 'author_detail_provider.g.dart';

@riverpod
Future<AuthorDetailResponse> authorDetail(Ref ref, String authorId) async {
  final client = ref.watch(flibustaApiClientProvider);
  return client.getAuthorDetail(authorId);
}
