import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'core/http/http_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  HttpClient.enableSslBypass();
  Intl.defaultLocale = 'ru';
  runApp(const ProviderScope(child: GlibustaApp()));
}
