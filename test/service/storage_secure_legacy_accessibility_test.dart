import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/storage_secure.dart';

/// 回归：Keychain accessibility 从默认 `unlocked` 改为 `first_unlock` 后，
/// 旧条目对新查询不可见（read 返回 null / write 撞 -25299 errSecDuplicateItem）。
void main() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;

  String accessibilityOf(MethodCall call) =>
      ((call.arguments as Map)['options'] as Map)['accessibility'] as String;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = <MethodCall>[];
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('write 遇 errSecDuplicateItem 时先删旧条目再重写', () async {
    var writeCount = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'write' && ++writeCount == 1) {
        throw PlatformException(
          code: 'Unexpected security result code',
          message: 'Code: -25299',
          details: -25299,
        );
      }
      return null;
    });

    await StorageSecureService.to.write(key: 'upload_key', value: 'v2');

    expect(calls.map((c) => c.method).toList(), ['write', 'delete', 'write']);
    expect((calls.last.arguments as Map)['value'], 'v2');
  });

  test('write 遇其他 Keychain 错误时原样抛出', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(
        code: 'Unexpected security result code',
        message: 'Code: -34018',
        details: -34018,
      );
    });

    await expectLater(
      StorageSecureService.to.write(key: 'upload_key', value: 'v2'),
      throwsA(isA<PlatformException>()),
    );
    expect(calls.map((c) => c.method).toList(), ['write']);
  });

  test(
    'delete 遇 errSecMissingEntitlement 时不抛（macOS 无 Keychain entitlement）',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        throw PlatformException(
          code: 'Unexpected security result code',
          message: "A required entitlement isn't present.",
          details: -34018,
        );
      });

      await StorageSecureService.to.delete(key: 'olm_account_pickle');
      expect(calls.map((c) => c.method).toList(), ['delete']);
    },
  );

  test('delete 遇其他 Keychain 错误时原样抛出', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(
        code: 'Unexpected security result code',
        message: 'Code: -25300',
        details: -25300,
      );
    });

    await expectLater(
      StorageSecureService.to.delete(key: 'olm_account_pickle'),
      throwsA(isA<PlatformException>()),
    );
  });

  test('read 回落到旧 accessibility 并把命中值搬迁到新 accessibility', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'read') {
        return accessibilityOf(call) == 'unlocked' ? 'legacy-secret' : null;
      }
      return null;
    });

    final value = await StorageSecureService.to.read(key: 'e2ee_private_key');

    expect(value, 'legacy-secret');
    expect(calls.map((c) => c.method).toList(), ['read', 'read', 'write']);
    expect(accessibilityOf(calls[0]), 'first_unlock');
    expect(accessibilityOf(calls[1]), 'unlocked');
    expect(accessibilityOf(calls[2]), 'first_unlock');
    expect((calls[2].arguments as Map)['value'], 'legacy-secret');
  });

  test('read 命中当前 accessibility 时不触发回落', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'read' ? 'current' : null;
    });

    expect(await StorageSecureService.to.read(key: 'k'), 'current');
    expect(calls.length, 1);
  });

  test('readAll 合并旧 accessibility 条目，当前值优先', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method != 'readAll') return null;
      return accessibilityOf(call) == 'unlocked'
          ? <Object?, Object?>{'e2ee_private_key': 'legacy', 'old_only': 'x'}
          : <Object?, Object?>{'e2ee_private_key': 'current'};
    });

    expect(await StorageSecureService.to.readAll(), {
      'e2ee_private_key': 'current',
      'old_only': 'x',
    });
  });
}
