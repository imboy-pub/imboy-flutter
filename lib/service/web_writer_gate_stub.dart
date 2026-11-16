/// Native startup and mutation policies are unchanged.
library;

import 'dart:async';

Future<void> prepareWebWriter() async {}
void requireWebWriter() {}
Future<void> reloadWebWriterPage() async {}

final _noWebWriterFailure = Completer<void>();
Future<void> get webWriterFailure => _noWebWriterFailure.future;

bool get isWebWriterReady => true;

Stream<void> get webWriterFailures => const Stream<void>.empty();
