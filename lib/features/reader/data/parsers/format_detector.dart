enum BookFormat {
  epub,
  fb2,
  pdf,
  txt,
  unknown,
}

BookFormat detectBookFormat(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.epub')) return BookFormat.epub;
  if (lower.endsWith('.fb2')) return BookFormat.fb2;
  if (lower.endsWith('.pdf')) return BookFormat.pdf;
  if (lower.endsWith('.txt')) return BookFormat.txt;
  return BookFormat.unknown;
}
