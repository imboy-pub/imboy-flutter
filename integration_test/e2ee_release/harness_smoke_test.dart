/// C11 E2EE release harness 冒烟自检（AC22-S01/S02 最小双端 C2C 往返）。
///
/// 运行（worktree 根目录）：
/// ```sh
/// FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR=<主仓>/imboyapp/spikes/e2ee-group/rust/target/release/ \
///   flutter test test/unit_test/service/e2ee_release_harness_host_test.dart --reporter expanded
/// ```
///
/// 防伪声明：本测试只证明冒烟 harness 自身可用（vodozemac 真实加解密、
/// 内存服务器替身、注入器、fixture 合同、旅程目录完整），**不构成
/// AC-22/AC-23 证据**；真实旅程需 REQUIRES_AUTHORIZED_BACKEND（attack-matrix.md §9）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'fixture_contract.dart';
import 'harness/backend_transport.dart';
import 'harness/malicious_proxy.dart';
import 'harness/simulated_device.dart';
import 'harness/vodozemac_loader.dart';
import 'journeys/c2c_journeys.dart';
import 'journeys/journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ensureVodozemacForHarness);

  test('fixture contract：命名规范与 canary 合同', () {
    final runTag = generateRunTag();
    expect(isValidRunTag(runTag), isTrue, reason: 'runTag: $runTag');
    expect(() => FixtureSet.c2c('BAD TAG'), throwsA(isA<AssertionError>()));

    for (final fixtures in [FixtureSet.c2c(runTag), FixtureSet.c2g(runTag)]) {
      expect(
        fixtures.validateNaming(),
        isEmpty,
        reason: '${fixtures.runtimeType} 命名违规',
      );
      expect(
        fixtures.scanForbiddenIdentifiers(),
        isEmpty,
        reason: '合成 fixture 不得混入真实标识',
      );
    }
    expect(FixtureSet.c2c(runTag).accounts, hasLength(2));
    expect(FixtureSet.c2g(runTag).accounts, hasLength(4));
    expect(FixtureSet.c2g(runTag).groups.single.memberUids, hasLength(4));
    expect(FixtureSet.c2c(runTag).messageId('s01', 3), 'c11msg-s01-0003');

    final canary = generateCanary();
    expect(canary, startsWith('IMBOY-E2EE-'));
    expect(
      RegExp(r'^IMBOY-E2EE-\d{10}-[0-9a-f]{48}$').hasMatch(canary),
      isTrue,
      reason: 'canary 格式须与历史矩阵 §1 一致: $canary',
    );
    expect(canary, isNot(equals(generateCanary())), reason: 'canary 每次唯一');
  });

  test('AC22-S01 冒烟：最小双端 C2C 真实加解密往返 + 服务端密文 oracle', () async {
    final fixtures = FixtureSet.c2c(generateRunTag());
    final canary = generateCanary();
    final transport = InMemoryReleaseTransport();
    await transport.start();
    final alice = SimulatedDevice(
      account: fixtures.accounts.first,
      device: fixtures.accounts.first.devices.first,
    );
    final bob = SimulatedDevice(
      account: fixtures.accounts.last,
      device: fixtures.accounts.last.devices.first,
    );
    await transport.connectDevice(alice.device);
    await transport.connectDevice(bob.device);
    SimulatedDevice.establishSession(alice, bob);

    final plaintext = 'hello-from-${alice.uid}-$canary';
    final frame = alice.sendProtectedText(
      messageId: fixtures.messageId('s01', 1),
      plaintext: plaintext,
      peer: bob,
    );
    // 帧内不得出现明文（发送侧防泄漏）。
    expect(frame.body.toString(), isNot(contains(canary)));

    final receipt = await transport.send(frame);
    expect(receipt, DeliveryReceipt.accepted);
    final outcome = bob.receiveFrame(transport.drainInbox(bob.deviceId).single);
    expect(outcome.status, ReceiveStatus.ok);
    expect(outcome.plaintext, plaintext);

    // 设备显示 oracle：B 端显示 == 发送文本，且标记已验证。
    final display = bob.displayInbox.single;
    expect(display.text, plaintext);
    expect(display.verified, isTrue);

    // 服务端密文 oracle：持久化面 + 日志面 canary 0 命中；存储行与消息一一对应。
    expect(transport.scanPlaintextSurfaces(canary), isEmpty);
    expect(
      transport.durableStore.single.messageId,
      fixtures.messageId('s01', 1),
    );
    expect(transport.durableStore.single.bodyJson, isNot(contains(canary)));
    await transport.dispose();
  });

  test('AC22-S02 冒烟：B→A 反向回复（双向 ratchet 往返）', () async {
    final fixtures = FixtureSet.c2c(generateRunTag());
    final canary = generateCanary();
    final transport = InMemoryReleaseTransport();
    await transport.start();
    final alice = SimulatedDevice(
      account: fixtures.accounts.first,
      device: fixtures.accounts.first.devices.first,
    );
    final bob = SimulatedDevice(
      account: fixtures.accounts.last,
      device: fixtures.accounts.last.devices.first,
    );
    await transport.connectDevice(alice.device);
    await transport.connectDevice(bob.device);
    SimulatedDevice.establishSession(alice, bob);

    // A -> B
    final first = alice.sendProtectedText(
      messageId: fixtures.messageId('s02', 1),
      plaintext: 'ping-$canary',
      peer: bob,
    );
    await transport.send(first);
    bob.receiveFrame(transport.drainInbox(bob.deviceId).single);

    // B -> A（inbound session 转为发送方向）
    final reply = bob.sendProtectedText(
      messageId: fixtures.messageId('s02', 2),
      plaintext: 'pong-$canary',
      peer: alice,
    );
    await transport.send(reply);
    final outcome = alice.receiveFrame(
      transport.drainInbox(alice.deviceId).single,
    );
    expect(outcome.status, ReceiveStatus.ok);
    expect(outcome.plaintext, 'pong-$canary');
    expect(transport.scanPlaintextSurfaces(canary), isEmpty);
    expect(transport.durableStore, hasLength(2));
    await transport.dispose();
  });

  test('AC22-M01 冒烟：replay 注入 -> 去重且 UI 不重复推进', () async {
    final fixtures = FixtureSet.c2c(generateRunTag());
    final transport = InMemoryReleaseTransport();
    await transport.start();
    final alice = _device(fixtures.accounts.first);
    final bob = _device(fixtures.accounts.last);
    await transport.connectDevice(bob.device);
    SimulatedDevice.establishSession(alice, bob);

    final frame = alice.sendProtectedText(
      messageId: fixtures.messageId('m01', 1),
      plaintext: 'replay-target-${generateCanary()}',
      peer: bob,
    );
    await transport.send(frame);
    final first = transport.drainInbox(bob.deviceId).single;
    // W1 注入：同一帧投递两次。
    for (final injected in MaliciousProxy.replay(first)) {
      bob.receiveFrame(injected);
    }
    expect(bob.displayInbox, hasLength(1), reason: '重复帧不得重复推进 UI');
    expect(bob.displayInbox.single.verified, isTrue);
    await transport.dispose();
  });

  test('AC22-M03 冒烟：篡改/洪泛注入 -> fail-closed 失败占位', () async {
    final fixtures = FixtureSet.c2c(generateRunTag());
    final transport = InMemoryReleaseTransport();
    await transport.start();
    final alice = _device(fixtures.accounts.first);
    final bob = _device(fixtures.accounts.last);
    await transport.connectDevice(bob.device);
    SimulatedDevice.establishSession(alice, bob);

    final frame = alice.sendProtectedText(
      messageId: fixtures.messageId('m03', 1),
      plaintext: 'tamper-target-${generateCanary()}',
      peer: bob,
    );
    await transport.send(frame);
    final delivered = transport.drainInbox(bob.deviceId).single;

    // 密文篡改：Olm 认证失败，不显示乱码。
    final tampered = MaliciousProxy.tamperCiphertext(delivered);
    final tamperedOutcome = bob.receiveFrame(tampered);
    expect(tamperedOutcome.status, ReceiveStatus.rejected);
    final tamperedEntry = bob.displayInbox.last;
    expect(tamperedEntry.verified, isFalse);
    expect(tamperedEntry.text, '[e2ee-failed]');
    expect(tamperedEntry.failedReason, isNotNull);

    // 同 ID 换密文再次投递：message_id 去重挡住（幂等，不重复上屏）。
    final swappedCiphertext = MaliciousProxy.tamperCiphertext(delivered);
    expect(
      bob.receiveFrame(swappedCiphertext).status,
      ReceiveStatus.duplicate,
      reason: '同 ID 换密文必须先被去重拦截，不得重复推进 UI',
    );

    // 信封篡改（换投递 ID，模拟「同密文换 ID」路径）：PFv3 hash 校验失败。
    final headerTampered = MaliciousProxy.tamperHeader(
      delivered.copyWith(messageId: '${delivered.messageId}-hdr'),
    );
    final headerOutcome = bob.receiveFrame(headerTampered);
    expect(headerOutcome.status, ReceiveStatus.rejected);
    expect(headerOutcome.reason, contains('hash'));

    // 洪泛：垃圾帧全部拒绝且设备不崩溃。
    for (final junk in MaliciousProxy.flood(delivered, 32)) {
      final outcome = bob.receiveFrame(junk);
      expect(outcome.status, ReceiveStatus.rejected);
    }
    expect(
      bob.displayInbox.where((e) => e.verified).toList(),
      isEmpty,
      reason: '全部攻击帧均不得上屏为已验证内容',
    );
    await transport.dispose();
  });

  test('AC22-M04 冒烟：身份目录替换 -> 握手 fail-closed，无法建立可信会话', () {
    final fixtures = FixtureSet.c2c(generateRunTag());
    final alice = _device(fixtures.accounts.first);
    final bob = _device(fixtures.accounts.last);

    // W2 注入：目录返回攻击者身份键。
    expect(
      () => SimulatedDevice.establishSession(
        alice,
        bob,
        directoryIdentityOverride: MaliciousProxy.swapDirectoryIdentity,
      ),
      throwsA(anything),
      reason: '目录身份被替换时，pre-key 握手必须失败，不得建立会话',
    );
    expect(alice.hasSessionWith(bob.deviceId), isFalse);
    expect(bob.hasSessionWith(alice.deviceId), isFalse);
  });

  test('AC22-S04 冒烟：离线存储 + 重连补投（内存替身离线能力）', () async {
    final fixtures = FixtureSet.c2c(generateRunTag());
    final transport = InMemoryReleaseTransport();
    await transport.start();
    final alice = _device(fixtures.accounts.first);
    final bob = _device(fixtures.accounts.last);
    await transport.connectDevice(alice.device);
    // B 离线。
    await transport.connectDevice(bob.device);
    await transport.disconnectDevice(bob.device);
    SimulatedDevice.establishSession(alice, bob);

    for (var i = 1; i <= 3; i++) {
      final frame = alice.sendProtectedText(
        messageId: fixtures.messageId('s04', i),
        plaintext: 'offline-$i-${generateCanary()}',
        peer: bob,
      );
      final receipt = await transport.send(frame);
      expect(receipt, DeliveryReceipt.recipientOffline);
    }
    expect(bob.displayInbox, isEmpty);

    // B 重连：backlog 按序补投且各只一次。
    await transport.connectDevice(bob.device);
    final flushed = transport.flushBacklogFor(bob.deviceId);
    expect(flushed, 3);
    final frames = transport.drainInbox(bob.deviceId);
    expect(frames, hasLength(3));
    for (final frame in frames) {
      expect(bob.receiveFrame(frame).status, ReceiveStatus.ok);
    }
    expect(bob.displayInbox, hasLength(3));
    expect(transport.flushBacklogFor(bob.deviceId), 0, reason: 'backlog 幂等');
    await transport.dispose();
  });

  test('真实后端层 stub：未授权实现必须显式拒绝（REQUIRES_AUTHORIZED_BACKEND）', () {
    expect(
      () => RealBackendTransport(),
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains(requiresAuthorizedBackendTag),
        ),
      ),
    );
  });

  test('旅程目录完整性与 attack-matrix.md 场景一一对齐', () {
    final all = JourneyCatalog.all();
    final ids = all.map((j) => j.id).toSet();
    final expected = <String>{
      for (var i = 1; i <= 6; i++) ...{'AC22-S${i.toString().padLeft(2, '0')}'},
      for (var i = 1; i <= 5; i++) ...{'AC22-M${i.toString().padLeft(2, '0')}'},
      for (var i = 1; i <= 6; i++) ...{'AC23-G${i.toString().padLeft(2, '0')}'},
      for (var i = 1; i <= 5; i++) ...{'AC23-M${i.toString().padLeft(2, '0')}'},
    };
    expect(ids, expected, reason: '场景 ID 集合必须与矩阵 §4/§4.1/§6/§6.1 一致');
    expect(all, hasLength(expected.length));
    expect(ids.lookup('AC22-S01'), isNotNull);

    for (final journey in all) {
      expect(journey.steps, isNotEmpty, reason: '${journey.id} 必须有操作步骤');
      expect(journey.deviceOracle, isNotEmpty);
      expect(journey.serverOracle, isNotEmpty);
      expect(journey.passCondition, isNotEmpty);
      expect(journey.fixtures, isNotEmpty);
      expect(journey.acId, journey.id.startsWith('AC22') ? 'AC-22' : 'AC-23');
      expect(
        journey.requiresAuthorizedBackend,
        isTrue,
        reason: '${journey.id} 验收层必须显式声明 REQUIRES_AUTHORIZED_BACKEND',
      );
    }

    // 冒烟可自检的 C2C 子集声明与 harness 实际覆盖一致。
    expect(c2cSmokeEligibleIds.toSet().difference(ids), isEmpty);
    expect(c2cSmokeEligibleIds, containsAll(<String>['AC22-S01', 'AC22-S02']));
  });
}

SimulatedDevice _device(SynthAccount account) =>
    SimulatedDevice(account: account, device: account.devices.first);
