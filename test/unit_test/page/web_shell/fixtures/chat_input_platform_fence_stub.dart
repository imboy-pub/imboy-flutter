import 'dart:io';

ChatInputPlatformFence? _active;

class ChatInputPlatformFence {
  ChatInputPlatformFence? _previous;
  int denied = 0;
  void install() {
    _previous = _active;
    _active = this;
  }

  void restore() => _active = _previous;
}

Future<T> runInChatInputIoZone<T>(Future<T> Function() body) {
  final fence = _active;
  // Enter inside the registered test body, below Flutter test's existing zone.
  // Do not replace the process-global HttpOverrides or inherit a weaker parent.
  return HttpOverrides.runZoned(
    body,
    createHttpClient: (_) {
      if (fence != null) fence.denied++;
      throw StateError('Composer test forbids native HTTP dispatch');
    },
  );
}
