import 'package:flutter_riverpod/flutter_riverpod.dart';

class Database {
  static final Database _instance = Database._internal();
  factory Database() => _instance;
  Database._internal();
}

final databaseProvider = Provider<Database>((ref) => Database());