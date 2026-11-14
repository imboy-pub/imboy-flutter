import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../integration_test/enterprise/macos_storage_isolation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('H2 persisted macOS scope', () {
    late String tag;
    late Directory root;
    const uid = '123456';

    setUp(() async {
      tag = 'scope-${DateTime.now().microsecondsSinceEpoch}';
      final temp = await Directory.systemTemp.resolveSymbolicLinks();
      root = Directory('$temp/imboy-h2-c2c-$tag-$uid');
    });

    tearDown(() async {
      final type = await FileSystemEntity.type(root.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        await Link(root.path).delete();
      } else if (type == FileSystemEntityType.directory) {
        await root.delete(recursive: true);
      }
    });

    test(
      'create and restore retain identity and private permissions',
      () async {
        final originalPaths = PathProviderPlatform.instance;
        final originalKeys = FlutterSecureStoragePlatform.instance;
        final created = await prepareH2MacosStorageDirectory(
          tag,
          uid,
          restore: false,
        );
        expect(created.path, root.path);
        expect((await root.stat()).mode & 0x3f, 0);
        await File('${root.path}/history')
            .writeAsString('synthetic-ciphertext');
        final restored = await prepareH2MacosStorageDirectory(
          tag,
          uid,
          restore: true,
        );
        expect(
          await File('${restored.path}/history').readAsString(),
          'synthetic-ciphertext',
        );
        expect(PathProviderPlatform.instance, same(originalPaths));
        expect(FlutterSecureStoragePlatform.instance, same(originalKeys));
        await expectLater(
          prepareH2MacosStorageDirectory(tag, uid, restore: false),
          throwsStateError,
        );
        await expectLater(clearH2MacosStorage(tag, uid), throwsStateError);
        expect(
          await root.exists(),
          isTrue,
          reason: 'uninstalled scope cannot be cleared',
        );
      },
    );

    test('restore missing scope never creates it', () async {
      await expectLater(
        prepareH2MacosStorageDirectory(tag, uid, restore: true),
        throwsStateError,
      );
      expect(await root.exists(), isFalse);
    });

    test('unsafe tags and UIDs are rejected before creating storage', () async {
      for (final unsafe in ['', '..', '../escape', 'a/b', r'a\b', 'a.b']) {
        await expectLater(
          prepareH2MacosStorageDirectory(unsafe, uid, restore: false),
          throwsArgumentError,
        );
      }
      for (final unsafe in ['', '0', '../escape', '123/456', 'abc']) {
        await expectLater(
          prepareH2MacosStorageDirectory(tag, unsafe, restore: false),
          throwsArgumentError,
        );
      }
      expect(await root.exists(), isFalse);
    });

    test('missing, foreign and mismatched markers fail closed', () async {
      await prepareH2MacosStorageDirectory(tag, uid, restore: false);
      final marker = File('${root.path}/.h2-owner.json');
      await marker.delete();
      await expectLater(
        prepareH2MacosStorageDirectory(tag, uid, restore: true),
        throwsStateError,
      );
      for (final identity in [
        {'owner': 'foreign', 'runTag': tag, 'expectedUid': uid},
        {'owner': 'imboy-h2-c2c-v1', 'runTag': tag, 'expectedUid': '999'},
        {'owner': 'imboy-h2-c2c-v1', 'runTag': 'other', 'expectedUid': uid},
      ]) {
        await marker.writeAsString(jsonEncode(identity));
        await expectLater(
          prepareH2MacosStorageDirectory(tag, uid, restore: true),
          throwsStateError,
        );
      }
    });

    test('directory and marker symlinks cannot escape the scope', () async {
      final outside = await Directory.systemTemp.createTemp(
        'imboy-h2-sentinel-',
      );
      addTearDown(() => outside.delete(recursive: true));
      final sentinel = File('${outside.path}/sentinel');
      await sentinel.writeAsString('untouched');
      await Link(root.path).create(outside.path);
      await expectLater(
        prepareH2MacosStorageDirectory(tag, uid, restore: true),
        throwsStateError,
      );
      await Link(root.path).delete();
      await prepareH2MacosStorageDirectory(tag, uid, restore: false);
      final marker = File('${root.path}/.h2-owner.json');
      await marker.delete();
      await Link(marker.path).create(sentinel.path);
      await expectLater(
        prepareH2MacosStorageDirectory(tag, uid, restore: true),
        throwsStateError,
      );
      expect(await sentinel.readAsString(), 'untouched');
    });

    test('shared directory permissions cannot be restored', () async {
      await prepareH2MacosStorageDirectory(tag, uid, restore: false);
      expect((await Process.run('/bin/chmod', ['755', root.path])).exitCode, 0);
      await expectLater(
        prepareH2MacosStorageDirectory(tag, uid, restore: true),
        throwsStateError,
      );
    });
  });

  group('persistent Android directory preparation on host', () {
    late Directory support;
    late PathProviderPlatform originalPaths;
    late FlutterSecureStoragePlatform originalKeys;
    late _SupportPaths paths;
    const tag = 'ux-identity';
    const uid = '654321';
    setUp(() async {
      support = await Directory.systemTemp.createTemp('native-support-');
      originalPaths = PathProviderPlatform.instance;
      originalKeys = FlutterSecureStoragePlatform.instance;
      paths = _SupportPaths(support.path);
      PathProviderPlatform.instance = paths;
    });
    tearDown(() async {
      PathProviderPlatform.instance = originalPaths;
      FlutterSecureStoragePlatform.instance = originalKeys;
      SharedPreferences.resetStatic();
      // ignore: deprecated_member_use
      await databaseFactory.setDatabasesPath(Directory.systemTemp.path);
      await support.delete(recursive: true);
    });

    test(
      'support path is stable and restore preserves owned identity bytes',
      () async {
        final created = await prepareH2AndroidStorageDirectory(
          tag,
          uid,
          restore: false,
        );
        final canonical = await support.resolveSymbolicLinks();
        expect(created.path, '$canonical/imboy-h2-c2c-$tag-$uid');
        expect((await created.stat()).mode & 0x1ff, 0x1c0);
        expect(
          (await File('${created.path}/.h2-owner.json').stat()).mode & 0x1ff,
          0x180,
        );
        final identity = File('${created.path}/identity');
        await identity.writeAsString('synthetic-encrypted-identity');
        final restored = await prepareH2AndroidStorageDirectory(
          tag,
          uid,
          restore: true,
        );
        expect(restored.path, created.path);
        expect(await identity.readAsString(), 'synthetic-encrypted-identity');
        expect(paths.supportReads, 2);
        expect(PathProviderPlatform.instance, same(paths));
        expect(FlutterSecureStoragePlatform.instance, same(originalKeys));
        await expectLater(
          prepareH2AndroidStorageDirectory(tag, uid, restore: false),
          throwsStateError,
        );
        final other = await prepareH2AndroidStorageDirectory(
          tag,
          '654322',
          restore: false,
        );
        expect(other.path, isNot(created.path));
      },
    );

    test(
      'restore never creates a missing identity or accepts a foreign marker',
      () async {
        await expectLater(
          prepareH2AndroidStorageDirectory(tag, uid, restore: true),
          throwsStateError,
        );
        expect(await support.list().toList(), isEmpty);
        final created = await prepareH2AndroidStorageDirectory(
          tag,
          uid,
          restore: false,
        );
        await File('${created.path}/.h2-owner.json').writeAsString(
          jsonEncode({'owner': 'foreign', 'runTag': tag, 'expectedUid': uid}),
        );
        await expectLater(
          prepareH2AndroidStorageDirectory(tag, uid, restore: true),
          throwsStateError,
        );
      },
    );

    test(
      'unsafe identity is rejected before asking for any platform path',
      () async {
        for (final bad in ['', '../escape', 'a/b']) {
          await expectLater(
            prepareH2AndroidStorageDirectory(bad, uid, restore: false),
            throwsArgumentError,
          );
          await expectLater(
            prepareH2AndroidStorageDirectory(tag, bad, restore: false),
            throwsArgumentError,
          );
        }
        expect(paths.supportReads, 0);
        expect(await support.list().toList(), isEmpty);
      },
    );

    test('symlink and shared marker cannot be restored', () async {
      final created = await prepareH2AndroidStorageDirectory(
        tag,
        uid,
        restore: false,
      );
      final marker = File('${created.path}/.h2-owner.json');
      expect(
        (await Process.run('/bin/chmod', ['644', marker.path])).exitCode,
        0,
      );
      await expectLater(
        prepareH2AndroidStorageDirectory(tag, uid, restore: true),
        throwsStateError,
      );
      await marker.delete();
      final sentinel = File('${support.path}/sentinel')
        ..writeAsStringSync('untouched');
      await Link(marker.path).create(sentinel.path);
      await expectLater(
        prepareH2AndroidStorageDirectory(tag, uid, restore: true),
        throwsStateError,
      );
      expect(await sentinel.readAsString(), 'untouched');
    });

    test(
      'installed paths cannot recursively become a new Android support base',
      () async {
        if (!Platform.isMacOS) {
          await expectLater(
            isolateH2MacosStorage(tag, uid, restore: false),
            throwsStateError,
          );
          return;
        }
        final installed = await isolateMacosStorage();
        addTearDown(() => installed.delete(recursive: true));
        await expectLater(
          prepareH2AndroidStorageDirectory(tag, uid, restore: false),
          throwsStateError,
        );
        expect(await installed.list().toList(), isEmpty);
        expect(paths.supportReads, 0);
      },
    );

    test('macOS cleanup cannot remove an Android support identity', () async {
      final created = await prepareH2AndroidStorageDirectory(
        tag,
        uid,
        restore: false,
      );
      await expectLater(clearH2MacosStorage(tag, uid), throwsStateError);
      expect(await created.exists(), isTrue);
    });
  });

  test('restoring the same Android namespace preserves keys and excludes another UID', () async {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final spaces = <String, Map<String, String>>{};
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final options = Map<String, dynamic>.from(args['options'] as Map);
      final namespace = options['storageNamespace'] as String;
      expect(options['preferencesKeyPrefix'], namespace);
      final values = spaces.putIfAbsent(namespace, () => {});
      if (call.method == 'write') {
        values[args['key'] as String] = args['value'] as String;
        return null;
      }
      if (call.method == 'read') return values[args['key'] as String];
      throw StateError('Unexpected native identity operation');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    const namespace = 'imboy-enterprise-native-imboy-h2-c2c-ux-identity-654321';
    await androidScopedSecureStorage(namespace)
        .write(key: 'identity', value: 'synthetic-key', options: {});
    expect(
      await androidScopedSecureStorage(namespace)
          .read(key: 'identity', options: {}),
      'synthetic-key',
    );
    expect(
      await androidScopedSecureStorage('$namespace-other')
          .read(key: 'identity', options: {}),
      isNull,
    );
  });

  test('Android token cleanup stays in the native test namespace', () async {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final spaces = <String, Map<String, String>>{
      'original': {'token': 'original-token'},
    };
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final options = Map<String, dynamic>.from(args['options'] as Map);
      final namespace = options['storageNamespace'] as String;
      expect(namespace, 'imboy-enterprise-native-regression');
      final values = spaces.putIfAbsent(namespace, () => {});
      switch (call.method) {
        case 'write':
          values[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return values[args['key'] as String];
        case 'deleteAll':
          values.clear();
          return null;
        default:
          throw StateError('Unexpected storage operation');
      }
    });
    try {
      final scoped = androidScopedSecureStorage(
        'imboy-enterprise-native-regression',
      );
      await scoped.write(key: 'token', value: 'test-token', options: {});
      expect(await scoped.read(key: 'token', options: {}), 'test-token');
      await scoped.deleteAll(options: {});
      expect(await scoped.read(key: 'token', options: {}), isNull);
      expect(spaces['original'], {'token': 'original-token'});
      expect(calls.map((call) => call.method), [
        'write',
        'read',
        'deleteAll',
        'read',
      ]);
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
}

class _SupportPaths extends PathProviderPlatform {
  _SupportPaths(this.path);
  final String path;
  int supportReads = 0;
  @override
  Future<String?> getApplicationSupportPath() async {
    supportReads++;
    return path;
  }
}
