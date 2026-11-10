import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/app_core/feature_flags/feature_scope.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/account_local_data_service.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/account_media_cache_store.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket_message_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = 'account-a';
  const otherUid = 'account-ab';
  const endpoint = 'https://history.example.invalid';
  const environment = 'local';
  const account = AccountLocalTaskOwner(
    uid: uid,
    environment: environment,
    endpoint: endpoint,
  );
  const otherAccount = AccountLocalTaskOwner(
    uid: otherUid,
    environment: environment,
    endpoint: endpoint,
  );
  final digest = sha256
      .convert(utf8.encode(jsonEncode([endpoint, uid])))
      .toString();
  final otherDigest = sha256
      .convert(utf8.encode(jsonEncode([endpoint, otherUid])))
      .toString();
  final uploadDigest = sha256
      .convert(utf8.encode('$environment:$uid'))
      .toString();
  final otherUploadDigest = sha256
      .convert(utf8.encode('$environment:$otherUid'))
      .toString();
  late Directory root;
  late Directory databases, support, cache, temporary;
  late Map<String, String> secure;
  late int memoryClears, notificationClears;

  AccountMediaCacheStore mediaStore() => AccountMediaCacheStore(
    cacheDirectory: () async => cache,
    temporaryDirectory: () async => temporary,
  );

  String featureKey(
    String owner, {
    String source = endpoint,
    String hash = 'old-build',
  }) {
    // Build the identity with the production writer: its normalized endpoint
    // includes URI serialization details that a raw input string does not.
    FeatureScope.bind(endpoint: source, uid: owner);
    final scope = jsonDecode(
      utf8.decode(base64Url.decode(FeatureScope.key!)),
    ) as List<dynamic>;
    scope[2] = hash;
    return FeatureScope.cacheKey(
      Keys.appFeatures,
      base64Url.encode(utf8.encode(jsonEncode(scope))),
    );
  }

  Future<void> seed(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    await StorageService.init();
  }

  Future<void> file(String relative) async {
    final target = File(p.join(root.path, relative));
    await target.parent.create(recursive: true);
    await target.writeAsString('synthetic account data');
  }

  Future<List<String>> mediaFiles(AccountLocalTaskOwner owner) async {
    final key = await mediaStore().reserve(
      owner,
      'https://media.example.invalid/file',
    );
    final relative = [
      'cache/cross_cache/${AccountMediaCacheStore.digest(key)}',
      'temporary/account_media_cache/${AccountMediaCacheStore.scopeId(owner)}/file.bin',
    ];
    for (final path in relative) {
      await file(path);
    }
    return relative;
  }

  Future<void> removeDatabase(String owner, String env) async {
    for (final artifact in ['', '.pre_restore.bak', '.restoring.tmp']) {
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final target = File(
          p.join(databases.path, '${env}_$owner.db$artifact$suffix'),
        );
        if (await target.exists()) await target.delete();
      }
    }
  }

  AccountLocalDataService service({
    Future<void> Function(String)? deleteSecure,
    Future<void> Function(String, String)? deleteDatabase,
  }) => AccountLocalDataService(
    databaseDirectory: () async => databases,
    supportDirectory: () async => support,
    cacheDirectory: () async => cache,
    documentsDirectory: () async => Directory(p.join(root.path, 'documents')),
    temporaryDirectory: () async => temporary,
    systemTemporaryDirectory: () async => temporary,
    deleteDatabase: deleteDatabase ?? removeDatabase,
    readSecure: () async => Map.of(secure),
    deleteSecure:
        deleteSecure ??
        (key) async {
          secure.remove(key);
        },
    clearSessionMemory: () {
      memoryClears++;
    },
    validateNotifications: () async {},
    clearNotifications: (_) async {
      notificationClears++;
    },
    clearMediaCache: (owner) => mediaStore().removeAccount(
      owner,
      deleteKey: (key) async {
        final target = File(
          p.join(cache.path, 'cross_cache', AccountMediaCacheStore.digest(key)),
        );
        if (await target.exists()) await target.delete();
      },
      containsKey: (key) => File(
        p.join(cache.path, 'cross_cache', AccountMediaCacheStore.digest(key)),
      ).exists(),
    ),
  );

  Future<void> clear(AccountLocalDataService target, {bool last = false}) =>
      target.clear(
        uid: uid,
        environment: environment,
        endpoint: endpoint,
        clearLastSessionData: last,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('imboy-history-cleanup-');
    databases = Directory(p.join(root.path, 'databases'));
    support = Directory(p.join(root.path, 'support'));
    cache = Directory(p.join(root.path, 'cache'));
    temporary = Directory(p.join(root.path, 'temporary'));
    secure = {};
    memoryClears = notificationClears = 0;
    await seed({});
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('removes selected durable data and media while preserving other owners', () async {
    final selectedKeys = <String>[
      'draft_v2:$uid:C2C:peer',
      'draftCursor_v2:$uid:C2C:peer',
      'org_current_$uid',
      'quick_replies:$uid',
      account.preferenceKey('chat_search_history'),
      account.preferenceKey('user_collect_pinned_ids'),
      account.preferenceKey('imboy.deleted_message_ids.v1'),
      'moment_failed_draft_$uid',
      'moment_last_visibility_$uid',
      'local_product_experience_$uid',
      'group_notice_disabled:$uid:100',
      'group_membership_self_heal_${environment}_$uid',
      'offline_cursor_c2g_page_${environment}_$uid',
      'message_search_history_v2_$digest',
      'web_search_history_v2_$digest',
      'creation_intent:${endpoint.length}:$endpoint:$uid:create_group:personal',
      'org_group_rename_pending:${endpoint.length}:$endpoint:$uid:workspace',
      'msg_history_seq_c2g:100_repair_v2_${uid}_$endpoint',
      'msg_history_seq_c2g:100_repair_v2_${uid}_${endpoint}_gap_1_7',
      featureKey(uid),
      featureKey(uid, hash: 'new-build'),
    ];
    final preservedKeys = <String>[
      'draft_v2:$otherUid:C2C:peer',
      'org_current_$otherUid',
      'quick_replies:$otherUid',
      otherAccount.preferenceKey('chat_search_history'),
      otherAccount.preferenceKey('user_collect_pinned_ids'),
      otherAccount.preferenceKey('imboy.deleted_message_ids.v1'),
      'group_notice_disabled:$otherUid:100',
      'message_search_history_v2_$otherDigest',
      featureKey(otherUid),
      featureKey(uid, source: 'https://other.example.invalid'),
      'app_features_scoped_corrupt',
      'theme_type',
    ];
    await seed({
      for (final key in [...selectedKeys, ...preservedKeys])
        key: 'retained until cleanup',
      Keys.currentUser: jsonEncode({'user_id': otherUid}),
      Keys.loginHistoryAccount: ['alice', 'bob'],
      'ws_message_queue': [
        jsonEncode({'ownerUid': uid, 'id': 'one'}),
        jsonEncode({'ownerUid': otherUid, 'id': 'two'}),
      ],
      'imboy.pending_read_receipts.v1': jsonEncode([
        {'from': uid, 'id': 'one'},
        {'from': otherUid, 'id': 'two'},
      ]),
    });
    secure = {
      'db_cipher_key_$uid': 'selected-db-key',
      'utk_$environment:$uid:upload': 'selected-upload-key',
      'talk_record_ai_v1_${digest}_openai': 'selected-ai-key',
      'db_cipher_key_$otherUid': 'other-db-key',
      'utk_$environment:$otherUid:upload': 'other-upload-key',
      'talk_record_ai_v1_${otherDigest}_openai': 'other-ai-key',
      'e2ee_private_key': 'other-last-session',
      'secure_token': 'other-last-session',
      'private_key': 'device-key',
      'trk_recording-a': 'recording-key-a',
      'trk_recording-b': 'recording-key-b',
      'trk_talk-ai-${'a' * 64}': 'ai-checkpoint-a',
      'trk_talk-ai-${'b' * 64}': 'ai-checkpoint-b',
    };
    final deleted = [
      'databases/${environment}_$uid.db',
      'databases/${environment}_$uid.db-wal',
      'databases/${environment}_$uid.db.pre_restore.bak',
      'support/imboy_db_snapshots/$environment/$uid/one.db',
      'support/talk_record/$digest/audio/recording-a/part.enc',
      'support/talk_record/$digest/ai/talk-ai-${'a' * 64}.enc',
      'cache/attachment_uploads/$uploadDigest/staging.bin',
      'temporary/account_local_data/${account.storageDigest}/voice.aac',
      ...await mediaFiles(account),
    ];
    final kept = [
      'databases/${environment}_$otherUid.db',
      'support/imboy_db_snapshots/$environment/$otherUid/one.db',
      'support/talk_record/$otherDigest/audio/recording-b/part.enc',
      'support/talk_record/$otherDigest/ai/talk-ai-${'b' * 64}.enc',
      'cache/attachment_uploads/$otherUploadDigest/staging.bin',
      'temporary/account_local_data/${otherAccount.storageDigest}/voice.aac',
      ...await mediaFiles(otherAccount),
      ...await mediaFiles(
        const AccountLocalTaskOwner(uid: '', environment: '', endpoint: ''),
      ),
    ];
    for (final path in [...deleted, ...kept]) {
      await file(path);
    }
    await clear(service());
    for (final path in deleted) {
      expect(
        await File(p.join(root.path, path)).exists(),
        isFalse,
        reason: path,
      );
    }
    for (final path in kept) {
      expect(
        await File(p.join(root.path, path)).exists(),
        isTrue,
        reason: path,
      );
    }
    for (final key in selectedKeys) {
      expect(StorageService.to.getKeys(), isNot(contains(key)), reason: key);
    }
    for (final key in preservedKeys) {
      expect(StorageService.to.getKeys(), contains(key), reason: key);
    }
    expect(
      secure.keys,
      unorderedEquals([
        'db_cipher_key_$otherUid',
        'utk_$environment:$otherUid:upload',
        'talk_record_ai_v1_${otherDigest}_openai',
        'e2ee_private_key',
        'secure_token',
        'private_key',
        'trk_recording-b',
        'trk_talk-ai-${'b' * 64}',
      ]),
    );
    expect(StorageService.to.getStringList(Keys.loginHistoryAccount), [
      'alice',
      'bob',
    ]);
    expect(StorageService.getMap(Keys.currentUser)['user_id'], otherUid);
    expect(StorageService.to.getStringList('ws_message_queue'), [
      jsonEncode({'ownerUid': otherUid, 'id': 'two'}),
    ]);
    expect(
      jsonDecode(StorageService.to.getString('imboy.pending_read_receipts.v1')),
      [
        {'from': otherUid, 'id': 'two'},
      ],
    );
    expect(memoryClears, 0);
    expect(notificationClears, 1);
  });

  for (final last in [false, true]) {
    test(
      'passphrase UID takes precedence over last profile (last=$last)',
      () async {
        const key = 'e2ee_backup_passphrase';
        await seed({
          Keys.currentUser: jsonEncode({'user_id': last ? uid : otherUid}),
        });
        final value = jsonEncode({
          'uid': last ? otherUid : uid,
          'passphrase': 'synthetic recovery passphrase',
        });
        secure = {key: value, 'db_cipher_key_$otherUid': 'retained'};
        await clear(service(), last: last);
        expect(secure[key], last ? value : isNull);
        expect(secure['db_cipher_key_$otherUid'], 'retained');
      },
    );
  }

  for (final raw in [
    'legacy plain text',
    '{"uid":"","passphrase":"x"}',
    '{"passphrase":"x"}',
  ]) {
    test(
      'unattributed passphrase blocks cleanup before deletion: $raw',
      () async {
        await seed({
          Keys.currentUser: jsonEncode({'user_id': uid}),
        });
        await file('databases/${environment}_$uid.db');
        secure = {'e2ee_backup_passphrase': raw, 'db_cipher_key_$uid': 'keep'};
        await expectLater(
          clear(service(), last: true),
          throwsA(isA<AccountLocalDataOwnershipException>()),
        );
        expect(secure['e2ee_backup_passphrase'], raw);
        expect(secure['db_cipher_key_$uid'], 'keep');
        expect(
          await File(p.join(databases.path, '${environment}_$uid.db')).exists(),
          isTrue,
        );
        expect(StorageService.getMap(Keys.currentUser)['user_id'], uid);
      },
    );
  }

  test('last-session cleanup removes legacy data and keeps device and other account secrets', () async {
    await seed({
      Keys.currentUser: jsonEncode({'user_id': uid}),
      Keys.e2eePurgePending: true,
      'offline_cursor_c2c': 123,
      'e2ee_recovery_needed': true,
      'msg_history_seq_c2c:old': 5,
      'current_language_code': 'en_US',
      'e2ee_notify_on_failed': false,
      'e2ee_backup_setup_done': true,
      'chat_background': 'device-background',
      'chat_background_opacity': '0.5',
      'chat_use_custom_color': true,
      'chat_custom_color': '112233',
      'chat_custom_image_path': '/user/chosen/background.png',
      'ws_url': 'wss://device.example.invalid',
      'upload_url': 'https://device.example.invalid/upload',
      'upload_key': 'device-upload-config',
      'upload_scene': 'device-scene',
      'draft_v2:$otherUid:C2C:peer': 'other draft',
      'msg_history_seq_c2g:100_repair_v2_${otherUid}_$endpoint': 9,
      'msg_history_seq_c2g:100_repair_v2_${uid}_https://other.example.invalid':
          9,
    });
    secure = {
      'db_cipher_key_$uid': 'selected-db-key',
      'db_cipher_key_$otherUid': 'other-db-key',
      'utk_$environment:$otherUid:upload': 'other-upload-key',
      'talk_record_ai_v1_${otherDigest}_openai': 'other-ai-key',
      'e2ee_private_key': 'last-account-key',
      'olm_account_pickle': 'last-account-pickle',
      'collect_ck_keychain_v1': 'last-account-collection',
      'secure_token': 'last-token',
      'secure_refresh_token': 'last-refresh',
      'upload_key': 'last-upload',
      'private_key': 'device-password-key',
      'compliance_key_pin_v1': 'device-pin',
    };
    for (final path in [
      'temporary/account_local_data/${account.storageDigest}/voice_tmp_123.aac',
      'temporary/account_local_data/${account.storageDigest}/imboy_e2ee_backup_incoming_old.enc',
      'temporary/account_local_data/${account.storageDigest}/imboy_data_123.json',
      'temporary/unrelated.txt',
      'cache/attachment_uploads/$otherUploadDigest/other.bin',
    ]) {
      await file(path);
    }
    await clear(service(), last: true);
    expect(
      secure.keys,
      unorderedEquals([
        'db_cipher_key_$otherUid',
        'utk_$environment:$otherUid:upload',
        'talk_record_ai_v1_${otherDigest}_openai',
        'private_key',
        'compliance_key_pin_v1',
        'upload_key',
      ]),
    );
    expect(StorageService.getMap(Keys.currentUser), isEmpty);
    expect(
      StorageService.to.getKeys(),
      containsAll(['current_language_code', 'draft_v2:$otherUid:C2C:peer']),
    );
    expect(StorageService.to.getBool('e2ee_notify_on_failed'), isFalse);
    expect(StorageService.to.getBool('e2ee_backup_setup_done'), isTrue);
    expect(StorageService.to.getString('chat_background'), 'device-background');
    expect(
      StorageService.to.getString('chat_custom_image_path'),
      '/user/chosen/background.png',
    );
    expect(
      StorageService.to.getString('ws_url'),
      'wss://device.example.invalid',
    );
    expect(
      StorageService.to.getString('upload_url'),
      'https://device.example.invalid/upload',
    );
    expect(StorageService.to.getString('upload_key'), 'device-upload-config');
    expect(StorageService.to.getString('upload_scene'), 'device-scene');
    expect(
      StorageService.to.getKeys(),
      isNot(contains('e2ee_recovery_needed')),
    );
    expect(StorageService.to.getKeys(), isNot(contains(Keys.e2eePurgePending)));
    expect(
      StorageService.to.getKeys(),
      containsAll([
        'msg_history_seq_c2g:100_repair_v2_${otherUid}_$endpoint',
        'msg_history_seq_c2g:100_repair_v2_${uid}_https://other.example.invalid',
      ]),
    );
    expect(
      await Directory(p.join(cache.path, 'cross_cache')).exists(),
      isFalse,
    );
    expect(
      await File(
        p.join(
          temporary.path,
          'account_local_data',
          account.storageDigest,
          'voice_tmp_123.aac',
        ),
      ).exists(),
      isFalse,
    );
    expect(
      await File(p.join(temporary.path, 'unrelated.txt')).exists(),
      isTrue,
    );
    expect(
      await File(
        p.join(
          cache.path,
          'attachment_uploads',
          otherUploadDigest,
          'other.bin',
        ),
      ).exists(),
      isTrue,
    );
    expect(memoryClears, 1);
    expect(notificationClears, 1);
  });

  test('a silently rejected secret deletion fails, retains attribution and permits retry', () async {
    await seed({
      Keys.currentUser: jsonEncode({'user_id': uid}),
    });
    secure['e2ee_private_key'] = 'synthetic';
    await file('support/talk_record/$digest/audio/part.enc');
    await expectLater(
      clear(service(deleteSecure: (_) async {}), last: true),
      throwsStateError,
    );
    expect(StorageService.getMap(Keys.currentUser)['user_id'], uid);
    expect(secure, isNotEmpty);
    expect(memoryClears, 0);
    await clear(service(), last: true);
    await clear(service(), last: true);
    expect(secure, isEmpty);
    expect(StorageService.getMap(Keys.currentUser), isEmpty);
  });

  for (final legacyPath in [
    'cache/cross_cache/unknown',
    'temporary/imboy_cache/old-image.bin',
    'temporary/db_snapshots/old-migration.db',
    'temporary/voice_tmp_123.aac',
    'temporary/imboy_e2ee_backup_123.enc',
    'temporary/imboy_data_123.json',
    'temporary/cropped_123.jpg',
    'temporary/imboy-direct-old/body',
    'cache/09-11-26-03-04-05123456789.m4a',
    'documents/26-11-09-15-04-05.m4a',
  ]) {
    test('unknown ownership rejects before deletion: $legacyPath', () async {
      await seed({
        Keys.currentUser: jsonEncode({'user_id': uid}),
        'quick_replies:$uid': 'retain',
      });
      secure['db_cipher_key_$uid'] = 'retain';
      await file('databases/${environment}_$uid.db');
      await file(legacyPath);
      await expectLater(
        clear(service(), last: true),
        throwsA(isA<AccountLocalDataOwnershipException>()),
      );
      expect(secure['db_cipher_key_$uid'], 'retain');
      expect(StorageService.to.getString('quick_replies:$uid'), 'retain');
      expect(
        await File(p.join(databases.path, '${environment}_$uid.db')).exists(),
        isTrue,
      );
      expect(await File(p.join(root.path, legacyPath)).exists(), isTrue);
      expect(notificationClears, 0);
    });
  }

  for (final legacyKey in [
    'chat_search_history',
    'user_collect_pinned_ids',
    'imboy.deleted_message_ids.v1',
  ]) {
    test(
      'legacy mixed account preference blocks cleanup: $legacyKey',
      () async {
        await seed({
          legacyKey: ['unknown owner'],
        });
        secure['db_cipher_key_$uid'] = 'retain';
        await expectLater(
          clear(service()),
          throwsA(isA<AccountLocalDataOwnershipException>()),
        );
        expect(secure['db_cipher_key_$uid'], 'retain');
        expect(StorageService.to.getStringList(legacyKey), ['unknown owner']);
      },
    );
  }

  test(
    'orphan recording key blocks without deleting another account',
    () async {
      secure.addAll({
        'trk_orphan': 'unattributed',
        'db_cipher_key_$uid': 'retain',
      });
      await file('support/talk_record/$otherDigest/audio/known-b/part.enc');
      await expectLater(
        clear(service()),
        throwsA(isA<AccountLocalDataOwnershipException>()),
      );
      expect(secure, containsPair('trk_orphan', 'unattributed'));
      expect(secure, containsPair('db_cipher_key_$uid', 'retain'));
    },
  );

  test(
    'recording attribution survives a failed key removal and retry',
    () async {
      final marker =
          'support/talk_record/$digest/ai/talk-ai-${'c' * 64}.enc.owner';
      final key = 'trk_talk-ai-${'c' * 64}';
      secure[key] = 'checkpoint-key';
      await file(marker);
      await expectLater(
        clear(service(deleteSecure: (_) async {})),
        throwsStateError,
      );
      expect(await File(p.join(root.path, marker)).exists(), isTrue);
      expect(secure[key], 'checkpoint-key');
      await clear(service());
      expect(secure, isEmpty);
      expect(await File(p.join(root.path, marker)).exists(), isFalse);
    },
  );

  test(
    'corrupt pending actions block before deleting durable account files',
    () async {
      await seed({'imboy.pending_reactions.v1': '{invalid'});
      await file('databases/${environment}_$uid.db');
      await expectLater(
        clear(service()),
        throwsA(isA<AccountLocalDataOwnershipException>()),
      );
      expect(
        await File(p.join(databases.path, '${environment}_$uid.db')).exists(),
        isTrue,
      );
    },
  );

  for (final sharedArtifact in [
    'databases/other_$uid.db',
    'databases/other_$uid.db.pre_restore.bak-wal',
    'databases/other_$uid.db.restore.orphan/original.db-wal',
    'support/imboy_db_snapshots/other/$uid/chat-backup.db',
  ]) {
    test(
      'rejects shared UID storage before changing $sharedArtifact',
      () async {
        await seed({
          'draft_v2:$uid:C2C:peer': 'shared draft',
          'org_current_$uid': 'shared organization',
          Keys.currentUser: jsonEncode({'user_id': uid}),
        });
        secure['db_cipher_key_$uid'] = 'shared-across-environments';
        await file('databases/${environment}_$uid.db');
        await file(
          'support/imboy_db_snapshots/$environment/$uid/chat-backup.db',
        );
        await file('cache/cross_cache/download');
        await file(sharedArtifact);
        var databaseDeletes = 0;
        await expectLater(
          clear(
            service(
              deleteDatabase: (_, _) async {
                databaseDeletes++;
              },
            ),
            last: true,
          ),
          throwsA(isA<LoginAccountSharedDataException>()),
        );
        expect(databaseDeletes, 0);
        expect(secure['db_cipher_key_$uid'], 'shared-across-environments');
        expect(
          StorageService.to.getString('draft_v2:$uid:C2C:peer'),
          'shared draft',
        );
        expect(
          StorageService.to.getString('org_current_$uid'),
          'shared organization',
        );
        expect(StorageService.getMap(Keys.currentUser)['user_id'], uid);
        for (final retained in [
          'databases/${environment}_$uid.db',
          'support/imboy_db_snapshots/$environment/$uid/chat-backup.db',
          'cache/cross_cache/download',
          sharedArtifact,
        ]) {
          expect(await File(p.join(root.path, retained)).exists(), isTrue);
        }
      },
    );
  }

  test(
    'rejects active or unproven last-session identity before deleting files',
    () async {
      await file('databases/${environment}_$uid.db');
      await seed({Keys.currentUid: otherUid});
      await expectLater(clear(service()), throwsStateError);
      await seed({
        Keys.currentUser: jsonEncode({'user_id': otherUid}),
      });
      await expectLater(clear(service(), last: true), throwsStateError);
      expect(
        await File(p.join(databases.path, '${environment}_$uid.db')).exists(),
        isTrue,
      );
    },
  );

  test(
    'rejects malformed identity without calling destructive dependencies',
    () async {
      var calls = 0;
      final cleaner = service(
        deleteDatabase: (_, _) async {
          calls++;
        },
      );
      await expectLater(
        cleaner.clear(
          uid: '../unknown',
          environment: environment,
          endpoint: endpoint,
          clearLastSessionData: false,
        ),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );

  test(
    'removed offline cursors cannot return from the previous service instance',
    () async {
      await seed({Keys.offlineCursorC2c: 123, Keys.offlineCursorS2c: 456});
      final offline = MessageOfflineService.instance;
      try {
        await StorageService.to.remove(Keys.offlineCursorC2c);
        await StorageService.to.remove(Keys.offlineCursorS2c);
        MessageOfflineService.resetLocalCursors();
        offline.persistCursors();
        await Future<void>.value();
        // Zero cursors intentionally remain absent in preferences; only
        // positive timestamps are persisted by the offline service.
        expect(StorageService.to.getInt(Keys.offlineCursorC2c), isNull);
        expect(StorageService.to.getInt(Keys.offlineCursorS2c), isNull);
        expect(
          MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c),
          0,
        );
        expect(
          MessageOfflineService.readStoredCursor(Keys.offlineCursorS2c),
          0,
        );
      } finally {
        offline.onDispose();
      }
    },
  );

  test('queue cleanup drains pending writes and removes selected owner from memory and storage', () async {
    final queue = await PersistentMessageQueue.to.init();
    try {
      queue.enqueue('one', '{}', ownerUid: uid);
      queue.enqueue('two', '{}', ownerUid: otherUid);
      await PersistentMessageQueue.removeAccount(uid);
      await queue.flushPersistence();
      expect(queue.messages.map((item) => item.ownerUid), [otherUid]);
      final stored = StorageService.to.getStringList('ws_message_queue')!;
      expect(stored.map((raw) => (jsonDecode(raw) as Map)['ownerUid']), [
        otherUid,
      ]);
    } finally {
      queue.dispose();
      await queue.flushPersistence();
    }
  });
}
