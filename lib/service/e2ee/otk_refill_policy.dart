/// E2EE-062：one-time prekey 池的**补传决策**（纯函数）。
///
/// 服务端的目标级限流（imboy `evidence/E2EE-062-per-task-throttle.md`）建立在
/// 一条取舍上：「限流只拖慢、靠补传恢复」。补传要成立，客户端必须能拿到**真实**
/// 余量。在此之前 `OlmApi.countPrekeys` 是恒返回 0 的桩实现，于是每次调用都判定
/// 为低水位、每次都全量重发——`report_one_time_keys` 是**全量替换式**（先删后插），
/// 等于每次入站建会话都把整个 OTK 池推倒重来。
///
/// 本函数把「该不该补、补多少」从副作用里摘出来，使其可直接验收。
/// 返回本次应生成并上报的 OTK 数量；`0` = 不补。
///
/// - [seed]：首次注册。池必然为空，**不依赖查询**直接铺满——否则一次查询失败
///   就会让新设备永远没有 OTK，所有对端只能退到同一条 fallback prekey。
/// - [remaining] 为 `null` 表示**未知**（查询失败），此时**不补**：
///   `report_one_time_keys` 是全量替换式，在未知状态上执行等于破坏性动作。
///   池饿一会儿只会降级到 fallback prekey（既定降级路径），
///   下次查询成功即恢复；而误替换会把其它对端正待领取的 key 一起冲掉。
/// - 余量 `>= lowWaterMark` → 不补；否则补到 [targetCount]。
int otkRefillCount({
  required int? remaining,
  required int lowWaterMark,
  required int targetCount,
  bool seed = false,
}) {
  if (seed) return targetCount;
  if (remaining == null) return 0;
  if (remaining >= lowWaterMark) return 0;
  final need = targetCount - remaining;
  return need > 0 ? need : 0;
}
