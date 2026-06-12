/// Quality scoring for Russian/English text decoding.
///
/// Returns 0.0–1.0 where higher is better. Catches cases where
/// a charset detector confidently returns the wrong encoding.
double encodingQualityScore(String text) {
  if (text.isEmpty) return 0;
  final sample = text.length > 20000 ? text.substring(0, 20000) : text;

  var score = 1.0;

  // Penalize replacement characters (U+FFFD)
  final replacementCount = '\uFFFD'.allMatches(sample).length;
  score -= replacementCount * 0.08;

  // Penalize control characters (except common whitespace)
  final controlCount = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').allMatches(sample).length;
  score -= controlCount * 0.04;

  // Penalize mojibake patterns (common in wrong-encoding decode)
  final mojibakeCount = RegExp(r'(Р.|С.|Ð.|Ñ.|â.|Ã.)').allMatches(sample).length;
  score -= mojibakeCount * 0.03;

  // Reward letter density
  final cyrillicCount = RegExp(r'[А-Яа-яЁё]').allMatches(sample).length;
  final latinCount = RegExp(r'[A-Za-z]').allMatches(sample).length;
  final lettersCount = cyrillicCount + latinCount;
  if (lettersCount < sample.length * 0.20) {
    score -= 0.25;
  }

  // Reward whitespace density (normal text has spaces/newlines)
  final whitespaceCount = RegExp(r'\s').allMatches(sample).length;
  if (whitespaceCount < sample.length * 0.05) {
    score -= 0.15;
  }

  // Reward common Russian words
  const commonRussianWords = [
    'и',
    'в',
    'не',
    'на',
    'что',
    'он',
    'она',
    'как',
    'это',
    'его',
    'книга',
    'глава',
  ];
  final lower = sample.toLowerCase();
  final commonHits = commonRussianWords
      .where((word) => RegExp('\\b$word\\b').hasMatch(lower))
      .length;
  score += commonHits * 0.02;

  return score.clamp(0.0, 1.0);
}
