import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/c2g_send_gate.dart';

void main() {
  test(
    'same account and message serialize until the previous action ends',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final order = <String>[];
      final first = C2gSendGate.run('a', 'id', () async {
        order.add('first');
        entered.complete();
        await release.future;
        order.add('first done');
      });
      await entered.future;
      final second = C2gSendGate.run('a', 'id', () async {
        order.add('second');
      });
      final other = C2gSendGate.run('b', 'id', () async {
        order.add('other');
      });
      await other;
      expect(order, ['first', 'other']);
      release.complete();
      await Future.wait([first, second]);
      expect(order, ['first', 'other', 'first done', 'second']);
    },
  );

  test('a failure releases the same message gate', () async {
    await expectLater(
      C2gSendGate.run<void>('a', 'id', () async => throw StateError('test')),
      throwsStateError,
    );
    expect(await C2gSendGate.run('a', 'id', () async => 7), 7);
  });
}
