/// Non-Web stub: native engines report IME composition into
/// `TextEditingValue.composing` themselves, so the DOM-level guard is a no-op.
class WebImeCompositionGuard {
  /// Always false; native composing is handled by the engine's own
  /// `TextEditingValue.composing` (checked separately by the caller).
  bool get composing => false;

  void dispose() {}
}
