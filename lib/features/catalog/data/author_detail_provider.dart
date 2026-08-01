import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../search/data/flibusta_models.dart';
import '../../search/data/flibusta_source.dart';

part 'author_detail_provider.g.dart';

@riverpod
Future<AuthorDetailResponse> authorDetail(Ref ref, String authorId) async {
  final client = ref.watch(flibustaSourceProvider);
  return client.getAuthorDetail(authorId);
}
