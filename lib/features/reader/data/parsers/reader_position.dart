import 'package:flutter/foundation.dart';

@immutable
class ReaderPosition {
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final double localOffset;

  const ReaderPosition({
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    this.localOffset = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'chapterIndex': chapterIndex,
    'paragraphIndex': paragraphIndex,
    'localOffset': localOffset,
  };

  factory ReaderPosition.fromJson(Map<String, dynamic> json) => ReaderPosition(
    bookId: json['bookId'] as String,
    chapterIndex: json['chapterIndex'] as int,
    paragraphIndex: json['paragraphIndex'] as int,
    localOffset: (json['localOffset'] as num?)?.toDouble() ?? 0.0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderPosition &&
          runtimeType == other.runtimeType &&
          bookId == other.bookId &&
          chapterIndex == other.chapterIndex &&
          paragraphIndex == other.paragraphIndex &&
          localOffset == other.localOffset;

  @override
  int get hashCode =>
      bookId.hashCode ^ chapterIndex.hashCode ^ paragraphIndex.hashCode ^ localOffset.hashCode;
}
