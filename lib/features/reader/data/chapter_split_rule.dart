class ChapterSplitRule {
  const ChapterSplitRule({
    required this.id,
    required this.name,
    required this.pattern,
    this.isPreset = false,
    this.isRegex = true,
  });

  final String id;
  final String name;
  final String pattern;
  final bool isPreset;
  final bool isRegex;

  static const List<ChapterSplitRule> presets = [
    ChapterSplitRule(
      id: 'chinese_standard',
      name: 'Chinese Standard (第X章)',
      pattern: r'^第[零一二三四五六七八九十百千万\d]+章',
      isPreset: true,
    ),
    ChapterSplitRule(
      id: 'chinese_volume',
      name: 'Chinese Volume (第X卷)',
      pattern: r'^第[零一二三四五六七八九十百千万\d]+卷',
      isPreset: true,
    ),
    ChapterSplitRule(
      id: 'english_chapter',
      name: 'English Chapter',
      pattern: r'^Chapter\s+\d+',
      isPreset: true,
    ),
    ChapterSplitRule(
      id: 'english_part',
      name: 'English Part',
      pattern: r'^Part\s+\d+',
      isPreset: true,
    ),
    ChapterSplitRule(
      id: 'number_dots',
      name: 'Number with Dots (1. Title)',
      pattern: r'^\d+\.\s+',
      isPreset: true,
    ),
    ChapterSplitRule(
      id: 'number_dash',
      name: 'Number with Dash (1 - Title)',
      pattern: r'^\d+\s*[-–—]\s+',
      isPreset: true,
    ),
    ChapterSplitRule(
      id: 'hash_number',
      name: 'Hash Number (#1 Title)',
      pattern: r'^#\d+\s+',
      isPreset: true,
    ),
    ChapterSplitRule(
      id: 'separator',
      name: 'Separator (--- or ===)',
      pattern: r'^[-=]{3,}\s*$',
      isPreset: true,
    ),
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pattern': pattern,
    'isPreset': isPreset,
    'isRegex': isRegex,
  };

  factory ChapterSplitRule.fromJson(Map<String, dynamic> json) {
    return ChapterSplitRule(
      id: json['id'] as String,
      name: json['name'] as String,
      pattern: json['pattern'] as String,
      isPreset: json['isPreset'] as bool? ?? false,
      isRegex: json['isRegex'] as bool? ?? true,
    );
  }

  bool matchesLine(String line) {
    if (isRegex) {
      return RegExp(pattern, multiLine: true).hasMatch(line);
    }
    return line.contains(pattern);
  }
}
