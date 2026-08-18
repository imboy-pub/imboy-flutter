# DF-15 群分类/标签 → 二维码 → 邀请入群

> 优先级：P1
> 状态：`分类/标签写入与回读本地通过（2026-08-17） / 二维码 URL 构造+读码端点通过 / 客户端渲染无头回归通过 / 扫码入群双端阻塞`

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

`integration_test/demo_flow/group_organization_local_api_flow_test.dart` 已落地分类/标签/二维码 URL 与读码端点的 API 级回归；后续优先补扫码识别（`scanner_result_page`）与双端扫码入群闭环。
