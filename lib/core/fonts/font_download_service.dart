import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';

class DownloadableFont {
  final String id;
  final String name;
  final String family;
  final String url;
  final bool isDownloaded;
  final bool isBundled;

  const DownloadableFont({
    required this.id,
    required this.name,
    required this.family,
    required this.url,
    this.isDownloaded = false,
    this.isBundled = false,
  });

  DownloadableFont copyWith({bool? isDownloaded}) {
    return DownloadableFont(
      id: id,
      name: name,
      family: family,
      url: url,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isBundled: isBundled,
    );
  }
}

class FontDownloadService {
  FontDownloadService(this._dio);

  final Dio _dio;
  final AppLogger _logger = AppLogger();

  static const _downloadedFontsKey = 'downloaded_fonts';
  static const _fontsDirName = 'custom_fonts';

  static const availableFonts = [
    DownloadableFont(
      id: 'merriweather',
      name: 'Merriweather',
      family: 'Merriweather',
      url: 'https://github.com/google/fonts/raw/main/ofl/merriweather/Merriweather%5Bwght%5D.ttf',
      isBundled: true,
    ),
    DownloadableFont(
      id: 'noto-serif',
      name: 'Noto Serif',
      family: 'NotoSerif',
      url: 'https://github.com/google/fonts/raw/main/ofl/notoserif/NotoSerif%5Bwght%5D.ttf',
      isBundled: true,
    ),
    DownloadableFont(
      id: 'lora',
      name: 'Lora',
      family: 'Lora',
      url: 'https://github.com/google/fonts/raw/main/ofl/lora/Lora%5Bwght%5D.ttf',
      isBundled: true,
    ),
    DownloadableFont(
      id: 'pt-serif',
      name: 'PT Serif',
      family: 'PTSerif',
      url: 'https://github.com/google/fonts/raw/main/ofl/ptserif/PTSerif%5Bwght%5D.ttf',
      isBundled: true,
    ),
    DownloadableFont(
      id: 'crimson-text',
      name: 'Crimson Text',
      family: 'CrimsonText',
      url: 'https://github.com/google/fonts/raw/main/ofl/crimsontext/CrimsonText-Regular.ttf',
      isBundled: true,
    ),
    DownloadableFont(
      id: 'old-standard',
      name: 'Old Standard TT',
      family: 'OldStandardTT',
      url: 'https://github.com/google/fonts/raw/main/ofl/oldstandardtt/OldStandardTT-Regular.ttf',
      isBundled: true,
    ),
  ];

  Future<Directory> get _fontsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final fontsDir = Directory('${appDir.path}/$_fontsDirName');
    if (!await fontsDir.exists()) {
      await fontsDir.create(recursive: true);
    }
    return fontsDir;
  }

  Future<List<DownloadableFont>> getFonts() async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedIds = prefs.getStringList(_downloadedFontsKey) ?? [];
    return availableFonts.map((font) {
      return font.copyWith(isDownloaded: downloadedIds.contains(font.id));
    }).toList();
  }

  Future<File?> downloadFont(DownloadableFont font, {ProgressCallback? onProgress}) async {
    try {
      final dir = await _fontsDir;
      final file = File('${dir.path}/${font.id}.ttf');

      if (await file.exists()) {
        await _markDownloaded(font.id);
        return file;
      }

      final response = await _dio.download(
        font.url,
        file.path,
        onReceiveProgress: onProgress,
      );

      if (response.statusCode == 200) {
        await _markDownloaded(font.id);
        _logger.info('Font downloaded: ${font.name}');
        return file;
      } else {
        await file.delete();
        return null;
      }
    } on Object catch (e) {
      _logger.severe('Failed to download font ${font.name}: $e');
      return null;
    }
  }

  Future<void> deleteFont(DownloadableFont font) async {
    try {
      final dir = await _fontsDir;
      final file = File('${dir.path}/${font.id}.ttf');
      if (await file.exists()) {
        await file.delete();
      }
      await _removeDownloaded(font.id);
      _logger.info('Font deleted: ${font.name}');
    } on Object catch (e) {
      _logger.severe('Failed to delete font ${font.name}: $e');
    }
  }

  Future<File?> getFontFile(String fontId) async {
    final dir = await _fontsDir;
    final file = File('${dir.path}/$fontId.ttf');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<List<String>> getDownloadedFontIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_downloadedFontsKey) ?? [];
  }

  Future<void> _markDownloaded(String fontId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_downloadedFontsKey) ?? [];
    if (!ids.contains(fontId)) {
      ids.add(fontId);
      await prefs.setStringList(_downloadedFontsKey, ids);
    }
  }

  Future<void> _removeDownloaded(String fontId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_downloadedFontsKey) ?? [];
    ids.remove(fontId);
    await prefs.setStringList(_downloadedFontsKey, ids);
  }
}
