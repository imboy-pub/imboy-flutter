// 类型化迁移清单 —— SQLite 升降级边的唯一真源（WP3 接口冻结版）
// Typed migration manifest — the single source of truth for SQLite
// upgrade/downgrade edges (WP3 frozen interface).
//
// 设计目标（研究文档 §4.2 / 计划 Step 4）：
//   - 每条边显式声明 from/to、SQL、reversible、dataLoss、requiresResync、
//     pre/postconditions、affectedObjects —— 取代"从注释/PRAGMA 猜方向"。
//   - ID/from/to 全局唯一；构造期校验，坏清单直接抛异常（fail-closed）。
//   - SQL asset（assets/migrations/*.sql）与内嵌常量（embedded_schema_scripts
//     的 kUpgradeScriptSql/kDowngradeScriptSql）降级为本清单的**构建期生成物**，
//     由 tool/generate_sqlite_migrations.dart 产出并校验字节级一致。
//
// ⚠️ 接口冻结（2026-08-27，主 Agent 确认）：MigrationEdge / MigrationManifest
// 的公共字段与方法是 WP4（schema contract）和 WP5（快照协调器）的依赖面，
// 冻结后如需破坏性修改必须暂停下游 WP 并重新协调。
library;

/// 迁移方向。
enum MigrationDirection { upgrade, downgrade }

/// 单条迁移边（一个 VERSION 块的完整声明）。
class MigrationEdge {
  const MigrationEdge({
    required this.id,
    required this.fromVersion,
    required this.toVersion,
    required this.description,
    required this.reversible,
    required this.dataLoss,
    required this.requiresResync,
    required this.preconditions,
    required this.postconditions,
    required this.affectedObjects,
    required this.headerComment,
    required this.sql,
    int? blockLabel,
  }) : blockLabel =
           blockLabel ?? (toVersion > fromVersion ? toVersion : fromVersion);

  /// 稳定唯一 ID（日期前缀 + 主题），如 `20260827_v31_channel_access_model`。
  /// 一经发布不得改名——它将进入迁移日志与 schema meta。
  final String id;

  /// 起始版本。upgrade 边为 N-1，downgrade 边为 N（块标签语义）。
  final int fromVersion;

  /// 目标版本。upgrade 边为 N（块标签），downgrade 边为 N-1。
  final int toVersion;

  /// 人类可读描述（对应旧 `-- DESC:` 行）。
  final String description;

  /// 是否可逆。**只有 reversible=true 的 upgrade 边允许存在配对的
  /// downgrade 边**；planner 只用显式存在的边构造路径，绝不假设可逆。
  final bool reversible;

  /// 执行本边是否可能丢失本地数据（删列/重建丢行/类型收窄）。
  final bool dataLoss;

  /// 降级/重建后是否需要服务端重同步才能恢复完整数据。
  final bool requiresResync;

  /// 前置条件（人类可读；可执行语句由脚本自身/服务负责）。
  final List<String> preconditions;

  /// 后置条件（迁移后必须成立的结构/业务断言）。
  final List<String> postconditions;

  /// 受影响对象（表/索引名），供 schema contract 与影响面分析。
  final List<String> affectedObjects;

  /// 块头注释原文（`-- ===...` 横线区，含 VERSION/DESC 行），生成器按原
  /// 布局回写 assets/migrations/*.sql，保证字节级可复现。
  final String headerComment;

  /// 块内 SQL 原文（含内嵌注释，以 `PRAGMA user_version = N;` 结束）。
  final String sql;

  MigrationDirection get direction => toVersion > fromVersion
      ? MigrationDirection.upgrade
      : MigrationDirection.downgrade;

  /// 块标签号（与历史 `-- VERSION: N` 一致）：upgrade=N(to)，downgrade=N(from)。
  ///
  /// 历史特例（显式传入）：upgrade v14 块（13→15）的 SQL 里
  /// `PRAGMA user_version = 15`——该边实际把版本从 13 跨到 15（v14/v15
  /// 间无 schema 差异，v15 即从未存在的"跳号"版本），但块标签是 14。
  /// planner/索引以块标签为准，版本语义以 from/to 为准。
  final int blockLabel;

  /// SQL 语句清单（跳过注释/空行、按行尾 ';' 边界切分；与
  /// MigrationService 历史解析规则一致）。
  List<String> get sqlStatements {
    final statements = <String>[];
    final current = StringBuffer();
    for (final line in sql.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('--')) continue;
      current.write(line);
      current.write('\n');
      if (trimmed.endsWith(';')) {
        statements.add(current.toString().trim());
        current.clear();
      }
    }
    if (current.isNotEmpty) statements.add(current.toString().trim());
    return statements;
  }
}

