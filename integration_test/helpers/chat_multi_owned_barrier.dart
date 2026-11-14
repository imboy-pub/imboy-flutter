import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

Map<String, String> ownedChatReleaseIdentity({
  required String nonce,
  required String uid,
  required String storageTag,
  required String challenge,
}) {
  if (RegExp(r'^[A-Za-z0-9_-]{1,80}$').stringMatch(nonce) != nonce ||
      RegExp(r'^[1-9][0-9]{0,19}$').stringMatch(uid) != uid ||
      RegExp(r'^[A-Za-z0-9_-]{1,100}$').stringMatch(storageTag) != storageTag ||
      RegExp(r'^[A-Za-z0-9_-]{43}$').stringMatch(challenge) != challenge) {
    throw ArgumentError('invalid owned barrier identity');
  }
  return {
    'nonce': nonce,
    'uid': uid,
    'storageTag': storageTag,
    'challenge': challenge,
    'package': 'pub.imboy.app.uiuxqa',
  };
}

Future<({File release, Map<String, String> identity})> prepareOwnedChatBarrier({
  required String nonce,
  required String uid,
  required String storageTag,
}) async {
  final random = Random.secure();
  final challenge = base64Url
      .encode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
  final identity = ownedChatReleaseIdentity(
    nonce: nonce,
    uid: uid,
    storageTag: storageTag,
    challenge: challenge,
  );
  final root = await (await getApplicationSupportDirectory())
      .resolveSymbolicLinks();
  if (!Platform.isAndroid ||
      !ownedChatBarrierRootMatches(root, uid, storageTag)) {
    throw StateError('barrier requires the owned QA private scope');
  }
  final directory = Directory('$root/.uiux-p1-barrier-$nonce');
  if (await FileSystemEntity.type(directory.path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw StateError('stale barrier directory');
  }
  await directory.create();
  if (await directory.resolveSymbolicLinks() != directory.path) {
    throw StateError('barrier directory changed');
  }
  await File('${directory.path}/request.json')
      .writeAsString(jsonEncode(identity), flush: true);
  final release = File('${directory.path}/release.json');
  return (release: release, identity: identity);
}

bool ownedChatBarrierRootMatches(String root, String uid, String storageTag) {
  final expected = 'imboy-h2-c2c-$storageTag-$uid';
  return RegExp(
        r'^/data/(?:user/0|data)/'
        '${RegExp.escape('pub.imboy.app.uiuxqa')}/(?:files|app_flutter)/'
        '${RegExp.escape(expected)}'
        r'$',
      ).stringMatch(root) ==
      root;
}

Future<bool> ownedChatReleaseMatches(
  File release,
  Map<String, String> identity,
) async {
  final parent = release.absolute.parent;
  if (await FileSystemEntity.type(parent.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      await parent.resolveSymbolicLinks() != parent.path) {
    throw StateError('owned barrier directory changed');
  }
  final kind = await FileSystemEntity.type(release.path, followLinks: false);
  if (kind == FileSystemEntityType.notFound) return false;
  if (kind != FileSystemEntityType.file || await release.length() > 2048) {
    throw StateError('unsafe owned release file');
  }
  final value = jsonDecode(await release.readAsString());
  if (value is! Map ||
      value.length != identity.length ||
      !identity.entries.every((entry) => value[entry.key] == entry.value)) {
    throw StateError('owned release identity mismatch');
  }
  return true;
}
