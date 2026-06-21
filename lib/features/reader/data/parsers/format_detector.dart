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
  BookFormat.docx: ['docx'],
  BookFormat.cbz: ['cbz'],
  BookFormat.cbr: ['cbr'],
};

final Map<String, BookFormat> _extensionToFormat = {
  for (final entry in extensionsByFormat.entries)
    for (final ext in entry.value) ext: entry.key,
  'zip': BookFormat.fb2,
};

final Set<String> importableExtensions = {
  for (final entry in extensionsByFormat.entries)
    for (final ext in entry.value)
      if (entry.key != BookFormat.pdf) ext,
  'zip',
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
  // ZIP files are treated as FB2 archives by the import service.
  if (lower.endsWith('.zip')) return BookFormat.fb2;
  return BookFormat.unknown;
}

String formatToDbString(BookFormat format) => format.name;

BookFormat formatFromDbString(String? value) {
  if (value == null || value.isEmpty) return BookFormat.unknown;
  final lower = value.toLowerCase();
  for (final f in BookFormat.values) {
    if (f.name == lower) return f;
  }
  return formatForExtension(lower);
}
