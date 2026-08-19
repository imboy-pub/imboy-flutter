# DF-15 群分类/标签 → 二维码 → 邀请入群

> 优先级：P1
> 状态：`分类/标签写入与回读本地通过（2026-08-19 复跑 4/4，二维码读码回归恢复） / 二维码 URL 构造+读码端点通过（08-19 有效 tk code=0、无效 tk 302；08-18 的 302 回归不再复现，阻塞解除） / 客户端渲染无头回归 08-19 实测 9/9 通过（08-18 SDK 问题未复现） / 扫码入群双端阻塞`

## 1. 目标

验证用户可以管理群分类和标签，并通过群二维码/邀请入口让授权测试账号找到目标群。

## 2. 前置条件

- [ ] 准备测试群、管理员账号、普通成员账号和第二设备/账号。
- [ ] 二维码有效期、分享目标和邀请权限已确认。
- [x] 不把二维码发给真实第三方，不执行不可逆的群清理。（2026-08-17 本轮未对外发送、未清理）

## 3. TODO 步骤

- [ ] 打开群分类列表和详情，创建/重命名一个可回收分类。
  - 预期：分类列表、详情、重命名和返回刷新正确。
  - 页面计划：[group_category_page.md](../auto_test/group/group_category_page.md)、[group_category_detail_page.md](../auto_test/group/group_category_detail_page.md)
- [ ] 为测试群添加或修改标签。
  - 预期：标签列表和群关联关系刷新正确。
  - 页面计划：[group_tag_page.md](../auto_test/group/group_tag_page.md)
- [ ] 生成群二维码，使用授权测试账号扫码。
  - 预期：扫码结果识别目标群，过期码和无效码有提示。
  - 页面计划：[group_qrcode_page.md](../auto_test/qrcode/group_qrcode_page.md)、[scanner_result_page.md](../auto_test/scanner/scanner_result_page.md)
- [ ] 在有权限时完成入群确认。
  - 预期：入群结果、群列表和成员数刷新一致。

## 4. 验收标准

- [ ] 分类、标签、二维码识别和入群结果分别可验证。
- [ ] 无效/过期二维码不会误加入群。
- [ ] 需要大群成员数的入口单独标记 `阻塞`。

## 5. 当前覆盖与阻塞

- 2026-08-19（DEMO-FLOW-20260819）复跑 `4/4 All tests passed`，**08-18 的二维码读码 302 回归不再复现（阻塞解除）**：
  - 群分类：`POST /api/v1/group/category/create`（`DEMO-FLOW-20260819-CAT-*`）code=0，返回 TSID id（107850845605070848）→ `category/list` 回读命中（列表累计 6 个分类），维持通过。
  - 群标签：绑定测试群（复用 DF-14 本轮自举群 gid=107850811471824896）code=0 msg=标签添加成功 → `tag/list` 回读命中（群累计 1 个标签），维持通过。
  - 群二维码：按客户端算法（`md5(exp_solidifiedKey)`，key 取 `.env.local` SOLIDIFIED_KEY）构造有效 tk → `GET /api/v1/group/qrcode?id&exp&tk&s=app_qrcode`（已登录）**恢复返回 `code=0 msg=success`**，payload 含群信息与 group_member（role=4）；无效 tk 仍返回 302 重定向（non_json_response），不误入群。与 08-17 通过口径一致。
  - **302 回归根因复核（只读）**：beam 进程（今日 10:25 重启，PID 37755，加载 alpha.36 sys.config）经 `ps eww` 探测仍无任何 `IMBOY_*` 环境变量；`sys.config`/`sys.local.config`/`sys.runtime.config` 亦无 solidified_key 条目——**但 tk 校验实测通过**，说明服务端运行时 solidified_key 与 imboyapp `.env.local` 一致，08-18 描述的「节点名哈希派生 dev key」分支与本轮实测不符（`config_ds:env` 只读 application env；实际注入途径未能从进程外部定位，可能为 `ps eww` 不显示全部环境变量、启动参数或运行期 set_env）。结论：**回归自愈/已被人工处置，无需后续端变更，环境级阻塞解除**；该用例继续作为环境配置漂移的自动哨兵保留。
  - 客户端二维码渲染无头复跑：`test/unit_test/page/qrcode/qrcode_pages_test.dart` + `qrcode_url_test.dart` 本轮实测 `9/9 All tests passed`——08-18 记录的 Flutter 3.47.0 SDK `text_painter.dart` 编译错误**未复现**（SDK/工件环境问题已消失，非二维码业务代码变化），恢复为实测证据而非历史引用。
  - 生产只读复跑（`.env.pro` read_env 提取，零写入）：`group_category_api_test.dart` 3 通过；`group_tag_api_test.dart` 5 通过（含无效 gid 业务响应边界），合计 8 过 0 跳 0 失败，维持 08-17 口径。未在生产写入分类/标签。
