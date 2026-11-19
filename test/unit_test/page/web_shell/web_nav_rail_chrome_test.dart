/// The same production navigation semantics cases in the real browser runtime.
@TestOn('chrome')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/web_writer_gate.dart';

import 'web_nav_rail_test.dart' as rail;

void main() {
  debugPrint = debugPrintSynchronously;
  setUpAll(prepareWebWriter);
  rail.main();
}
