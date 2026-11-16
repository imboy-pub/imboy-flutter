/// Explicit W09 wiring; default uploader remains unavailable until injected.
library;

export 'browser_attachment_durability_stub.dart'
    if (dart.library.js) 'browser_attachment_durability_web.dart';
