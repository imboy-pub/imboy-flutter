# `page/contact/assistant_plaza/assistant_plaza_page.dart`

> 功能点 10 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需人工决策：生产补配 bailian 凭据（imboy a83648e2 已切百炼 provider，qianfan 已弃） | `page/contact/assistant_plaza/assistant_plaza_page.dart` | 助手收到消息后返回回复 | 未测 | 批次26 | 1 | 0 | 1 | 代码侧已闭环：后端守卫 fail-closed 不再 badmap 崩溃 + 已切 bailian（qwen3.7-flash，a83648e2）。剩余纯配置：生产库 agent provider/凭据补配，属人工授权范围（对外 AI 调用+费用） |
| 无待办 | - | `page/contact/assistant_plaza/assistant_plaza_page.dart` | 加载助手列表并渲染卡片 | 已通过 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/contact/assistant_plaza/assistant_plaza_page.dart` | 点击「发消息」进入助手会话 | 已通过 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/contact/assistant_plaza/assistant_plaza_page.dart` | 顶部展示 AI 透明声明卡 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/contact/assistant_plaza/assistant_plaza_page.dart` | 搜索助手并做 300ms 防抖 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/contact/assistant_plaza/assistant_plaza_page.dart` | 搜索无结果展示对应空态文案 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/contact/assistant_plaza/assistant_plaza_page.dart` | 滚动触底加载下一页助手 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/contact/assistant_plaza/assistant_plaza_page.dart` | 下拉刷新重新拉取助手列表 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/contact/assistant_plaza/assistant_plaza_page.dart` | 加载失败展示错误态与重试 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/contact/assistant_plaza/assistant_plaza_page.dart` | 助手昵称旁展示 AI 身份徽章 | 待重验 | - | 0 | 0 | 0 | |
