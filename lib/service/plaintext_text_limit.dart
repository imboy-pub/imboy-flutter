import 'dart:convert';

/// Plaintext message body limit; callers provide exactly the text to be sent.
abstract final class PlaintextTextLimit {
  static const maxBytes = 64 * 1024;
  static const errorCode = 'message_text_too_large';

  static bool exceeded(String text) => utf8.encode(text).length > maxBytes;

  /// Inspect only declared plaintext text bodies, never ciphertext or metadata.
  static bool exceededPayload({
    required Object? msgType,
    required Object? action,
    required Object? payload,
  }) {
    if (msgType != 'text' ||
        (action != null && action != '' && action != 'message_edit') ||
        payload is! Map) {
      return false;
    }
    final text =
        payload['text'] ??
        (action == 'message_edit' ? payload['content'] : null);
    return text is String && exceeded(text);
  }
}
