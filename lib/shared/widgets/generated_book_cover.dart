import 'package:flutter/material.dart';

class GeneratedBookCover extends StatelessWidget {
  const GeneratedBookCover({
    required this.title,
    required this.author,
    required this.seed,
    super.key,
  });

  final String title;
  final String author;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final color = Color(0xFF000000 | (seed.hashCode & 0x00FFFFFF));
    final hsl = HSLColor.fromColor(color);
    final darkColor = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();

    return AspectRatio(
      aspectRatio: 2 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, darkColor],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Icon(
                Icons.book,
                color: Colors.white.withValues(alpha: 0.15),
                size: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
