import 'package:collection/collection.dart';
import 'package:xml/xml.dart';
import 'epub_archive.dart';

final class EpubContainerParser {
  String parseOpfPath(EpubArchive epub) {
    final xmlText = epub.readText('META-INF/container.xml');
    final doc = XmlDocument.parse(xmlText);
    final rootfile = doc.findAllElements('rootfile').firstOrNull;
    final fullPath = rootfile?.getAttribute('full-path');
    if (fullPath == null || fullPath.isEmpty) {
      throw StateError('Invalid EPUB: OPF path not found');
    }
    return fullPath;
  }
}
