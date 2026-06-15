import '../../../../shared/models/book.dart';

export '../../../../shared/models/book.dart' show BookFormat;

const Map<BookFormat, List<String>> extensionsByFormat = {
  BookFormat.epub: ['epub'],
  BookFormat.fb2: ['fb2'],
  BookFormat.pdf: ['pdf'],
  BookFormat.txt: ['txt'],
  BookFormat.mobi: ['mobi', 'azw'],
  BookFormat.azw3: ['azw3'],
  BookFormat.prc: ['prc'],
  BookFormat.rtf: ['rtf'],
  BookFormat.djvu: ['djvu', 'djv'],
};

final Map<String, BookFormat> _extensionToFormat = {
  for (final entry in extensionsByFormat.entries)
    for (final ext in entry.value) ext: entry.key,
};

final Set<String> importableExtensions = {
  for (final entry in extensionsByFormat.entries)
    for (final ext in entry.value)
      if (entry.key != BookFormat.pdf) ext,
  'zip',
};

const Set<String> readableExtensions = {
  'epub',
  'fb2',
  'txt',
  'rtf',
  'mobi',
  'azw',
  'azw3',
  'prc',
};

BookFormat formatForExtension(String ext) {
  return _extensionToFormat[ext.toLowerCase()] ?? BookFormat.unknown;
}

BookFormat detectBookFormat(String path) {
  final lower = path.toLowerCase();
  for (final entry in extensionsByFormat.entries) {
    for (final ext in entry.value) {
      if (lower.endsWith('.$ext')) return entry.key;
    }
  }
  if (lower.endsWith('.zip')) return BookFormat.unknown;
  return BookFormat.unknown;
}
