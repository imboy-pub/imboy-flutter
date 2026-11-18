/// One startup admission boundary; native platforms keep their existing path.
library;

export 'web_writer_gate_types.dart';
export 'web_writer_gate_stub.dart'
    if (dart.library.js_interop) 'web_writer_gate_web.dart';
