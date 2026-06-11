import '../../../../shared/models/book.dart';

export '../../../../shared/models/book.dart' show BookFormat;

BookFormat detectBookFormat(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.epub')) return BookFormat.epub;
  if (lower.endsWith('.fb2')) return BookFormat.fb2;
  if (lower.endsWith('.pdf')) return BookFormat.pdf;
  if (lower.endsWith('.txt')) return BookFormat.txt;
  return BookFormat.unknown;
}
