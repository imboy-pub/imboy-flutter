/// Production composers with synthetic transport/storage in the browser runtime.
@TestOn('chrome')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'web_native_draft_handoff_test.dart' as handoff;

void main() {
  debugPrint = debugPrintSynchronously;
  handoff.main();
}
