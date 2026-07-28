/// E2EE-062：fallback prekey 的**周期轮换决策**（纯函数）。
///
/// 缺口见 imboy `evidence/E2EE-062-fallback-rotation-assessment.md`：
/// `generateFallbackKey()` 此前只在登录时调用，**长期不登出的会话，其 fallback key
/// 永不被替换**。而 OTK 耗尽（整个 E2EE-062 系列处理的正是这件事）会把所有新会话
/// 逼到 fallback key 上——单把 key 的生命周期越长，其泄漏的爆炸半径越大。
library;

/// Olm/Matrix 生态的惯例周期。取 7 天而非更短，是因为轮换本身有成本
/// （一次上报 + 一次持久化），而威胁模型是"缩短暴露窗口"而非"每次都换"。
const Duration kFallbackRotationInterval = Duration(days: 7);

/// 是否该轮换 fallback key。
///
/// [lastRotatedAtMs] 为 `null` 表示**从未记录过**（新装、或本功能上线前的老账号）。
/// 此时**轮换**：换一把新 key 的代价只是一次上报，而旧 key 会被 vodozemac 保留、
/// 在途消息不受影响（已实证，见特征测试）；反过来"拿不准就不换"会让升级上来的
/// 老账号继续无限期沿用同一把 key，正是本项要消除的情形。
bool shouldRotateFallbackKey({
  required int? lastRotatedAtMs,
  required int nowMs,
  Duration interval = kFallbackRotationInterval,
}) {
  if (lastRotatedAtMs == null) return true;
  // 时间戳在未来：时钟回拨或数据损坏。判成"刚轮换过"会让该设备**永远**不再轮换，
  // 故一律当作该轮换——多换一次的代价只是一次上报。
  if (lastRotatedAtMs > nowMs) return true;
  return nowMs - lastRotatedAtMs >= interval.inMilliseconds;
}
