import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/src/rust/api/frb_generated.dart';
import 'package:stack_trace/stack_trace.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Allow stack_trace package traces in Flutter test framework.
  FlutterError.demangleStackTrace = (StackTrace stack) {
    if (stack is Trace) return stack.vmTrace;
    return stack;
  };

  // ponytail: init FRB once globally so any test touching the Rust bridge works.
  // Safe to call multiple times — FRB ignores redundant inits.
  try {
    await RustLib.init();
  } on Object {
    // Native lib unavailable (e.g. CI without compiled Rust) — tests that
    // call Rust functions will fail individually instead of hanging.
  }

  await testMain();
}
