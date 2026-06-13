import 'dart:convert';

import 'package:drift/drift.dart';

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    try {
      final decoded = jsonDecode(fromDb);
      if (decoded is List) {
        return decoded.map((e) => e?.toString() ?? '').toList();
      }
      return [];
    } on Object {
      return [];
    }
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
