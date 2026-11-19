/// Production composers with synthetic transport/storage in the browser runtime.
@TestOn('chrome')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/web_writer_gate.dart';

import 'web_native_draft_handoff_test.dart' as handoff;

void main() {
  debugPrint = debugPrintSynchronously;
  // Chrome requires a real browser writer lease; VM uses the native stub.
  setUpAll(prepareWebWriter);
  handoff.main();
}
