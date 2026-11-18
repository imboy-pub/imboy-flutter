@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/web_writer_gate.dart';

void main() {
  test(
    'terminal hold rejects new work without executing cancellation cleanup',
    () {
      final registry = AccountLocalTaskRegistry();
      const owner = AccountLocalTaskOwner(
        uid: 'synthetic-hold-owner',
        environment: 'local',
        endpoint: 'http://127.0.0.1:9',
      );
      var cancellationCalls = 0;
      final task = registry.register(
        owner,
        onCancel: () {
          cancellationCalls++;
        },
      );
      registry.suspendForStorageFailure();

      final terminal = isA<WebWriterGateFailure>();
      expect(task.isCancelled, isTrue);
      expect(task.throwIfCancelled, throwsA(terminal));
      expect(() => registry.register(owner), throwsA(terminal));
      expect(() => registry.beginCleanup(owner), throwsA(terminal));
      expect(cancellationCalls, 0);
      task.finish(); // bookkeeping only; no owner cleanup is implicitly called
      expect(cancellationCalls, 0);
    },
  );
}
