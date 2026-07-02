import '../../features/reader/data/parsers/format_detector.dart';
import '../utils/format_utils.dart';
export '../utils/format_utils.dart' show formatBytes;

const int _mb = 1024 * 1024;

int maxReadableBookBytes(BookFormat format) {
  return switch (format) {
    BookFormat.txt => 10 * _mb,
    BookFormat.fb2 || BookFormat.rtf => 20 * _mb,
    BookFormat.epub => 250 * _mb,
    BookFormat.mobi || BookFormat.azw3 || BookFormat.prc => 120 * _mb,
    BookFormat.pdf || BookFormat.djvu => 500 * _mb,
    BookFormat.docx => 50 * _mb,
    BookFormat.cbz || BookFormat.cbr => 500 * _mb,
    BookFormat.unknown => 0,
  };
}

bool isBookFileTooLarge(BookFormat format, int sizeBytes) {
  final limit = maxReadableBookBytes(format);
  return limit > 0 && sizeBytes > limit;
}

String bookFileTooLargeMessage(BookFormat format, int sizeBytes) {
  final limit = maxReadableBookBytes(format);
  return 'Файл слишком большой для обработки: '
      '${formatBytes(sizeBytes)} из ${formatBytes(limit)} для ${format.name.toUpperCase()}';
}
