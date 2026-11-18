library;

export 'browser_received_attachment_stub.dart'
    if (dart.library.js_interop) 'browser_received_attachment_web.dart';

// Browser byte retention budget; Native keeps its existing streaming path.
const browserResourceByteBudget = 100 * 1024 * 1024;
