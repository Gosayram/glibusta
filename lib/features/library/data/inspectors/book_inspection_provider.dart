import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/encoding/encoding_detection.dart';
import 'book_file_inspector.dart';
import 'book_format_detector.dart';
import 'book_inspection_result.dart';
import 'book_metadata_extractor.dart';
import 'duplicate_checker.dart';

part 'book_inspection_provider.g.dart';

@riverpod
BookFileInspector bookFileInspector(Ref ref) {
  return BookFileInspector(
    formatDetector: BookFormatDetector(),
    encodingDetector: BookEncodingDetector(),
    metadataExtractor: BookMetadataExtractor(),
    duplicateChecker: DuplicateChecker(ref.watch(databaseProvider)),
  );
}

@riverpod
Future<BookFileInspectionResult> bookFileInspection(
  Ref ref,
  String path,
) async {
  final inspector = ref.watch(bookFileInspectorProvider);
  return inspector.inspect(path);
}
