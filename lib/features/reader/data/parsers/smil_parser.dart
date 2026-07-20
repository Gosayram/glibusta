import 'package:xml/xml.dart';

/// LW-6.2: SMIL (Media Overlays) parser for EPUB3 audio synchronization.
/// Extracts timed text-audio pairs from SMIL XML.
class SmilParser {
  /// Parse SMIL XML content and return timed entries.
  /// Each entry maps a text fragment to an audio time range.
  static List<SmilEntry> parse(String xmlContent) {
    final doc = XmlDocument.parse(xmlContent);
    final entries = <SmilEntry>[];

    // SMIL <par> elements contain <text> + <audio> children
    for (final par in doc.findAllElements('par')) {
      final textRef = _findChildText(par, 'text');
      final audio = _findChildElement(par, 'audio');
      if (textRef == null || audio == null) continue;

      final audioSrc = audio.getAttribute('src') ?? '';
      final clipBegin = _parseTime(audio.getAttribute('clipBegin'));
      final clipEnd = _parseTime(audio.getAttribute('clipEnd'));

      // Extract paragraph ID from text reference (e.g., "chapter.xhtml#p1" → "p1")
      final paragraphId = textRef.contains('#') ? textRef.split('#').last : null;

      entries.add(
        SmilEntry(
          paragraphId: paragraphId,
          textRef: textRef,
          audioSrc: audioSrc,
          clipBegin: clipBegin,
          clipEnd: clipEnd,
        ),
      );
    }

    return entries;
  }

  static String? _findChildText(XmlElement parent, String tagName) {
    for (final child in parent.childElements) {
      if (_localName(child) == tagName) {
        return child.getAttribute('src');
      }
    }
    return null;
  }

  static XmlElement? _findChildElement(XmlElement parent, String tagName) {
    for (final child in parent.childElements) {
      if (_localName(child) == tagName) return child;
    }
    return null;
  }

  static String _localName(XmlElement e) {
    final name = e.name;
    return name.local;
  }

  /// Parse SMIL time values: "12.5s", "1m30s", "00:01:30.5", "7500ms"
  static Duration _parseTime(String? value) {
    if (value == null || value.isEmpty) return Duration.zero;
    final raw = value.trim();
    // EPUB Media Overlays may use the SMIL normal-play-time prefix, e.g.
    // `npt=12.5s` or `npt=00:01:30.5`. It describes the same clock values
    // as the unprefixed forms below.
    final v = raw.length >= 4 && raw.substring(0, 4).toLowerCase() == 'npt='
        ? raw.substring(4).trim()
        : raw;

    // Match "XXs" (seconds)
    if (v.endsWith('s') && !v.endsWith('ms')) {
      final numStr = v.substring(0, v.length - 1);
      final sec = double.tryParse(numStr) ?? 0;
      return Duration(milliseconds: (sec * 1000).round());
    }
    // Match "XXms" (milliseconds)
    if (v.endsWith('ms')) {
      final numStr = v.substring(0, v.length - 2);
      final ms = int.tryParse(numStr) ?? 0;
      return Duration(milliseconds: ms);
    }
    // Match "HH:MM:SS.ms" (clock time)
    if (v.contains(':')) {
      final parts = v.split(':');
      if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final secParts = parts[2].split('.');
        final s = int.tryParse(secParts[0]) ?? 0;
        final ms = secParts.length > 1
            ? int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0
            : 0;
        return Duration(hours: h, minutes: m, seconds: s, milliseconds: ms);
      }
    }
    // Fallback: try as seconds
    final sec = double.tryParse(v) ?? 0;
    return Duration(milliseconds: (sec * 1000).round());
  }
}

/// A single timed text-audio pair from SMIL.
class SmilEntry {
  const SmilEntry({
    required this.textRef,
    this.paragraphId,
    required this.audioSrc,
    required this.clipBegin,
    required this.clipEnd,
  });

  /// Full text reference (e.g., "chapter.xhtml#p1").
  final String textRef;

  /// Extracted paragraph ID (e.g., "p1").
  final String? paragraphId;

  /// Audio file path (relative to SMIL file).
  final String audioSrc;

  /// Start time of this segment in the audio.
  final Duration clipBegin;

  /// End time of this segment in the audio.
  final Duration clipEnd;

  /// Duration of this segment.
  Duration get duration => clipEnd - clipBegin;
}
