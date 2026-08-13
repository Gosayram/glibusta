/// Builds a privacy-preserving preview for an explicit dictionary request.
///
/// The preview is intentionally bounded: it lets the reader verify the text
/// before approving a network request without creating an unbounded dialog for
/// an accidental large selection. It never changes the query sent to the
/// dictionary.
final class DictionaryLookupPreview {
  const DictionaryLookupPreview._();

  static const maxPreviewRunes = 160;

  /// Normalizes whitespace and returns the visible part of [query].
  static String text(String query) {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    final runes = normalized.runes;
    if (runes.length <= maxPreviewRunes) return normalized;
    return '${String.fromCharCodes(runes.take(maxPreviewRunes))}…';
  }

  /// Whether the confirmation needs to state that the preview is truncated.
  static bool isTruncated(String query) {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.runes.length > maxPreviewRunes;
  }

  /// Localized consent copy used immediately before a network request.
  static String confirmationMessage({required String host, required String query}) {
    final truncationNotice = isTruncated(query)
        ? '\n\nПоказано начало; источнику будет передан весь выбранный фрагмент.'
        : '';
    return 'На $host будет отправлен выбранный фрагмент:\n\n'
        '«${text(query)}»$truncationNotice\n\nПродолжить?';
  }
}
