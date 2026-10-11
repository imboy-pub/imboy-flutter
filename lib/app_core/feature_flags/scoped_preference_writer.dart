/// Serialize native writes so a slow older write cannot land after newer state.
class ScopedPreferenceWriter {
  static Future<void> _tail = Future<void>.value();

  static Future<bool> write({
    required bool Function() isCurrent,
    required Future<void> Function() operation,
  }) {
    final result = _tail.then((_) async {
      if (!isCurrent()) return false;
      await operation();
      return isCurrent();
    });
    // Only the queue continuation consumes errors; the caller receives them.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
