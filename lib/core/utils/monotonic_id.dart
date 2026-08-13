int _lastIssuedMicroseconds = 0;

/// Returns a process-local, time-ordered identifier safe for rapid inserts.
///
/// Wall-clock milliseconds are not unique when users create several records
/// within one frame. Advancing from the last issued value also handles a clock
/// that momentarily moves backwards.
String newMonotonicId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final next = now > _lastIssuedMicroseconds ? now : _lastIssuedMicroseconds + 1;
  _lastIssuedMicroseconds = next;
  return next.toString();
}
