import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fonts/font_download_service.dart';
import '../../../core/http/dio_provider.dart';

final fontDownloadServiceProvider = Provider<FontDownloadService>((ref) {
  final dio = ref.watch(dioProvider);
  return FontDownloadService(dio);
});
