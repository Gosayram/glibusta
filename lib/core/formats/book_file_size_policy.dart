import '../../features/reader/data/parsers/format_detector.dart';

const int _mb = 1024 * 1024;

int maxReadableBookBytes(BookFormat format) {
  return switch (format) {
    BookFormat.txt => 20 * _mb,
    BookFormat.fb2 || BookFormat.rtf => 50 * _mb,
    BookFormat.epub => 250 * _mb,
    BookFormat.mobi || BookFormat.azw3 || BookFormat.prc => 120 * _mb,
    BookFormat.pdf || BookFormat.djvu => 500 * _mb,
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

String formatBytes(int bytes) {
  if (bytes >= _mb) {
    return '${(bytes / _mb).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
