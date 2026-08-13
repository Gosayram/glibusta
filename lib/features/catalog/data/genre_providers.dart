import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../search/data/flibusta_models.dart';
import '../../search/data/flibusta_source.dart';

part 'genre_providers.g.dart';

@riverpod
Future<GenreListResponse> genreList(Ref ref) async {
  final client = ref.watch(flibustaSourceProvider);
  return client.getGenreList();
}

@riverpod
Future<GenreBooksResponse> genreBooks(Ref ref, String genreId) async {
  final client = ref.watch(flibustaSourceProvider);
  return client.getGenreBooks(genreId);
}
