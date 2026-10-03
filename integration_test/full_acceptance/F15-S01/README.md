# F15-S01 路由与 WS 清单 — 静态枚举

> execution-contract 第 4 节：Backend 域，operation 矩阵，本地可枚举，
> 不能只看 OpenAPI 存在。

## 产物索引

| 文件 | 内容 |
|---|---|
| `route-inventory.tsv` | **791 条路由**（v2），列：line/section/path/handler/action/is_open_anon/in_option/kind/note |
| `ws-inventory.tsv` | 1 条 WebSocket 端点 `/api/v1/ws`（websocket_handler；open/0 注释「ws 有自己的 auth」） |
| `open-whitelist.tsv` | 39 项匿名可达路径，全部与静态路由精确匹配（unmatched=0） |
| `stats.json` | 分布统计与 v1→v2 修正记录 |

## 数字总览

- **791 条**：MainRoutes 10 / ApiV1Routes 406 / AdmRoutes 256 / PluginOrCSWire 39 / HumanOrSeatDynamic 80。
- kind：HTTP_API 786 / STATIC 4 / WS 1；引用 144 个 handler。
- 跨行 action map 239 条（v1 曾整批漏提，v2 修正）；空 action 14 条为设计如此
  （健康/指标/静态/MCP/SSE/WS/签名自验下载），非解析缺陷。
- option 白名单 3 项（feedback/add、app_version/check、app_upgrade/report）。

## OpenAPI 表达不了、本清单记录的三层事实

1. **编译期 feature 门**：未选中 feature 的路由在编译时被物理裁剪
   （`generated/imboy_product_features.hrl` + `imboy_feature:compiled_routes`），
   源码全量 ≠ 运行时暴露——F15-S02 必须按候选 profile 复核。
2. **动态拼装段**：PluginOrCSWire / HumanOrSeatDynamic 两段含运行时 flatmap /
   customer_service_wire / seat_console_route 拼装，静态清单标 DYNAMIC_REVIEW。
3. **双白名单语义**：`open/0`（39 项免鉴权）与 `option/0`（3 项免登录可写）
   是授权负例设计的直接输入；源码注释中含历史安全决策（如
   conversation/online 移出白名单的原因），F15-S02 应将这些注释列为负例来源。

## 抽样验证记录

第 82 行 wechat-mini/login（跨行 action `wechat_mini_login`，open=TRUE）与
AdmRoutes 首条 `/api/adm`（action=index）已对照源码原文核验一致。

## 边界

本清单为 PREPARATION 静态产物（evidence_phase=PRELIMINARY 性质），不构成任何
授权行为 PASS；授权/RBAC/租户/幂等负例是 F15-S02 的运行时职责。imboy 仓全程
只读。
