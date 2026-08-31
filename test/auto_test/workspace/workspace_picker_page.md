# `page/workspace/workspace_picker_page.dart`

> 功能点 11 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 工作区壳模式顶栏点击当前工作区名进入「我的工作区」切换页（路由 /workspace，页标题「我的工作区」） | 已通过 | 批次W2R2 | 0 | 0 | 0 | 顶栏工作区名进「我的工作区」页，标题正确 |
| 阻塞 | 列表恒有缓存，无缓存场景不可达（清数据卡登录） | `page/workspace/workspace_picker_page.dart` | 无任何工作区数据时首屏显示加载视图（转圈），加载完成后切换为列表 | 未测 | 批次W2R2 | 0 | 0 | 0 | 观察项：进页零网络请求纯缓存，页内无刷新机制，新工作区需重启才可见 |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 列表渲染我加入的工作区卡片：logo 头像图，无 logo 显示名称首字符（名称为空显示 ?）+ 工作区名 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 无logo显示首字符A+名称；logo图与空名称?分支未触发 |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 当前选中工作区卡片带主色描边边框且右侧显示对勾图标，其余卡片无标识 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 选中卡主色描边+对勾，其余卡无标识 |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 点击其他工作区卡片：选中该工作区并自动返回壳，壳从 Overview 开始展示 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 双向切换均回壳Overview开始，顶栏名同步 |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 切换到配置了不同 branding 的工作区后返回壳，新工作区主题（branding 颜色）生效 | 已通过 | 批次W2R2FIX | 1 | 1 | 0 | 真机WS2橙/WS1无色回落蓝；根因mine列表不含branding+branding接口嵌套解析错，ensureCurrentBranding补拉 |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 已归档工作区卡片在工作区名下方显示红色「已归档」徽标文案 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 归档WS2重启后卡显示红色已归档徽标；壳顶橙横幅「内容可查看写已禁用Owner可恢复」 |
| 阻塞 | 需无任何工作区账号 | `page/workspace/workspace_picker_page.dart` | 账号无任何工作区时显示空态视图（rectangle_stack 图标 + 空态标题/副标题文案） | 未测 | 批次W2R2 | 0 | 0 | 0 | 同创建页前置 |
| 阻塞 | 需无缓存+加载失败同时成立 | `page/workspace/workspace_picker_page.dart` | 加载失败且无缓存数据时显示错误视图，点重试按钮重新拉取我的工作区列表 | 未测 | 批次W2R2 | 0 | 0 | 0 | 清数据则卡登录，不可达 |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 再次点击当前已选中的工作区卡片：直接返回壳，不重复加载、当前工作区不变 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 再点当前选中卡直接回壳，工作区不变无重复加载 |
| 无待办 | - | `page/workspace/workspace_picker_page.dart` | 系统返回手势/顶栏返回键回到壳，当前工作区保持不变 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 顶栏返回箭头回壳，当前工作区保持 |
