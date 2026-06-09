import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/parsers/normalized_book.dart';
import '../data/reader_colors.dart';
import '../domain/reader.dart';

class ReaderContentBody extends StatelessWidget {
  const ReaderContentBody({
    super.key,
    required this.book,
    required this.settings,
    required this.scrollController,
    required this.onTap,
  });

  final NormalizedBook book;
  final ReaderSettings settings;
  final ScrollController scrollController;
  final GestureTapUpCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: onTap,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.all(settings.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < book.chapters.length; i++) ...[
                _buildChapterContent(i, settings),
                if (i < book.chapters.length - 1)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: settings.paragraphSpacing * 3,
                    ),
                    child: Center(
                      child: Text(
                        '— ${book.chapters[i + 1].title} —',
                        style: _getReaderStyle(settings).copyWith(
                          color: _getReaderStyle(settings).color?.withValues(alpha: 0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterContent(int chapterIndex, ReaderSettings settings) {
    if (chapterIndex < 0 || chapterIndex >= book.chapters.length) {
      return const SizedBox.shrink();
    }

    final chapter = book.chapters[chapterIndex];
    final textAlign = switch (settings.textAlign) {
      ReaderTextAlign.left => TextAlign.left,
      ReaderTextAlign.justify => TextAlign.justify,
      ReaderTextAlign.center => TextAlign.center,
      ReaderTextAlign.right => TextAlign.right,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chapter.title.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: settings.paragraphSpacing * 2),
            child: Text(
              chapter.title,
              style: _getReaderStyle(settings).copyWith(
                fontSize: settings.fontSize * 1.4,
                fontWeight: FontWeight.bold,
              ),
              textAlign: textAlign,
            ),
          ),
        ...chapter.blocks.map((block) => _buildBlock(block, settings, textAlign)),
      ],
    );
  }

  Widget _buildBlock(
    ReaderBlock block,
    ReaderSettings settings,
    TextAlign textAlign,
  ) {
    switch (block.type) {
      case BlockType.heading:
        return Padding(
          padding: EdgeInsets.only(
            top: settings.paragraphSpacing * 2,
            bottom: settings.paragraphSpacing,
          ),
          child: Text(
            block.text,
            style: _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 1.2,
              fontWeight: FontWeight.bold,
            ),
            textAlign: textAlign,
          ),
        );
      case BlockType.quote:
        return Container(
          margin: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _getReaderStyle(settings).color!.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
          ),
          child: Text(
            block.text,
            style: _getReaderStyle(settings).copyWith(
              fontStyle: FontStyle.italic,
            ),
            textAlign: textAlign,
          ),
        );
      case BlockType.separator:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
          child: Center(child: Text('* * *', style: _getReaderStyle(settings))),
        );
      case BlockType.image:
        if (block.imageUrl != null) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
            child: Center(
              child: Icon(
                Icons.image,
                size: 64,
                color: _getReaderStyle(settings).color,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      case BlockType.footnote:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing / 2),
          child: Text(
            block.text,
            style: _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 0.85,
            ),
            textAlign: textAlign,
          ),
        );
      case BlockType.paragraph:
        return Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
          child: Text(
            block.text,
            style: _getReaderStyle(settings),
            textAlign: textAlign,
          ),
        );
    }
  }

  TextStyle _getReaderStyle(ReaderSettings settings) {
    final colors = ReaderColors.forTheme(settings.theme);
    switch (settings.font) {
      case ReaderFont.sourceSerif:
        return GoogleFonts.sourceSerif4(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: colors.text,
          letterSpacing: settings.letterSpacing,
        );
      case ReaderFont.literata:
        return GoogleFonts.literata(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: colors.text,
          letterSpacing: settings.letterSpacing,
        );
      case ReaderFont.robotoSerif:
        return GoogleFonts.robotoSerif(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: colors.text,
          letterSpacing: settings.letterSpacing,
        );
      case ReaderFont.inter:
        return GoogleFonts.inter(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: colors.text,
          letterSpacing: settings.letterSpacing,
        );
    }
  }
}
