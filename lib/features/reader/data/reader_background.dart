import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReaderBackgroundType { solid, image, gradient }

enum DayNightMode { day, night, auto }

class ReaderBackground {
  const ReaderBackground({
    this.type = ReaderBackgroundType.solid,
    this.solidColor = const Color(0xFFFFFFFF),
    this.imageUrl,
    this.dayImageUrl,
    this.nightImageUrl,
    this.opacity = 0.3,
    this.blur = 0,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.dayNightMode = DayNightMode.auto,
  });

  final ReaderBackgroundType type;
  final Color solidColor;
  final String? imageUrl;
  final String? dayImageUrl;
  final String? nightImageUrl;
  final double opacity;
  final double blur;
  final BoxFit fit;
  final Alignment alignment;
  final DayNightMode dayNightMode;

  String? getEffectiveUrl(bool isNight) {
    if (dayNightMode == DayNightMode.auto) {
      return isNight ? nightImageUrl : dayImageUrl;
    }
    return imageUrl;
  }

  ReaderBackground copyWith({
    ReaderBackgroundType? type,
    Color? solidColor,
    String? imageUrl,
    String? dayImageUrl,
    String? nightImageUrl,
    double? opacity,
    double? blur,
    BoxFit? fit,
    Alignment? alignment,
    DayNightMode? dayNightMode,
  }) {
    return ReaderBackground(
      type: type ?? this.type,
      solidColor: solidColor ?? this.solidColor,
      imageUrl: imageUrl ?? this.imageUrl,
      dayImageUrl: dayImageUrl ?? this.dayImageUrl,
      nightImageUrl: nightImageUrl ?? this.nightImageUrl,
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
      fit: fit ?? this.fit,
      alignment: alignment ?? this.alignment,
      dayNightMode: dayNightMode ?? this.dayNightMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'solidColor': solidColor.toARGB32(),
    'imageUrl': imageUrl,
    'dayImageUrl': dayImageUrl,
    'nightImageUrl': nightImageUrl,
    'opacity': opacity,
    'blur': blur,
    'fit': fit.index,
    'alignment': alignment.x,
    'dayNightMode': dayNightMode.index,
  };

  factory ReaderBackground.fromJson(Map<String, dynamic> json) => ReaderBackground(
    type: ReaderBackgroundType.values[json['type'] as int? ?? 0],
    solidColor: Color(json['solidColor'] as int? ?? 0xFFFFFFFF),
    imageUrl: json['imageUrl'] as String?,
    dayImageUrl: json['dayImageUrl'] as String?,
    nightImageUrl: json['nightImageUrl'] as String?,
    opacity: (json['opacity'] as num?)?.toDouble() ?? 0.3,
    blur: (json['blur'] as num?)?.toDouble() ?? 0,
    fit: BoxFit.values[json['fit'] as int? ?? 0],
    alignment: Alignment(json['alignment'] as double? ?? 0, 0),
    dayNightMode: DayNightMode.values[json['dayNightMode'] as int? ?? 0],
  );
}

class BackgroundImageWidget extends StatelessWidget {
  const BackgroundImageWidget({
    required this.background,
    required this.isNight,
    required this.child,
    super.key,
  });

  final ReaderBackground background;
  final bool isNight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (background.type == ReaderBackgroundType.solid) {
      return ColoredBox(color: background.solidColor, child: child);
    }

    if (background.type == ReaderBackgroundType.gradient) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              background.solidColor,
              background.solidColor.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: child,
      );
    }

    final url = background.getEffectiveUrl(isNight);
    if (url == null) {
      return ColoredBox(color: background.solidColor, child: child);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: _getImageProvider(url),
          fit: background.fit,
          alignment: background.alignment,
          color: Colors.white.withValues(alpha: background.opacity),
          colorBlendMode: BlendMode.overlay,
          errorBuilder: (_, _, _) => ColoredBox(color: background.solidColor),
        ),
        child,
      ],
    );
  }

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('file://')) {
      return FileImage(File(url.replaceFirst('file://', '')));
    }
    return NetworkImage(url);
  }
}

class EInkMode {
  const EInkMode({this.enabled = false});

  final bool enabled;

  EInkMode copyWith({bool? enabled}) {
    return EInkMode(enabled: enabled ?? this.enabled);
  }

  BoxDecoration getContainerDecoration() {
    if (enabled) {
      return BoxDecoration(
        border: Border.all(),
        color: Colors.white,
      );
    }
    return const BoxDecoration();
  }

  TextStyle getTextStyle(TextStyle base) {
    if (enabled) {
      return base.copyWith(
        color: Colors.black,
        fontWeight: FontWeight.w500,
      );
    }
    return base;
  }
}

class BionicReadingMode {
  const BionicReadingMode({this.enabled = false, this.boldFraction = 0.3});

  final bool enabled;
  final double boldFraction;

  String apply(String text) {
    if (!enabled) return text;

    final words = text.split(' ');
    final buffer = StringBuffer();

    for (var i = 0; i < words.length; i++) {
      if (i > 0) buffer.write(' ');
      final word = words[i];
      if (word.isEmpty) continue;

      final boldEnd = (word.length * boldFraction).ceil().clamp(1, word.length);
      buffer.write('<b>');
      buffer.write(word.substring(0, boldEnd));
      buffer.write('</b>');
      if (boldEnd < word.length) {
        buffer.write(word.substring(boldEnd));
      }
    }

    return buffer.toString();
  }
}

class ReaderBackgroundSettings {
  const ReaderBackgroundSettings({
    this.background = const ReaderBackground(),
    this.eInk = const EInkMode(),
    this.bionicReading = const BionicReadingMode(),
  });

  final ReaderBackground background;
  final EInkMode eInk;
  final BionicReadingMode bionicReading;

  ReaderBackgroundSettings copyWith({
    ReaderBackground? background,
    EInkMode? eInk,
    BionicReadingMode? bionicReading,
  }) {
    return ReaderBackgroundSettings(
      background: background ?? this.background,
      eInk: eInk ?? this.eInk,
      bionicReading: bionicReading ?? this.bionicReading,
    );
  }
}

final readerBackgroundProvider = StateProvider<ReaderBackgroundSettings>((ref) {
  return const ReaderBackgroundSettings();
});
