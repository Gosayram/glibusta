import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../features/search/data/flibusta_api_client.dart';

part 'series_detail_provider.g.dart';

@riverpod
Future<SeriesDetailResponse> seriesDetailFromServer(Ref ref, String seriesId) async {
  final client = ref.watch(flibustaApiClientProvider);
  return client.getSeriesDetail(seriesId);
}
