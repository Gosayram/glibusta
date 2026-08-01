import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/services/opds_service.dart';

void main() {
  test('built-in OPDS catalogs use the configured base URL', () {
    final catalogs = builtInCatalogs('https://library.example/');

    expect(catalogs.map((catalog) => catalog.url), [
      'https://library.example/opds',
      'https://library.example/opds/recent',
    ]);
  });
}
