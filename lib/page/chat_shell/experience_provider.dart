/// T2 (WP1) — Product Experience 消费层
///
/// 链路（计划 §4.1，服务端唯一真相源）：
///
/// ```text
/// 服务端安装级 IMBOY_PRODUCT_EXPERIENCE
///   → /api/v1/init 下发 { effective_product_experience, config_version }
///   → initConfig（config/init.dart）解密后写入 StorageService 缓存
///   → 本 provider 读取缓存
///   → 路由与壳（ChatShellBootstrap）只消费该值
/// ```
///
/// 兼容规则（fail-safe，与后端 T1 约定一致）：
/// - 字段缺失（T1 未就绪 / 旧后端）、值为空、未知值、离线无缓存
///   → 一律按 [ProductExperience.chat] 渲染；
/// - 旧客户端继续按 chat；
/// - 切换语义为安装级：修改服务端配置 + 受控重启后 `config_version` 变化，
///   客户端下次启动时 initConfig 覆盖缓存，本 provider 随新 ProviderContainer
///   生效（App 生命周期内该值视为不变，不做运行时热切换）。
///
/// 镜像 `config/env.dart` `publicBaseUrl` 的「服务端下发 → StorageService
/// 缓存 → 内置默认回落」三段式。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';

/// /api/v1/init 下发的 experience 字段名（与后端 T1 约定一致）。
const String kEffectiveProductExperienceField = 'effective_product_experience';

/// 产品体验枚举。
///
/// - [chat]：现有 IM 聊天体验（ChatShell，T2 现状包壳）
/// - [workspace]：工作区体验（WorkspaceShell，WP5/T8 的扩展点，
///   本期仅保留枚举值，不包含任何 workspace UI）
enum ProductExperience {
  /// 聊天体验：移动端底部导航 + 桌面端三栏壳（现状）
  chat('chat'),

  /// 工作区体验：WP5 (T8) WorkspaceShell 落地后启用
  workspace('workspace');

  /// 与服务端 /api/v1/init 传输的 wire 值。
  final String wireName;

  const ProductExperience(this.wireName);
}

/// 解析服务端下发的原始 experience 字符串。
///
/// fail-safe：仅显式识别 `workspace`；`null`、空串、未知值一律降级
/// [ProductExperience.chat]（§4.1「缺字段/未知值/离线无缓存时按 chat 渲染」）。
ProductExperience parseProductExperience(String? raw) {
  if (raw == ProductExperience.workspace.wireName) {
    return ProductExperience.workspace;
  }
  return ProductExperience.chat;
}

/// 从 /api/v1/init 解密后的 payload 解析 experience（T1 未就绪时字段缺失
/// → chat）。
///
/// 独立为纯函数以便单测固化「字段缺失降级」契约；运行时主链路走
/// StorageService 缓存（[readCachedProductExperience]），本函数供
/// initConfig 接线期与测试消费。
ProductExperience resolveProductExperienceFromPayload(
  Map<String, dynamic>? payload,
) {
  if (payload == null) return ProductExperience.chat;
  final dynamic raw = payload[kEffectiveProductExperienceField];
  return parseProductExperience(raw is String ? raw : null);
}

/// 同步读取 StorageService 缓存的 experience（服务端优先 + 本地缓存 +
/// 离线回落 chat）。
///
/// 缓存由 initConfig 在每次启动拉取 /api/v1/init 后覆盖写入；离线无缓存
/// 时 getString 返回空串 → [parseProductExperience] 降级 chat。
ProductExperience readCachedProductExperience() {
  return parseProductExperience(
    StorageService.to.getString(Keys.effectiveProductExperience),
  );
}

/// 当前生效的产品体验（App 生命周期内不变，安装级配置）。
///
/// 消费方：ChatShellBootstrap（experience=chat → ChatShell）。路由与
/// Provider 只消费该值，不得自行读取原始字符串（唯一真相源收敛）。
final Provider<ProductExperience> productExperienceProvider =
    Provider<ProductExperience>((ref) => readCachedProductExperience());
