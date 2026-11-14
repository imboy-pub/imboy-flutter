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
}
