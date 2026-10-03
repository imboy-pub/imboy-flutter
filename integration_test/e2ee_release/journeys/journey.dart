/// C11 旅程（journey）定义类型：attack-matrix.md 场景在代码侧的唯一登记。
///
/// 每个 [JourneyDefinition] 与 attack-matrix.md §4/§4.1/§6/§6.1 的一个场景 ID
/// 一一对应；[JourneyCatalog.all] 是权威全集，冒烟自检会断言它与矩阵文档同步。
library;

import 'c2c_journeys.dart';
import 'c2g_journeys.dart';

/// 旅程执行层。
enum JourneyLayer {
  /// 冒烟层：内存替身可离线运行（仅 harness 自检，非 AC 证据）。
  smoke,

  /// 真实层：需要授权后端 + 真机（REQUIRES_AUTHORIZED_BACKEND）。
  realBackend,
}

class JourneyDefinition {
  const JourneyDefinition({
    required this.id,
    required this.acId,
    required this.title,
    required this.layer,
    required this.fixtures,
    required this.steps,
    required this.deviceOracle,
    required this.serverOracle,
    required this.passCondition,
  });

  /// 场景 ID，如 `AC22-S01` / `AC22-M03` / `AC23-G02` / `AC23-M01`。
  final String id;

  /// 所属验收 ID：`AC-22` 或 `AC-23`。
  final String acId;

  final String title;
  final JourneyLayer layer;

  /// 前置 fixture 描述（attack-matrix.md 各表「前置 fixture」列）。
  final String fixtures;

  /// 攻击/操作步骤（attack-matrix.md 各表「操作」列）。
  final List<String> steps;

  /// 设备显示 oracle 断言口径。
  final String deviceOracle;

  /// 服务端密文 oracle 断言口径。
  final String serverOracle;

  /// PASS 条件。
  final String passCondition;

  bool get requiresAuthorizedBackend => layer == JourneyLayer.realBackend;
}

class JourneyCatalog {
  const JourneyCatalog._();

  /// AC-22 全部场景（§4 + §4.1）。
  static List<JourneyDefinition> c2c() => c2cJourneys;

  /// AC-23 全部场景（§6 + §6.1）。
  static List<JourneyDefinition> c2g() => c2gJourneys;

  static List<JourneyDefinition> all() => <JourneyDefinition>[
    ...c2cJourneys,
    ...c2gJourneys,
  ];
}
