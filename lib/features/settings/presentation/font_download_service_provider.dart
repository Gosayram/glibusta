import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fonts/font_download_service.dart';

final fontDownloadServiceProvider = Provider<FontDownloadService>((ref) {
  final dio = Dio();
  return FontDownloadService(dio);
});
