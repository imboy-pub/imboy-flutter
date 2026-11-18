/// Run the production composer component cases in the real browser runtime.
@TestOn('chrome')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'web_chat_input_test.dart' as composer;

void main() {
  debugPrint = debugPrintSynchronously;
  composer.main();
}
