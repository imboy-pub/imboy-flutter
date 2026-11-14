import 'package:flutter_test/flutter_test.dart';

import '../../../../../integration_test/helpers/chat_multi_bundle_history.dart';

void main() {
  Map<String, dynamic> snapshot(List<Object?> entries) => {
    'bundle_version': 1,
    'title': 'synthetic',
    'entries': entries,
  };
  test('snapshot canonicalization sorts nested maps, retains entry order and all fields', () {
    final first = snapshot([
      {
        'payload': {'b': 2, 'a': 1},
        'id': 'one',
      },
      {'id': 'two'},
    ]);
    final reordered = {
      'entries': [
        {
          'id': 'one',
          'payload': {'a': 1, 'b': 2},
        },
        {'id': 'two'},
      ],
      'title': 'synthetic',
      'bundle_version': 1,
    };
    expect(bundleSnapshotDigest(first), bundleSnapshotDigest(reordered));
    expect(
      bundleSnapshotDigest(first),
      isNot(
        bundleSnapshotDigest(
          snapshot((first['entries'] as List).reversed.toList()),
        ),
      ),
    );
    expect(
      bundleSnapshotDigest(first),
      isNot(
        bundleSnapshotDigest(
          snapshot([
            {
              'payload': {'b': 3, 'a': 1},
              'id': 'one',
            },
            {'id': 'two'},
          ]),
        ),
      ),
    );
    expect(
      bundleUiReceipt('nonce', 'message', first),
      startsWith('UIUX-BUNDLE-ACK:nonce:message:'),
    );
  });
  test('all optional v1 snapshot fields affect the receipt digest', () {
    final original = {
      ...snapshot(<Object?>[]),
      'sender_name': 'sender',
      'exported_at': 42,
    };
    expect(
      bundleSnapshotDigest(original),
      isNot(bundleSnapshotDigest({...original, 'sender_name': 'other'})),
    );
    expect(
      bundleSnapshotDigest(original),
      isNot(bundleSnapshotDigest({...original, 'exported_at': 43})),
    );
  });
  test('snapshot and receipt reject malformed identity or non JSON values', () {
    expect(
      () => bundleSnapshotDigest({'title': '', 'entries': <Object?>[]}),
      throwsStateError,
    );
    expect(
      () => bundleSnapshotDigest(snapshot([double.nan])),
      throwsStateError,
    );
    expect(
      () => bundleSnapshotDigest(
        snapshot([
          {1: 'bad'},
        ]),
      ),
      throwsStateError,
    );
    expect(
      () => bundleUiReceipt('bad:nonce', 'message', snapshot(<Object?>[])),
      throwsArgumentError,
    );
  });
  test('forward-each UI receipts bind nonce, exact IDs and ordered kinds', () {
    final ids = ['one', 'two', 'three', 'four', 'five'];
    final kinds = ['m1', 'image', 'm2', 'file', 'm3'];
    final manifest = forwardEachUiReceipt('run', ids, kinds, manifest: true);
    expect(parseForwardEachManifest(manifest, 'run')?.ids, ids);
    expect(parseForwardEachManifest(manifest, 'run')?.kinds, kinds);
    expect(parseForwardEachManifest(manifest, 'other'), isNull);
    expect(parseForwardEachManifest('$manifest ', 'run'), isNull);
    final receipt = forwardEachUiReceipt('run', ids, kinds);
    expect(parseForwardEachManifest(receipt, 'run'), isNull);
    expect(receipt, isNot(forwardEachUiReceipt('other', ids, kinds)));
    expect(
      receipt,
      isNot(forwardEachUiReceipt('run', ids.reversed.toList(), kinds)),
    );
    expect(
      receipt,
      isNot(
        forwardEachUiReceipt('run', ids, ['m1', 'file', 'm2', 'image', 'm3']),
      ),
    );
    expect(
      () => forwardEachUiReceipt('run', [
        'one',
        'one',
        'two',
        'three',
        'four',
      ], kinds),
      throwsArgumentError,
    );
    expect(
      () => forwardEachUiReceipt('bad:nonce', ids, kinds),
      throwsArgumentError,
    );
    expect(
      () =>
          forwardEachUiReceipt('run', ids, ['m1', 'image', 'm3', 'file', 'm2']),
      throwsArgumentError,
    );
  });
}
