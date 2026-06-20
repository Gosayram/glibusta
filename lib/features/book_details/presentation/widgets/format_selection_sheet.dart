import 'package:flutter/material.dart';

import '../../../../core/formats/format_capability.dart';

class FormatSelectionSheet extends StatelessWidget {
  final String bookTitle;
  final List<BookFormat> formats;

  const FormatSelectionSheet({super.key, required this.bookTitle, required this.formats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Скачать в формате',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (bookTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                bookTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          const Divider(height: 1),
          ...formats.map((format) {
            final info = _formatInfo(format);
            final capService = const FormatCapabilityService();
            final cap = capService.capabilityOf(format);
            final warning = capService.warningLabel(format);
            return ListTile(
              leading: Icon(info.icon, color: info.color),
              title: Row(
                children: [
                  Text(info.label),
                  if (warning != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cap == FormatCapability.partial
                            ? const Color(0xFFFFA726).withValues(alpha: 0.2)
                            : const Color(0xFF9E9E9E).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cap.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cap == FormatCapability.partial
                              ? const Color(0xFFFFA726)
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(info.description, style: theme.textTheme.bodySmall),
              onTap: () => Navigator.of(context).pop(format),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  _FormatInfo _formatInfo(BookFormat format) {
    switch (format) {
      case BookFormat.fb2:
        return const _FormatInfo(
          Icons.description,
          'FB2',
          'FictionBook 2 — стандарт Флибусты',
          Color(0xFF4CAF50),
        );
      case BookFormat.epub:
        return const _FormatInfo(
          Icons.menu_book,
          'EPUB',
          'Universal Publication — для большинства ридеров',
          Color(0xFF2196F3),
        );
      case BookFormat.mobi:
        return const _FormatInfo(
          Icons.tablet_mac,
          'MOBI',
          'Mobipocket — для Kindle',
          Color(0xFFFF9800),
        );
      case BookFormat.azw3:
        return const _FormatInfo(
          Icons.tablet_mac,
          'AZW3',
          'Kindle Format 8 — частичная поддержка',
          Color(0xFFFFA726),
        );
      case BookFormat.prc:
        return const _FormatInfo(
          Icons.tablet_mac,
          'PRC',
          'Palm/Mobipocket legacy',
          Color(0xFFFFB74D),
        );
      case BookFormat.pdf:
        return const _FormatInfo(
          Icons.picture_as_pdf,
          'PDF',
          'Portable Document — для печати и экрана',
          Color(0xFFF44336),
        );
      case BookFormat.txt:
        return const _FormatInfo(
          Icons.text_snippet,
          'TXT',
          'Текстовый файл — универсальный',
          Color(0xFF9E9E9E),
        );
      case BookFormat.rtf:
        return const _FormatInfo(
          Icons.article,
          'RTF',
          'Rich Text Format — текст с базовым форматированием',
          Color(0xFF795548),
        );
      case BookFormat.djvu:
        return const _FormatInfo(
          Icons.image,
          'DJVU',
          'DjVu — сканы и документы',
          Color(0xFF607D8B),
        );
      case BookFormat.docx:
        return const _FormatInfo(
          Icons.description,
          'DOCX',
          'Microsoft Word Document',
          Color(0xFF2B579A),
        );
      case BookFormat.cbz:
        return const _FormatInfo(
          Icons.book,
          'CBZ',
          'Comic Book ZIP — комиксы',
          Color(0xFF9C27B0),
        );
      case BookFormat.cbr:
        return const _FormatInfo(
          Icons.book,
          'CBR',
          'Comic Book RAR — комиксы',
          Color(0xFF7B1FA2),
        );
      case BookFormat.unknown:
        return _FormatInfo(
          Icons.help_outline,
          format.name.toUpperCase(),
          'Неизвестный формат',
          const Color(0xFF757575),
        );
    }
  }
}

class _FormatInfo {
  final IconData icon;
  final String label;
  final String description;
  final Color color;

  const _FormatInfo(this.icon, this.label, this.description, this.color);
}
