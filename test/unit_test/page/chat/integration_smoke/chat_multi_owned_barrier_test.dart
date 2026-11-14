import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../../../integration_test/helpers/chat_multi_owned_barrier.dart';

void main() {
  late Directory root;
  late File release;
  late Map<String, String> identity;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('uiux-owned-barrier-test-');
    root = Directory(await root.resolveSymbolicLinks());
    release = File('${root.path}/release.json');
    identity = ownedChatReleaseIdentity(
      nonce: 'run_1',
      uid: '100',
      storageTag: 'owned_scope',
      challenge: 'a' * 43,
    );
  });
  tearDown(() => root.delete(recursive: true));

  test('barrier root is the exact QA app private owned scope', () {
    const root =
        '/data/user/0/pub.imboy.app.uiuxqa/files/imboy-h2-c2c-owned_scope-100';
    expect(ownedChatBarrierRootMatches(root, '100', 'owned_scope'), isTrue);
    expect(
      ownedChatBarrierRootMatches(
        root.replaceFirst('/user/0/', '/data/'),
        '100',
        'owned_scope',
      ),
      isTrue,
    );
    for (final path in [
      root.replaceFirst('uiuxqa', 'production'),
      '$root/child',
      '$root/../other',
      root.replaceFirst('/data/user/0/', '/sdcard/'),
      root.replaceFirst('pub.imboy', 'pubXimboy'),
    ]) {
      expect(ownedChatBarrierRootMatches(path, '100', 'owned_scope'), isFalse);
    }
    expect(ownedChatBarrierRootMatches(root, '200', 'owned_scope'), isFalse);
    expect(ownedChatBarrierRootMatches(root, '100', 'old_scope'), isFalse);
  });

  test('missing release waits; exact controller identity releases', () async {
    expect(await ownedChatReleaseMatches(release, identity), isFalse);
    await release.writeAsString(jsonEncode(identity));
    expect(await ownedChatReleaseMatches(release, identity), isTrue);
  });

  test(
    'old nonce, challenge, account, scope or package cannot release',
    () async {
      for (final field in identity.keys) {
        await release.writeAsString(jsonEncode({...identity, field: 'other'}));
        await expectLater(
          ownedChatReleaseMatches(release, identity),
          throwsStateError,
        );
      }
      await release.writeAsString(jsonEncode({...identity, 'extra': true}));
      await expectLater(
        ownedChatReleaseMatches(release, identity),
        throwsStateError,
      );
      await release.writeAsString('{broken');
      await expectLater(
        ownedChatReleaseMatches(release, identity),
        throwsFormatException,
      );
    },
  );

  test('directories, symlinks and oversized files fail closed', () async {
    await Directory(release.path).create();
    await expectLater(
      ownedChatReleaseMatches(release, identity),
      throwsStateError,
    );
    await Directory(release.path).delete();
    final target = await File('${root.path}/target')
        .writeAsString(jsonEncode(identity));
    final link = await Link(release.path).create(target.path);
    await expectLater(
      ownedChatReleaseMatches(release, identity),
      throwsStateError,
    );
    await link.delete();
    await release.writeAsString(' ' * 2049);
    await expectLater(
      ownedChatReleaseMatches(release, identity),
      throwsStateError,
    );
  });

  test(
    'replacing barrier parent or ancestor with a symlink is rejected',
    () async {
      final ancestor = await Directory('${root.path}/ancestor').create();
      final barrier = await Directory('${ancestor.path}/barrier').create();
      final marker = await File('${barrier.path}/release.json')
          .writeAsString(jsonEncode(identity));
      expect(await ownedChatReleaseMatches(marker, identity), isTrue);
      final moved = await ancestor.rename('${root.path}/moved');
      final alias = await Link(ancestor.path).create(moved.path);
      await expectLater(
        ownedChatReleaseMatches(marker, identity),
        throwsStateError,
      );
      await alias.delete();
      await moved.rename(ancestor.path);
      final movedBarrier = await barrier.rename('${ancestor.path}/other');
      await Link(barrier.path).create(movedBarrier.path);
      await expectLater(
        ownedChatReleaseMatches(marker, identity),
        throwsStateError,
      );
    },
  );

  test('identity rejects traversal, missing nonce and invalid challenge', () {
    for (final nonce in ['', '../old', 'old:run', 'run\n']) {
      expect(
        () => ownedChatReleaseIdentity(
          nonce: nonce,
          uid: '100',
          storageTag: 'owned_scope',
          challenge: 'a' * 43,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => ownedChatReleaseIdentity(
        nonce: 'run',
        uid: '100',
        storageTag: '../scope',
        challenge: 'a' * 43,
      ),
      throwsArgumentError,
    );
    expect(
      () => ownedChatReleaseIdentity(
        nonce: 'run',
        uid: '100',
        storageTag: 'scope',
        challenge: 'old',
      ),
      throwsArgumentError,
    );
  });
}
