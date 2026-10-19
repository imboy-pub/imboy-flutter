# P2 Inventory — 企业工作台（T02 勘察报告）

勘察基线：integration HEAD `c61cd8d46e276496b2ddae8b89b17d6fe6856ddc`。方法：只读源码；未运行应用/设备。

## 0. 入口结构与宿主

| 入口 | 符号 | 观测 |
|---|---|---|
| 工作台宿主 | `EnterpriseShellPage`（`lib/page/workspace_shell/enterprise_shell_page.dart:49`）；四 destinations：消息/通讯录/工作台/我 | 移动端 NavigationBar（L302-315）、桌面 NavigationRail（L285-298），断点 `resolveWorkspaceShellLayout`（workspace_shell_breakpoint.dart）；顶栏两级上下文「企业名 · 工作区名」（L127-133） |
| 工作台页 | `EnterpriseWorkbenchPage`（`lib/modules/enterprise_oa/presentation/enterprise_workbench_page.dart:18`），由 shell `_page()` L357-388 注入 resourceEntries | ListView 三段 insetGrouped：资源组（L60-61）→ [Android] 确认登录组（L62-73）→ 应用组（L76-86） |
| 资源行 | shell `_resourceEntry`（L488-501）：项目(feature gate L365)/群组/频道/附件，各带 leading Icon + chevron，push Scaffold+AppBar 整页 | 图标 folder/person_2/speaker_2/paperclip（L369-384） |
| 客服行 | `CsWorkspaceEntryTile`（`lib/modules/customer_service/presentation/cs_workspace_entry.dart:33`） | seat-contexts 权威聚合 + `csEntryVisibleFromContexts` 纯函数；不可见=SizedBox.shrink；自定义 29×29 圆角 leading 容器 + 19px 图标（L69-80） |
| 应用行 | workbench L78-84：`ValueKey('workbench-apps-entry')` + Icon(square_grid_2x2) + `t.enterpriseOa.apps` + chevron | **无 URL 副标题/tooltip/semantics**；点击 `_openApps`（L43-54）→ 应用内 `WebViewPage(appsUrl, t.enterpriseOa.apps, allowOaDevicePermissions, oaAuthCodeHandler)` |

## 1. P2-01 统一背景/容器 — **VERIFY_EXISTING**

三段均 `CupertinoListSection.insetGrouped`（同一亮暗主题容器）；16 边距/24 组距依赖 Cupertino 默认值，待 T13 几何断言补证。无上白下灰断裂的代码路径（同 ListView 同容器族）。

## 2. P2-02 删除办公而非删除 OA — **VERIFY_EXISTING**

- 文档注释记录 2026-10-17 产品裁决（L16-17）：不再展示 OA 应用列表；工作台只留「应用」联调入口。
- OA `entries` 仍供桥 `getAuthCode` 按需签发（`_issueBridgeAuthCode` L38-41 → `OaBridgeAuthCodeService`，organization 不参与授权）。
- 回归：`test/enterprise_oa/enterprise_workbench_page_test.dart:94`「OA 应用列表不再展示（产品裁决 2026-10-17），联调入口常驻」。

## 3. P2-03 不显示调试地址 — **VERIFY_EXISTING（数据边界另记）**

- 应用行 title=`t.enterpriseOa.apps`，无 appsUrl/http(s) 文本；`appsUrl`（L33）仅作为 WebView **目的地址**传入（PRD 口径：URL 仅目的地址）。
- 仓内其余 `appsUrl/test_oa` 引用仅在 `web_view.dart` 注释（L70、L504），非 UI 输出。
- **边界（PRD Q07）**：目的页仍为 `https://imboy.pub/test_oa.html` 联调页；隐藏文字≠生产配置完成，本计划不改目的地址。

## 4. P2-04 全部导航行统一图标槽 — **NEEDS_FIX（槽位不统一）**

- 项目/群组/频道/附件/应用行：标准 `CupertinoListTile.leading = Icon(…)`（默认 24 语义槽）✓ 文本起点一致。
- **客服行**：自定义 29×29 圆角容器 + 19px 图标（cs_workspace_entry.dart L69-80），槽位尺寸/形状与其他行不一致。
- **Android 确认登录行**（workbench L68-71）：**无 leading 图标**（业务保留 ✓，容器统一但图标槽缺失）。
- 待 T13 统一为「图标槽24、间距12、文本起点一致」，不改变导航目标与 gate。

## 5. P2-05 空组不留空壳 — **NEEDS_FIX（可见性投影缺口）**

- workbench L60-61 仅按 `resourceEntries.isNotEmpty` 决定资源组——但 shell 传入的列表**恒含** `CsWorkspaceEntryTile`（不可见时渲染 SizedBox.shrink，L66-74 of cs_workspace_entry）。
- 场景：普通用户（CS 隐藏）+ 无 currentWorkspace（4 个资源行全部被 `ref.watch(currentWorkspaceProvider) != null` 门关闭，shell L364）→ 资源组仅剩不可见 shrink 子项，**仍渲染空组背景**。
- 与 PRD P2-05 备选一致：不可用 `resourceEntries.length` 猜可见性；T13 采同组逐行自然布局或宿主只读可见性投影，不复制权限规则、不调 RenderObject 反推。
- 附：OA entries 错误态有独立 retry 行（shell L241-249）✓；`_configurationReady` 前 AsyncLoading 不渲染半成品（shell L103-105）。

## 6. 行为不变锚点（T26 回归基线）

- Android 确认登录：`!kIsWeb && android && entry.inboundLoginEnabled` → `/oa/login`（extra=entry）（workbench L62-73）。
- 桥签发：打开页面不预取；仅 H5 主动 getAuthCode 时按需签发（L35-41 注释与实现）。
- feature gate：项目行 `AppFeatureRegistry.isEnabled(FeatureKeys.project)`（shell L365）。
- CS gate：`csEntryVisibleFromContexts`（domain 纯函数），fail-closed（cs_workspace_entry.dart L52-58）。

## 7. 既有测试索引（P2 相关）

| 文件 | 覆盖 |
|---|---|
| `test/enterprise_oa/enterprise_workbench_page_test.dart` | macOS OA 设备权限显式传递、无外部 launcher、办公列表已删+联调入口常驻 |
| `test/unit_test/page/workspace_shell/enterprise_shell_page_test.dart` | 抽屉/顶栏上下文/汉堡入口/筛选 tab/重挂载恢复/撤权空工作台/无工作区组织架构/换账号清资源 |
| `test/enterprise_oa/t15_enterprise_layout_test.dart` | 资源回调矩阵、企业动作矩阵 |
| `test/customer_service/cs_seat_contexts_test.dart`（+cs_seat_gate_test） | CS 入口 gate 纯函数 |

## 8. 判定汇总

| 项 | 判定 | 一句话依据 |
|---|---|---|
| P2-01 | VERIFY_EXISTING | 三段同 insetGrouped 容器；几何数值待 T13 断言 |
| P2-02 | VERIFY_EXISTING | 办公列表已删（2026-10-17 裁决），OA 桥签发保留，回归在 |
| P2-03 | VERIFY_EXISTING | 行内无 URL 文本；URL 仅 WebView 目的地址；目的页仍联调页（Q07 边界） |
| P2-04 | NEEDS_FIX | CS 行 29×29 自定义槽、Android 确认登录行无图标槽，未统一为 24 槽 |
| P2-05 | NEEDS_FIX | 资源组门槛=列表长度恒真；CS 隐藏+无工作区时空组壳仍渲染 |

未核验（设备依赖）：运行时亮暗截图、桌面窗口实际布局。不阻塞源码 inventory。
