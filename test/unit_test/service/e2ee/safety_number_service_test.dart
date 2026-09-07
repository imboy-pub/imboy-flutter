import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/safety_number_service.dart';

void main() {
  const identities = <String, String>{
    '100:a-1': 'YS0xLWlkZW50aXR5',
    '100:a-2': 'YS0yLWlkZW50aXR5',
    '200:b-1': 'Yi0xLWlkZW50aXR5',
    '200:b-2': 'Yi0yLWlkZW50aXR5',
  };

  List<Map<String, dynamic>> devices(String uid) => switch (uid) {
    '100' => [
      {'device_id': 'a-2', 'key_id': 'kid-a-2'},
      {'device_id': 'a-1', 'key_id': 'kid-a-1'},
    ],
    '200' => [
      {'device_id': 'b-2', 'key_id': 'kid-b-2'},
      {'device_id': 'b-1', 'key_id': 'kid-b-1'},
    ],
    _ => [],
  };

  Future<String> verifiedIdentity(String uid, String did) async =>
      identities['$uid:$did']!;

  test('双方使用真实 device_id 与全部 Olm identity，聚合安全码对称', () async {
    final fromA = await SafetyNumberService.generateForPeer(
      peerUid: '200',
      localUidOverride: '100',
      localDeviceIdOverride: 'a-1',
      deviceListLoader: (uid) async => devices(uid),
      localIdentityLoader: () async => identities['100:a-1']!,
      verifiedIdentityLoader: verifiedIdentity,
    );
    final fromB = await SafetyNumberService.generateForPeer(
      peerUid: '100',
      localUidOverride: '200',
      localDeviceIdOverride: 'b-1',
      deviceListLoader: (uid) async => devices(uid),
      localIdentityLoader: () async => identities['200:b-1']!,
      verifiedIdentityLoader: verifiedIdentity,
    );

    expect(fromA.number, fromB.number);
    expect(fromA.localDeviceCount, 2);
    expect(fromA.remoteDeviceCount, 2);
    expect(fromA.remoteDeviceId, 'b-1');
    expect(fromB.remoteDeviceId, 'a-1');
    expect(fromA.remoteDeviceId, isNot(startsWith('kid-')));
  });

  test('本机当前 device_id 未出现在权威活跃设备清单时 fail-closed', () async {
    await expectLater(
      SafetyNumberService.generateForPeer(
        peerUid: '200',
        localUidOverride: '100',
        localDeviceIdOverride: 'a-revoked',
        deviceListLoader: (uid) async => devices(uid),
        localIdentityLoader: () async => identities['100:a-1']!,
        verifiedIdentityLoader: verifiedIdentity,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'local_device_not_registered',
        ),
      ),
    );
  });

  test('设备集合变化会改变安全码，旧验证值随即失效', () async {
    final original = await SafetyNumberService.generateForPeer(
      peerUid: '200',
      localUidOverride: '100',
      localDeviceIdOverride: 'a-1',
      deviceListLoader: (uid) async => devices(uid),
      localIdentityLoader: () async => identities['100:a-1']!,
      verifiedIdentityLoader: verifiedIdentity,
    );
    final changed = await SafetyNumberService.generateForPeer(
      peerUid: '200',
      localUidOverride: '100',
      localDeviceIdOverride: 'a-1',
      deviceListLoader: (uid) async => uid == '200'
          ? [
              ...devices(uid),
              {'device_id': 'b-3', 'key_id': 'kid-b-3'},
            ]
          : devices(uid),
      localIdentityLoader: () async => identities['100:a-1']!,
      verifiedIdentityLoader: (uid, did) async =>
          did == 'b-3' ? 'Yi0zLWlkZW50aXR5' : verifiedIdentity(uid, did),
    );

    expect(changed.number, isNot(original.number));
    expect(
      SafetyNumberService.isCurrentNumberVerified(
        original.number,
        changed.number,
      ),
      isFalse,
    );
    expect(
      SafetyNumberService.isCurrentNumberVerified(
        changed.number,
        changed.number,
      ),
      isTrue,
    );
    expect(
      SafetyNumberService.isCurrentNumberVerified(
        '2026-09-07T10:00:00.000Z',
        changed.number,
      ),
      isFalse,
      reason: '旧版时间戳不得继续代表当前 identity 集合已验证',
    );
  });
}
