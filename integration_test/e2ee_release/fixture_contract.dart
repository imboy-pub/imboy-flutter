/// C11 合成 fixture contract —— AC-22/AC-23 测试账号/设备/群组的唯一命名规范。
///
/// 对齐 `imboy/docs/design/2026-10-03-e2ee-production-excellence/attack-matrix.md` §2：
/// - C2C 账号 `c11-c2c-{a|b}-{runTag}`
/// - C2G 账号 `c11-c2g-{a|b|c|d}-{runTag}`
/// - 设备 `{ownerAccount}-dev{n}`
/// - 群组 `c11-c2g-group-{runTag}`
/// - 消息 ID `c11msg-{scene}-{seq}`
/// - canary 沿用历史攻击矩阵 §1：`IMBOY-E2EE-<epoch>-<48hex>`，证据只留 SHA-256。
///
/// 禁止使用任何真实账号、设备序列号或脚本默认设备 ID；秘密由本地环境注入，不入仓。
library;

import 'dart:math';

/// runTag：每轮随机（小写字母数字，≤12 位），全 fixture 共享。
String generateRunTag([Random? random]) {
  final rnd = random ?? Random.secure();
  const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
  const length = 8;
  return List.generate(
    length,
    (_) => alphabet[rnd.nextInt(alphabet.length)],
  ).join();
}

bool isValidRunTag(String tag) => RegExp(r'^[a-z2-9]{1,12}$').hasMatch(tag);

/// 每轮临时生成唯一 canary；明文绝不写入证据/日志，只允许输出 SHA-256 与脱敏前缀。
/// 等价 shell：`IMBOY-E2EE-$(date +%s)-$(openssl rand -hex 24)`。
String generateCanary({DateTime? now, Random? random}) {
  final rnd = random ?? Random.secure();
  final epoch = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  final hex = List.generate(
    24,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return 'IMBOY-E2EE-$epoch-$hex';
}

/// 合成设备。`platform` 仅描述目标运行面，冒烟层（内存替身）不区分平台。
class SynthDevice {
  const SynthDevice({required this.deviceId, required this.platform});

  /// `{ownerAccount}-dev{n}`
  final String deviceId;

  /// android / ios / macos / host-simulated（冒烟层）
  final String platform;

  @override
  String toString() => 'SynthDevice($deviceId@$platform)';
}

/// 合成账号。
class SynthAccount {
  const SynthAccount({
    required this.uid,
    required this.role,
    required this.devices,
  });

  /// `c11-{c2c|c2g}-{role}-{runTag}`
  final String uid;
  final String role; // a/b（C2C）或 a/b/c/d（C2G）
  final List<SynthDevice> devices;

  @override
  String toString() => 'SynthAccount($uid)';
}

/// 合成群组。
class SynthGroup {
  const SynthGroup({required this.gid, required this.memberUids});

  /// `c11-c2g-group-{runTag}`
  final String gid;
  final List<String> memberUids;

  @override
  String toString() => 'SynthGroup($gid)';
}

/// 一轮旅程的全部合成 fixture。
class FixtureSet {
  const FixtureSet({
    required this.runTag,
    required this.accounts,
    required this.groups,
  });

  final String runTag;
  final List<SynthAccount> accounts;
  final List<SynthGroup> groups;

  /// AC-22 两账号基线：A/B 各一台设备（S06 时由调用方为 B 追加 dev2）。
  factory FixtureSet.c2c(String runTag) {
    assert(isValidRunTag(runTag), 'runTag 必须匹配 ^[a-z2-9]{1,12}\$');
    return FixtureSet(
      runTag: runTag,
      accounts: [
        SynthAccount(
          uid: 'c11-c2c-a-$runTag',
          role: 'a',
          devices: [
            SynthDevice(
              deviceId: 'c11-c2c-a-$runTag-dev1',
              platform: 'host-simulated',
            ),
          ],
        ),
        SynthAccount(
          uid: 'c11-c2c-b-$runTag',
          role: 'b',
          devices: [
            SynthDevice(
              deviceId: 'c11-c2c-b-$runTag-dev1',
              platform: 'host-simulated',
            ),
          ],
        ),
      ],
      groups: const [],
    );
  }

  /// AC-23 四账号 + 一个群基线。
  factory FixtureSet.c2g(String runTag) {
    assert(isValidRunTag(runTag), 'runTag 必须匹配 ^[a-z2-9]{1,12}\$');
    final accounts = ['a', 'b', 'c', 'd']
        .map(
          (role) => SynthAccount(
            uid: 'c11-c2g-$role-$runTag',
            role: role,
            devices: [
              SynthDevice(
                deviceId: 'c11-c2g-$role-$runTag-dev1',
                platform: 'host-simulated',
              ),
            ],
          ),
        )
        .toList(growable: false);
    return FixtureSet(
      runTag: runTag,
      accounts: accounts,
      groups: [
        SynthGroup(
          gid: 'c11-c2g-group-$runTag',
          memberUids: accounts.map((a) => a.uid).toList(growable: false),
        ),
      ],
    );
  }

  /// 场景消息 ID：`c11msg-{scene}-{seq}`（seq 4 位零填充）。
  String messageId(String scene, int seq) =>
      'c11msg-$scene-${seq.toString().padLeft(4, '0')}';

  /// 命名规范校验（冒烟自检用）：全部账号/设备/群 ID 必须匹配合同。
  List<String> validateNaming() {
    final violations = <String>[];
    final accountPattern = RegExp(r'^c11-c2[cg]-[abcd]-[a-z2-9]{1,12}$');
    final devicePattern = RegExp(
      r'^c11-c2[cg]-[abcd]-[a-z2-9]{1,12}-dev[0-9]+$',
    );
    final groupPattern = RegExp(r'^c11-c2g-group-[a-z2-9]{1,12}$');
    for (final account in accounts) {
      if (!accountPattern.hasMatch(account.uid)) {
        violations.add('account uid 命名违规: ${account.uid}');
      }
      for (final device in account.devices) {
        if (!devicePattern.hasMatch(device.deviceId) ||
            !device.deviceId.startsWith('${account.uid}-')) {
          violations.add('device id 命名违规: ${device.deviceId}');
        }
      }
    }
    for (final group in groups) {
      if (!groupPattern.hasMatch(group.gid)) {
        violations.add('group gid 命名违规: ${group.gid}');
      }
    }
    return violations;
  }

  /// 防真实标识混入：合同 fixture 里不允许出现历史脚本默认设备号等真实序列号。
  static const List<String> forbiddenRealIdentifiers = [
    // 历史脚本默认 Android 设备号（scripts/run_cross_platform_e2ee_interop.sh
    // 的 ANDROID_DEVICE_ID 默认值），仅作为「不得出现在合成 fixture」的样例锚点。
    'XWE6R19916004085',
  ];

  /// 扫描全部 fixture 字段中是否混入禁用的真实标识。
  List<String> scanForbiddenIdentifiers() {
    final blob = [
      for (final a in accounts) a.uid,
      for (final a in accounts)
        for (final d in a.devices) d.deviceId,
      for (final g in groups) g.gid,
    ].join('\n');
    return [
      for (final id in forbiddenRealIdentifiers)
        if (blob.contains(id)) 'fixture 混入真实标识: $id',
    ];
  }
}
