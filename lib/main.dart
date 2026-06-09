import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'core/http/dio_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  enableSslBypass();
  Intl.defaultLocale = 'ru';
  runApp(const ProviderScope(child: GlibustaApp()));
}
