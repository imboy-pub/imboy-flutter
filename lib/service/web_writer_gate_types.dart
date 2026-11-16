enum WebWriterFailureKind { occupied, unavailable, poisoned }

/// Safe boot UI state; never includes credentials, raw paths or plugin payloads.
class WebWriterGateFailure implements Exception {
  const WebWriterGateFailure(this.kind);
  final WebWriterFailureKind kind;

  @override
  String toString() => 'Web writer admission failed: ${kind.name}';
}
