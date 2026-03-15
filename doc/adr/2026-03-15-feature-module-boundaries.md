# ADR: Flutter Feature Module Boundaries And Lightweight Plugin Extension Points

- Status: Accepted
- Date: 2026-03-15
- Context:
  `imboyapp` 已经覆盖聊天、会话、联系人、群组、频道、朋友圈、收藏、通知与端到端加密等多条业务线，但代码入口仍大量集中在全局 `service/`、`page/`、`component/` 下。随着客户端继续扩展，如果没有稳定的 feature module 边界，跨域调用、兼容层治理和后续架构门禁都会持续变重。
- Decision:
  后端继续保持 modular monolith，不拆微服务；Flutter 客户端与管理后台按领域模块化推进，不再继续膨胀全局 `service/pages/components` 入口。Flutter 侧会为主要领域建立稳定的 `modules/<domain>/public.dart` 公开入口，并通过薄封装与兼容层逐步迁移现有调用。插件化只用于高变化扩展点，例如消息类型渲染、媒体处理扩展等，不用于路由守卫、消息一致性、核心状态流转等主链路。
- Consequences:
  新增客户端能力应优先落在领域模块公开入口之后，再逐步把现有页面、服务、状态与适配器收敛到模块内部。历史全局服务文件会暂时保留为 wrapper 或 facade，直到调用点收敛并有 grep/验证证明可以收口。后续任务会补充模块边界门禁，限制绕过 `public.dart` 的内部依赖。
- Non-Goals:
  本次决策不引入通用插件平台、不改写现有后端 API 契约、不一次性迁移全部 Flutter 页面，也不把业务插件系统扩展到仓库内已有的本地插件 package。
