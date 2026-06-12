import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../features/search/data/flibusta_api_client.dart';

part 'genre_providers.g.dart';

@riverpod
Future<GenreListResponse> genreList(Ref ref) async {
  final client = ref.watch(flibustaApiClientProvider);
  return client.getGenreList();
}

@riverpod
Future<GenreBooksResponse> genreBooks(Ref ref, String genreId) async {
  final client = ref.watch(flibustaApiClientProvider);
  return client.getGenreBooks(genreId);
}
