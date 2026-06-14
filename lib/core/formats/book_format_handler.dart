import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/reader/data/parsers/epub_parser.dart';
import '../../features/reader/data/parsers/fb2_parser.dart';
import '../../features/reader/data/parsers/normalized_book.dart';
import '../../features/reader/data/parsers/rtf_parser.dart';

abstract class BookFormatHandler {
  String get format;
  List<String> get supportedExtensions;
  String get displayName;

  Future<NormalizedBook> parse(Uint8List data);
  Future<NormalizedBook> parseFile(String filePath);

  bool canHandle(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return supportedExtensions.contains(ext);
  }
}

class Fb2FormatHandler extends BookFormatHandler {
  final _parser = Fb2Parser();

  @override
  String get format => 'fb2';
  @override
  List<String> get supportedExtensions => ['fb2'];
  @override
  String get displayName => 'FictionBook 2.0';

  @override
  Future<NormalizedBook> parse(Uint8List data) => _parser.parse(data);
  @override
  Future<NormalizedBook> parseFile(String filePath) => _parser.parseFile(filePath);
}

class EpubFormatHandler extends BookFormatHandler {
  final _parser = EpubParser();

  @override
  String get format => 'epub';
  @override
  List<String> get supportedExtensions => ['epub'];
  @override
  String get displayName => 'EPUB';

  @override
  Future<NormalizedBook> parse(Uint8List data) => _parser.parse(data);
  @override
  Future<NormalizedBook> parseFile(String filePath) => _parser.parseFile(filePath);
}

class TxtFormatHandler extends BookFormatHandler {
  @override
  String get format => 'txt';
  @override
  List<String> get supportedExtensions => ['txt'];
  @override
  String get displayName => 'Plain Text';

  @override
  Future<NormalizedBook> parse(Uint8List data) async {
    final text = String.fromCharCodes(data);
    return _parseText(text, 'txt');
  }

  @override
  Future<NormalizedBook> parseFile(String filePath) async {
    final file = File(filePath);
    final data = await file.readAsBytes();
    final text = String.fromCharCodes(data);
    final name = filePath.split(Platform.pathSeparator).last;
    return _parseText(text, name);
  }

  NormalizedBook _parseText(String text, String sourceName) {
    final lines = text.split('\n');
    final chapters = <ReaderChapter>[];
    final buf = <String>[];

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) {
        if (buf.isNotEmpty) {
          chapters.add(_makeChapter(chapters.length, buf));
          buf.clear();
        }
        continue;
      }
      if (t.startsWith('#') || t.startsWith('Глава') || t.startsWith('CHAPTER')) {
        if (buf.isNotEmpty) {
          chapters.add(_makeChapter(chapters.length, buf));
          buf.clear();
        }
        chapters.add(
          ReaderChapter(
            index: chapters.length,
            title: t.replaceFirst(RegExp(r'^[#]+\s*'), ''),
            blocks: [ReaderBlock(index: 0, text: t)],
          ),
        );
      } else {
        buf.add(t);
      }
    }
    if (buf.isNotEmpty) {
      chapters.add(_makeChapter(chapters.length, buf));
    }
    if (chapters.isEmpty) {
      chapters.add(
        ReaderChapter(
          index: 0,
          title: 'Содержание',
          blocks: [ReaderBlock(index: 0, text: text.isNotEmpty ? text : 'Пустой файл')],
        ),
      );
    }

    return NormalizedBook(
      id: sourceName,
      title: sourceName,
      authors: const ['Unknown'],
      chapters: chapters,
    );
  }

  ReaderChapter _makeChapter(int index, List<String> paragraphs) {
    return ReaderChapter(
      index: index,
      title: 'Глава ${index + 1}',
      blocks: paragraphs
          .asMap()
          .entries
          .map((e) => ReaderBlock(index: e.key, text: e.value))
          .toList(),
    );
  }
}

class RtfFormatHandler extends BookFormatHandler {
  final _parser = RtfBookParser();

  @override
  String get format => 'rtf';
  @override
  List<String> get supportedExtensions => ['rtf'];
  @override
  String get displayName => 'Rich Text Format';

  @override
  Future<NormalizedBook> parse(Uint8List data) => _parser.parse(data);
  @override
  Future<NormalizedBook> parseFile(String filePath) => _parser.parseFile(filePath);
}

class BookFormatRegistry {
  BookFormatRegistry() {
    register(Fb2FormatHandler());
    register(EpubFormatHandler());
    register(TxtFormatHandler());
    register(RtfFormatHandler());
  }

  final Map<String, BookFormatHandler> _handlers = {};

  void register(BookFormatHandler handler) {
    for (final ext in handler.supportedExtensions) {
      _handlers[ext] = handler;
    }
  }

  void unregister(String format) {
    _handlers.removeWhere((_, h) => h.format == format);
  }

  BookFormatHandler? handlerFor(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return _handlers[ext];
  }

  bool canHandle(String filePath) => handlerFor(filePath) != null;

  List<BookFormatHandler> get allHandlers => _handlers.values.toSet().toList();

  List<String> get supportedFormats => _handlers.values.map((h) => h.format).toSet().toList();
}

final bookFormatRegistryProvider = Provider<BookFormatRegistry>((ref) {
  return BookFormatRegistry();
});
