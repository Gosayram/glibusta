import '../../../reader/data/parsers/format_detector.dart';

final class BookFormatDetector {
  BookFormat detect({required String path, required List<int> bytes}) {
    return detectBookFormat(path);
  }
}
