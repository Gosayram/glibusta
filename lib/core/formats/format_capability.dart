import '../../features/reader/data/parsers/format_detector.dart';
import '../../shared/models/book.dart';

export '../../shared/models/book.dart' show BookFormat;

enum FormatCapability {
  readable('Поддерживается'),
  partial('Частичная поддержка'),
  legacy('Устаревший формат'),
  documentOnly('Только хранение'),
  unsupported('Не поддерживается');

  const FormatCapability(this.label);
  final String label;

  bool get canReadInApp =>
      this == FormatCapability.readable ||
      this == FormatCapability.partial ||
      this == FormatCapability.legacy;

  bool get canImport => this != FormatCapability.unsupported;

  bool get isDocumentOnly => this == FormatCapability.documentOnly;

  bool get hasReaderRoute => canReadInApp || isDocumentOnly;
}

extension BookFormatCapability on BookFormat {
  FormatCapability get capability => switch (this) {
    BookFormat.epub ||
    BookFormat.fb2 ||
    BookFormat.txt ||
    BookFormat.rtf ||
    BookFormat.mobi ||
    BookFormat.docx ||
    BookFormat.cbz => FormatCapability.readable,
    BookFormat.azw3 => FormatCapability.partial,
    BookFormat.prc => FormatCapability.legacy,
    BookFormat.pdf || BookFormat.djvu => FormatCapability.documentOnly,
    BookFormat.cbr => FormatCapability.readable,
    BookFormat.unknown => FormatCapability.unsupported,
  };

  bool get canReadInApp => capability.canReadInApp;
  bool get canImport => capability.canImport;
  bool get isDocumentOnly => capability.isDocumentOnly;
  bool get hasReaderRoute => capability.hasReaderRoute;

  String? warningLabel() => switch (capability) {
    FormatCapability.readable => null,
    FormatCapability.documentOnly => 'Только хранение/просмотр',
    FormatCapability.partial => 'Частичная поддержка (MOBI v1)',
    FormatCapability.legacy => 'Устаревший формат (legacy)',
    FormatCapability.unsupported => 'Формат не поддерживается',
  };
}
