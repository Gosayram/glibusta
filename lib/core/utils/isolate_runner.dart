import 'dart:isolate';

import '../errors/app_failure.dart';
import '../errors/app_result.dart';

Future<AppResult<T>> runInIsolate<T>(T Function() computation) async {
  try {
    final result = await Isolate.run(computation);
    return Success(result);
  } on Object catch (e) {
    return Failure(ParseFailure(message: 'Isolate error: $e'));
  }
}