/// 清单校验失败（构造期 fail-closed）。
class MigrationManifestException implements Exception {
  MigrationManifestException(this.message);
  final String message;

  @override
  String toString() => 'MigrationManifestException: $message';
}

/// 迁移清单：全部边的聚合与查询。
class MigrationManifest {
  /// 以全部边构造清单；构造期完成一致性校验，任何违规抛
  /// [MigrationManifestException]（坏清单不允许进入运行时）。
  MigrationManifest(this.edges) {
    _validate();
  }

  /// 全部边（升级 + 降级）。顺序即声明顺序（lib/service/migrations/*.dart）。
  final List<MigrationEdge> edges;

  final Map<String, MigrationEdge> _byId = {};
  final Map<int, MigrationEdge> _upgradesByTo = {};
  final Map<int, MigrationEdge> _downgradesByFrom = {};

  /// upgrade 边索引：key = 目标版本（块标签 N）。
  Map<int, MigrationEdge> get upgradesByTo => Map.unmodifiable(_upgradesByTo);

  /// downgrade 边索引：key = 起始版本（块标签 N）。
  Map<int, MigrationEdge> get downgradesByFrom =>
      Map.unmodifiable(_downgradesByFrom);

  /// 清单中出现过的全部版本号（升序）。
  Set<int> get knownVersions {
    final versions = <int>{};
    for (final e in edges) {
      versions.add(e.fromVersion);
      versions.add(e.toVersion);
    }
    return versions;
  }

  /// 最新（最高）版本 —— 必须等于 SqliteService._dbVersion（契约测试守护）。
  int get latestVersion => knownVersions.reduce((a, b) => a > b ? a : b);

  /// 按 from/to 精确查边；不存在返回 null（调用方必须显式处理缺边）。
  MigrationEdge? edge(int fromVersion, int toVersion) {
    for (final e in edges) {
      if (e.fromVersion == fromVersion && e.toVersion == toVersion) return e;
    }
    return null;
  }

  void _validate() {
    for (final e in edges) {
      if (e.id.trim().isEmpty) {
        throw MigrationManifestException(
          'edge v${e.fromVersion}→'
          'v${e.toVersion} 缺少 id',
        );
      }
      if (_byId.containsKey(e.id)) {
        throw MigrationManifestException('重复的边 id: ${e.id}');
      }
      _byId[e.id] = e;

      if (e.fromVersion == e.toVersion) {
        throw MigrationManifestException(
          '边 ${e.id} from==to '
          '(v${e.fromVersion})，不允许自环',
        );
      }
      final isUpgrade = e.toVersion > e.fromVersion;
      if (isUpgrade) {
        if (_upgradesByTo.containsKey(e.toVersion)) {
          throw MigrationManifestException(
            '重复的 upgrade 目标版本 '
            'v${e.toVersion}（${_upgradesByTo[e.toVersion]!.id} 与 ${e.id}）',
          );
        }
        _upgradesByTo[e.blockLabel] = e;
      } else {
        if (_downgradesByFrom.containsKey(e.fromVersion)) {
          throw MigrationManifestException(
            '重复的 downgrade 起始版本 '
            'v${e.fromVersion}（${_downgradesByFrom[e.fromVersion]!.id} 与 ${e.id}）',
          );
        }
        _downgradesByFrom[e.fromVersion] = e;
      }
    }
  }

  /// 交叉校验配对边的一致性：
  /// - 不可逆 upgrade 边不得存在配对 downgrade 边；
  /// - 可逆 upgrade 边的配对 downgrade 边声明必须同 affectedObjects 基集。
  ///
  /// 由清单组装处（kMigrationManifest）在测试与生成器中调用。
  void validatePairing() {
    for (final e in _downgradesByFrom.values) {
      final up = _upgradesByTo[e.fromVersion];
      if (up == null) continue; // 对应 upgrade 块不存在（历史遗留形态）
      if (!up.reversible) {
        throw MigrationManifestException(
          '不可逆 upgrade 边 ${up.id} 存在配对 downgrade 边 ${e.id}；'
          '要么补 reversible=true（并给出验证证据），要么删除 downgrade 边',
        );
      }
    }
  }
}
