/// Typed pre-dispatch rejection, not proof of a remote request or success.
class WebControlBeforeDispatch implements Exception {
  const WebControlBeforeDispatch();
}

/// A Web overall deadline, deliberately distinct from user cancellation and
/// unobservable XHR phases. Dispatched means Fetch was admitted, not delivered.
class WebControlDeadlineExceeded implements Exception {
  const WebControlDeadlineExceeded({
    required this.budget,
    required this.phase,
    required this.dispatched,
  });
  final Duration budget;
  final String phase;
  final bool dispatched;
  @override
  String toString() => 'Web control deadline: $phase; dispatched=$dispatched';
}