- 2026-08-18 后端升级后复跑（alpha.36）：`group_organization_local_api_flow_test.dart` 结果 `3 passed + 1 failed`，出现**回归**（08-17 同测试 4/4）。【历史记录：该回归于 08-19 复核确认不再复现，见上条】
  - 群分类：创建（`DEMO-FLOW-20260817-CAT-*`）code=0，返回 TSID id → `category/list` 回读命中（列表累计 5 个分类），维持通过。
  - 群标签：绑定测试群（gid=107539326623287296）code=0 → `tag/list` 回读命中（群累计 3 个标签），维持通过。
  - 群二维码：**读码端点 `GET /api/v1/group/qrcode?id&exp&tk&s=app_qrcode` 对按客户端算法（`md5(exp_solidifiedKey)`）构造的有效 tk 返回 HTTP 302 重定向（non_json），`code=0` 不再出现**——08-17 通过、08-18 失败，回归窗口在后端 alpha.27 → alpha.36 升级 + 今早 08:46 重启。
  - 回归根因（环境级配置缺失，非代码缺陷；imboy 仓只读定位）：`group_handler.erl:516-540` 中 `Key = config_ds:env(solidified_key)`，tk 校验 `md5(exp_Key)==Tk` 失败或未登录即 302。本轮核实：运行中 beam 进程环境**无任何 IMBOY_* 变量**（`ps eww` 确认，含 IMBOY_SOLIDIFIED_KEY 缺失）；`sys.local.config`、`sys.runtime.config`、运行 release 的 sys.config 中**均无 solidified_key 条目**（grep 0 命中）→ `imboy_app.erl:576-587` 走「节点名哈希派生 dev key」分支，与 imboyapp `.env.local` 的 SOLIDIFIED_KEY 不一致 → 校验必败。上轮通过说明当时后端进程曾注入 `IMBOY_SOLIDIFIED_KEY`（`imboy_env.erl:140` 支持该覆盖）或配置含此 key，本轮重启后丢失。**解锁方式：后端重启时注入 IMBOY_SOLIDIFIED_KEY（与 .env.local 一致）或写入 sys.local.config 后重启——涉及后端仓/进程变更，本轮未执行。**
  - 客户端二维码渲染无头复跑：`test/unit_test/page/qrcode/qrcode_pages_test.dart` + `qrcode_url_test.dart` 本轮**加载失败**（Flutter 3.47.0 stable，8-11 升级）——编译错误发生在 Flutter SDK 框架源码内部（`packages/flutter/lib/src/painting/text_painter.dart` 报 `Type 'Offset' not found` / `_LineCaretMetrics` switch 不匹配），属 SDK/artifact 不匹配的环境级问题，所有挂载 Flutter 框架的无头测试均无法加载，非二维码业务代码回归；08-17 的 `9/9 All tests passed` 证据维持。纯 Dart 链路（本 flow 的 API 测试）不受影响。
- 2026-08-17 本地组织能力 API 级验收（新增 `integration_test/demo_flow/group_organization_local_api_flow_test.dart`，纯 Dart 无设备，本地 alpha.27 + 测试账号 13900001002 + 测试群 `DEMO-FLOW-20260817-COLLAB` gid=107539326623287296）：最终 `4/4 All tests passed`。
  - 群分类：`POST /api/v1/group/category/create`（`DEMO-FLOW-20260817-CAT-*`）code=0，返回 id（TSID）→ `group/category/list` 回读命中（本地列表累计 4 个分类含本轮新建）。
  - 群标签：`POST /api/v1/group/tag/add`（绑定测试群）code=0 msg=标签添加成功 → `group/tag/list?gid` 回读命中（群累计 2 个标签）。负向发现：对非本人所在群调用 add 返回 `code=1 msg=只有群成员可以添加标签`，成员校验按预期拒绝。
  - 群二维码：复刻 `lib/page/qrcode/qrcode_url.dart` 的 `buildGroupQrcodeUrl`（`md5(exp_solidifiedKey)` 作为 tk）构造内容 URL → `GET /api/v1/group/qrcode?id&exp&tk&s=app_qrcode`（已登录）返回 `code=0 msg=success`，payload 含群信息与 group_member（role=4），证明服务端 tk 校验与扫码入群（join_group scan_qr_code 分支）可达；无效 tk 返回 302 重定向（非 JSON），不会误入群。
  - 客户端二维码渲染无头复跑：`test/unit_test/page/qrcode/qrcode_pages_test.dart` + `qrcode_url_test.dart` 合计 `9/9 All tests passed`（含 group 码 `/api/v1` 段、id/exp/tk 与后缀断言）。
- 2026-08-17 生产只读复跑（`.env.pro`，alpha.36）：`group_category_api_test.dart` 3 通过；`group_tag_api_test.dart` 5 通过（含无效 gid 业务响应边界）。未在生产写入分类/标签。
- 扫码入群完整闭环（第二设备扫真实二维码 → 入群确认 → 群列表/成员数刷新）无第二设备与第二登录账号，保持 `BLOCKED`；服务端入群分支已由上文的读码端点 API 级验证部分覆盖。
- 注意事项：本地测试账号 13900001002 为多会话共用，`group/page` 会列出其他会话创建的 DEMO-FLOW 群；自动化必须按确切群名匹配（本 flow 测试已按 `DEMO-FLOW-20260817-COLLAB` 精确匹配）。
- 分类重命名页面当前有待发布/待复验问题记录（UI 级，本轮未涉及）。
- 二维码邀请依赖第二账号或第二设备，默认不对外发送。
- 2026-08-09：`group_category_api_test.dart`、`group_tag_api_test.dart` 的只读检查通过；本地二维码渲染通过。
- 第二账号扫码、入群确认 UI 和成员列表刷新未执行，缺少双端/隔离测试条件，保持 `BLOCKED`。

## 6. 未来自动化目标

`integration_test/demo_flow/group_organization_local_api_flow_test.dart` 已落地分类/标签/二维码 URL 与读码端点的 API 级回归；其中二维码读码用例在本地后端未注入 IMBOY_SOLIDIFIED_KEY 且无等效 key 时会如实失败（2026-08-18 即如此，08-19 已恢复），本身就是该环境配置漂移的自动哨兵，属预期行为不需要改测试。后续优先补扫码识别（`scanner_result_page`）与双端扫码入群闭环。
