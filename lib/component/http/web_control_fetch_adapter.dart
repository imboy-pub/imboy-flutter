/// Scoped Web control dispatch; native transports are unchanged.
library;

export 'web_control_fetch_types.dart';
export 'web_control_fetch_adapter_stub.dart'
    if (dart.library.js_interop) 'web_control_fetch_adapter_web.dart';
