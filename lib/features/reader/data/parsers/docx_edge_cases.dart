import 'package:xml/xml.dart';

class DocxEdgeCaseHandler {
  static List<String> extractFootnotes(XmlDocument doc) {
    final footnotes = <String>[];
    final footnotesPart = doc.findAllElements('w:footnoteReference');
    for (final ref in footnotesPart) {
      final id = ref.getAttribute('w:id');
      if (id != null) {
        final footnote = _findFootnoteById(doc, id);
        if (footnote != null) {
          footnotes.add(footnote);
        }
      }
    }
    return footnotes;
  }

  static String? _findFootnoteById(XmlDocument doc, String id) {
    for (final footnote in doc.findAllElements('w:footnote')) {
      final footnoteId = footnote.getAttribute('w:id');
      if (footnoteId == id) {
        return _extractTextFromNode(footnote);
      }
    }
    return null;
  }

  static String _extractTextFromNode(XmlElement node) {
    final buffer = StringBuffer();
    for (final child in node.descendants) {
      if (child is XmlText) {
        buffer.write(child.value);
      }
    }
    return buffer.toString().trim();
  }

  static List<String> extractEndnotes(XmlDocument doc) {
    final endnotes = <String>[];
    for (final ref in doc.findAllElements('w:endnoteReference')) {
      final id = ref.getAttribute('w:id');
      if (id != null) {
        final endnote = _findEndnoteById(doc, id);
        if (endnote != null) {
          endnotes.add(endnote);
        }
      }
    }
    return endnotes;
  }

  static String? _findEndnoteById(XmlDocument doc, String id) {
    for (final endnote in doc.findAllElements('w:endnote')) {
      final endnoteId = endnote.getAttribute('w:id');
      if (endnoteId == id) {
        return _extractTextFromNode(endnote);
      }
    }
    return null;
  }

  static List<TrackChange> extractTrackChanges(XmlDocument doc) {
    final changes = <TrackChange>[];

    for (final ins in doc.findAllElements('w:ins')) {
      final author = ins.getAttribute('w:author') ?? 'Unknown';
      final date = ins.getAttribute('w:date');
      final text = _extractTextFromNode(ins);
      if (text.isNotEmpty) {
        changes.add(
          TrackChange(
            type: TrackChangeType.insertion,
            author: author,
            date: date,
            text: text,
          ),
        );
      }
    }

    for (final del in doc.findAllElements('w:del')) {
      final author = del.getAttribute('w:author') ?? 'Unknown';
      final date = del.getAttribute('w:date');
      final text = _extractTextFromNode(del);
      if (text.isNotEmpty) {
        changes.add(
          TrackChange(
            type: TrackChangeType.deletion,
            author: author,
            date: date,
            text: text,
          ),
        );
      }
    }

    return changes;
  }

  static List<String> extractComments(XmlDocument doc) {
    final comments = <String>[];
    for (final comment in doc.findAllElements('w:comment')) {
      final text = _extractTextFromNode(comment);
      if (text.isNotEmpty) {
        comments.add(text);
      }
    }
    return comments;
  }

  static String resolveFootnoteMarkers(String text, List<String> footnotes) {
    final pattern = RegExp(r'\[(\d+)\]');
    return text.replaceAllMapped(pattern, (match) {
      final index = int.tryParse(match.group(1) ?? '');
      if (index != null && index > 0 && index <= footnotes.length) {
        return '[${footnotes[index - 1]}]';
      }
      return match.group(0) ?? '';
    });
  }
}

enum TrackChangeType { insertion, deletion, formatting }

class TrackChange {
  const TrackChange({
    required this.type,
    required this.author,
    this.date,
    required this.text,
  });

  final TrackChangeType type;
  final String author;
  final String? date;
  final String text;

  String get displayType {
    switch (type) {
      case TrackChangeType.insertion:
        return 'Вставка';
      case TrackChangeType.deletion:
        return 'Удаление';
      case TrackChangeType.formatting:
        return 'Форматирование';
    }
  }
}
