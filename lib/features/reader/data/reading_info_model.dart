enum InfoSlotMode {
  none,
  chapterTitle,
  chapterProgress,
  bookProgress,
  battery,
  time,
  batteryAndTime,
  remainingChapter,
  remainingBook,
  wpm,
  sessionTime,
  streak,
  todayTime,
}

class ReadingInfoModel {
  const ReadingInfoModel({
    this.headerLeft = InfoSlotMode.none,
    this.headerCenter = InfoSlotMode.chapterTitle,
    this.headerRight = InfoSlotMode.time,
    this.footerLeft = InfoSlotMode.bookProgress,
    this.footerCenter = InfoSlotMode.none,
    this.footerRight = InfoSlotMode.chapterProgress,
    this.fontSize = 12.0,
    this.margin = 8.0,
  });

  final InfoSlotMode headerLeft;
  final InfoSlotMode headerCenter;
  final InfoSlotMode headerRight;
  final InfoSlotMode footerLeft;
  final InfoSlotMode footerCenter;
  final InfoSlotMode footerRight;
  final double fontSize;
  final double margin;

  ReadingInfoModel copyWith({
    InfoSlotMode? headerLeft,
    InfoSlotMode? headerCenter,
    InfoSlotMode? headerRight,
    InfoSlotMode? footerLeft,
    InfoSlotMode? footerCenter,
    InfoSlotMode? footerRight,
    double? fontSize,
    double? margin,
  }) {
    return ReadingInfoModel(
      headerLeft: headerLeft ?? this.headerLeft,
      headerCenter: headerCenter ?? this.headerCenter,
      headerRight: headerRight ?? this.headerRight,
      footerLeft: footerLeft ?? this.footerLeft,
      footerCenter: footerCenter ?? this.footerCenter,
      footerRight: footerRight ?? this.footerRight,
      fontSize: fontSize ?? this.fontSize,
      margin: margin ?? this.margin,
    );
  }

  Map<String, dynamic> toJson() => {
    'headerLeft': headerLeft.index,
    'headerCenter': headerCenter.index,
    'headerRight': headerRight.index,
    'footerLeft': footerLeft.index,
    'footerCenter': footerCenter.index,
    'footerRight': footerRight.index,
    'fontSize': fontSize,
    'margin': margin,
  };

  factory ReadingInfoModel.fromJson(Map<String, dynamic> json) {
    return ReadingInfoModel(
      headerLeft: _safeSlot(json, 'headerLeft', 0),
      headerCenter: _safeSlot(json, 'headerCenter', 1),
      headerRight: _safeSlot(json, 'headerRight', 5),
      footerLeft: _safeSlot(json, 'footerLeft', 3),
      footerCenter: _safeSlot(json, 'footerCenter', 0),
      footerRight: _safeSlot(json, 'footerRight', 2),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 12.0,
      margin: (json['margin'] as num?)?.toDouble() ?? 8.0,
    );
  }

  static InfoSlotMode _safeSlot(Map<String, dynamic> json, String key, int fallback) {
    final idx = json[key];
    if (idx is int && idx >= 0 && idx < InfoSlotMode.values.length) {
      return InfoSlotMode.values[idx];
    }
    return InfoSlotMode.values[fallback];
  }

  static const ReadingInfoModel defaults = ReadingInfoModel();
}
