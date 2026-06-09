class AuthorNormalizer {
  static String normalize(String author) {
    if (author.trim().isEmpty) return '';
    final parts = author
        .split(';')
        .map((a) => _normalizeSingle(a.trim()))
        .where((a) => a.isNotEmpty);
    return parts.join(', ');
  }

  static String _normalizeSingle(String author) {
    if (author.isEmpty) return '';
    if (author.contains(',')) {
      final commaParts = author
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (commaParts.length >= 2) {
        return '${commaParts[1]} ${commaParts[0]}';
      }
      return commaParts.join(' ');
    }
    return author.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> normalizeList(List<String> authors) {
    final seen = <String>{};
    final result = <String>[];
    for (final a in authors) {
      final normalized = normalize(a);
      if (normalized.isEmpty) continue;
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        result.add(normalized);
      }
    }
    return result;
  }

  static String sortKey(String author) {
    final normalized = normalize(author);
    final parts = normalized.split(' ');
    return parts.isNotEmpty ? parts.last.toLowerCase() : '';
  }
}
