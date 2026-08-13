const _articles = [
  'the ',
  'a ',
  'an ',
  'der ',
  'die ',
  'das ',
  'le ',
  'la ',
  'el ',
];

String normalizeAuthorForSort(String? author) {
  if (author == null || author.trim().isEmpty) return '';
  return author.split(';').map(_normalizeSingle).join('; ');
}

String _normalizeSingle(String raw) {
  var name = raw.trim();
  if (name.isEmpty) return '';

  for (final article in _articles) {
    if (name.toLowerCase().startsWith(article)) {
      name = name.substring(article.length);
      break;
    }
  }

  if (name.contains(',')) {
    name = name.replaceAll(RegExp(r',\s*'), ' ');
  } else {
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final surname = parts.last;
      final rest = parts.sublist(0, parts.length - 1).join(' ');
      name = '$surname $rest';
    }
  }

  return name.toLowerCase().replaceAll('ё', 'е');
}
