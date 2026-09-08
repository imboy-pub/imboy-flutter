# `page/workspace/workspace_picker_page.dart`

> 功能点 11 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 工作区壳模式顶栏点击当前工作区名进入「我的工作区」切换页（路由 /workspace，页标题「我的工作区」） | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 按功能本质判定通过（不改行文本）：ea682e31 后入口形态变更——顶栏左上常驻 WorkspaceSwitcherChip（工作区图标+名称+⌄）点击进「我的工作区」页（页标题不变）；账户 Sheet 工作区列表为第二切换入口（多工作区时）；此前 47461adc 曾收进账户 Sheet 致不可发现，ea682e31 恢复常驻 |
| 阻塞 | 列表恒有缓存，无缓存场景不可达（清数据卡登录） | `page/workspace/workspace_picker_page.dart` | 无任何工作区数据时首屏显示加载视图（转圈），加载完成后切换为列表 | 未测 | 批次W2R2 | 0 | 0 | 0 | 观察项：进页零网络请求纯缓存，页内无刷新机制，新工作区需重启才可见 |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 列表渲染我加入的工作区卡片：logo 头像图，无 logo 显示名称首字符（名称为空显示 ?）+ 工作区名 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：无 logo 首字符 A+名称正常（甲/乙双账号；logo图与空名称?分支仍未触发，沿用批次W2R2） |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 当前选中工作区卡片带主色描边边框且右侧显示对勾图标，其余卡片无标识 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：WS1 选中卡描边+对勾正常（ACC_A 双卡场景与 ACC_B 单卡场景均验） |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 点击其他工作区卡片：选中该工作区并自动返回壳，壳从 Overview 开始展示 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：WS2→WS1 切换回壳从 Overview 开始、chip 名同步 |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 切换到配置了不同 branding 的工作区后返回壳，新工作区主题（branding 颜色）生效 | 已通过 | 批次W2R4 | 1 | 1 | 0 | W2R4：WS2 橙(FF6600)/WS1 红(FF0000，后续批次配置) 切换主题即时生效；4a60d8f7 主色接入壳主题后对比更鲜明（历史「WS1 无色回落蓝」场景已被新配置数据覆盖）。⭐BUG#（批次W2R2FIX）详见 git log |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 已归档工作区卡片在工作区名下方显示红色「已归档」徽标文案 | 已通过 | 批次W2R2 | 0 | 0 | 0 | W2R4 未复测（两工作区当前均为恢复态，需再归档造场景）；批次W2R2/W2R3 证据沿用，picker 页未被受检提交改动 |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 账号无任何工作区时显示空态视图（rectangle_stack 图标 + 空态标题/副标题文案） | 已通过 | 批次W2R3 | 0 | 0 | 0 | W2R4 未复测（需无工作区账号）；批次W2R3 ACC_F 证据沿用（渲染自壳bootstrap _NoWorkspaceEntry，与picker共用WorkspaceEmptyView） |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 加载失败且无缓存数据时显示错误视图，点重试按钮重新拉取我的工作区列表 | 已通过 | 批次128 | 0 | 0 | 0 | AT-WPF1 全绿（integration_test/workspace/workspace_picker_failure_test.dart）：「清数据卡登录」定性推翻——WorkspaceShellNotifier 常驻但 container.invalidate 可重置 state，adapterForTest 注入 /workspaces/mine 业务失败 → error+空列表 → picker 错误视图+workspace-error-retry → 解除拦截点重试列表恢复（BobWS 行出现）；构造配方=登录后归位 chat 体验+invalidate+failMine 下 select(workspace)+兜底手动 loadMine |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 再次点击当前已选中的工作区卡片：直接返回壳，不重复加载、当前工作区不变 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：再点当前选中卡直接回壳、工作区不变无重复加载（ACC_B 单卡场景实测） |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 系统返回手势/顶栏返回键回到壳，当前工作区保持不变 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：picker 顶栏返回箭头回壳、当前工作区保持 |
