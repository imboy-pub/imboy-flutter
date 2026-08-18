# DF-19 联系人 → 备注/标签 → 分组筛选

> 优先级：P1
> 状态：`本地 API 写入闭环通过（2026-08-17 建立，2026-08-18 alpha.36 复跑 8/8 维持）/ 分组 id 契约缺陷未修复 / UI 级展示待执行（设备已恢复在线）`

## 1. 目标

验证好友建立后，用户可以修改联系人备注、创建标签、给好友打标签并按标签筛选。

## 2. 前置条件

- [x] 已有明确授权的测试好友关系。（2026-08-17：本地合成账号 A=13900260817 ↔ B=13900260818，好友关系由 DF-02 闭环建立/自愈）
- [x] 使用专用标签名和备注内容，不修改真实第三方资料。（备注/标签/分组均带 DEMO-FLOW-20260817 / DF0817 标记，仅写本地测试账号）
- [x] 删除标签、解除关系等破坏性动作默认不执行。（user_tag/delete、friend/category/delete、relation/remove、friend/delete 均未执行；本地好友关系保留供后续复用）

## 3. TODO 步骤

> 2026-08-17 勾选说明：以下步骤按 **API 级等价物** 完成并勾选（服务端证据充分）；
> 联系人页/资料页的 UI 展示（备注在联系人列表同步显示、标签筛选 UI）未执行，详见第 5 节。

- [ ] 从联系人打开测试好友资料和更多设置。（UI 步骤未执行；API 级入口 `friend/list`/`friend/information` 可达已由只读契约覆盖）
  - 预期：好友信息、备注和管理入口正确。
  - 页面计划：[contact_page.md](../auto_test/contact/contact_page.md)、[people_info_more_page.md](../auto_test/contact/people_info_more_page.md)
- [x] 修改好友备注并重新加载资料。（API 级：`POST /api/v1/friend/change_remark` → code=0；`friend/list` 回读 remark 与写入一致）
  - 预期：备注服务端保存成功，联系人列表同步展示。
  - 页面计划：[contact_setting_page.md](../auto_test/contact/contact_setting_page.md)
- [x] 创建“demo”标签并给测试好友打标签。（API 级：`POST /api/v1/user_tag/add` → tagId>0；`POST /api/v1/user_tag_relation/add` → code=0；`user_tag/page` 与 `user_tag_relation/friend_page` 均回读到）
  - 预期：标签保存成功，好友与标签关系可见。
  - 页面计划：[contact_setting_tag_page.md](../auto_test/contact/contact_setting_tag_page.md)、[contact_tag_list_page.md](../auto_test/user_tag/contact_tag_list_page.md)、[user_tag_save_page.md](../auto_test/user_tag/user_tag_save_page.md)
- [x] 按标签筛选联系人并打开好友资料。（API 级：`GET /api/v1/user_tag_relation/friend_page?tag_id=` → 筛选结果包含测试好友 B；"打开好友资料"的 UI 部分未执行）
  - 预期：筛选结果与标签关系一致。
- [x] 分组管理（后端 API 存在，一并验证）：`POST /api/v1/friend/category/add` → id>0；`POST /api/v1/friend/move` → code=0；`friend/list` 回读 B 的 category_id 与新分组一致。注意：移动端无独立好友分组页面，App 内分组能力由好友标签（scene=friend）承担；friend/category+move 为后端能力，客户端未接入。

## 4. 验收标准

- [x] 备注、标签、好友关系和筛选结果重新加载后保持一致。（2026-08-17 本地 API 级：change_remark 后 friend/list 回读一致；打标后 tag/page、relation/friend_page 回读一致；分组 move 后 category_id 回读一致）
- [x] 失败时不把本地临时标签显示为服务端已保存。（断言均基于服务端回读：tagId>0、tag/page 含新标签、friend_page 含目标好友；标签名超 14 字时服务端拒绝并提示「Tag 最多14个字」）
- [x] 标签删除和好友关系破坏操作默认阻塞。（本轮未执行 user_tag/delete、category/delete、relation/remove、friend/delete）

## 5. 当前覆盖与阻塞

- 页面级计划覆盖联系人设置和 user_tag，但还没有跨页面流程。
- 需要明确好友测试账号，避免产生第三方通知或资料变更。
- 2026-08-09：`contact_api_test.dart` 的联系人只读检查通过，本地标签 UI 部分检查通过，计入本轮汇总。
- 2026-08-17：**本地 API 级联系人管理写入闭环通过（8/8）**。新增 `integration_test/demo_flow/contact_management_flow_api_test.dart`（纯 dart test，门禁：`TEST_ALLOW_API_WRITES=true` + 非生产 URL + 双账号，缺一即 SKIP；含好友关系自愈前置）。环境与账号同 DF-02（本地 `http://127.0.0.1:9800`，A=13900260817 uid=107539488731039744 ↔ B=13900260818 uid=107539489230161920）。命令（凭据经环境注入）：`API_BASE_URL=... IMBOY_ENV_PRO=.env.local TEST_PHONE=... TEST_PHONE2=... TEST_ALLOW_API_WRITES=true dart test integration_test/demo_flow/contact_management_flow_api_test.dart --concurrency=1` → `All tests passed!`（8 passed）。步骤证据：
  - 备注：`POST /api/v1/friend/change_remark {uid:B, remark:"DEMO-FLOW-20260817-备注-v2"}` → code=0，`friend/list` 回读 B.remark 与写入一致；
  - 标签创建：`POST /api/v1/user_tag/add {scene:"friend", tag:"DF0817标签"}` → code=0，payload.tagId>0；
  - 打标：`POST /api/v1/user_tag_relation/add {scene:"friend", objectId:B, tag:["DF0817标签"]}` → code=0；
  - 标签回读：`GET /api/v1/user_tag/page` → 列表含「DF0817标签」；
  - 按标签筛选：`GET /api/v1/user_tag_relation/friend_page?tag_id=` → 结果包含 B；
  - 分组创建：`POST /api/v1/friend/category/add {name:"DF0817分组"}` → code=0，id>0；
  - 移动入组：`POST /api/v1/friend/move {user_id:B, category_id}` → code=0，`friend/list` 回读 B.category_id 与新分组一致。
- 2026-08-17 后端契约发现（本地 alpha.27，不修改后端，仅在测试中兼容）：① `friend/category/add` 响应 `payload.id` 不是 TSID 整数，而是嵌套 map `{id:<真实TSID>, name, groupname}`——handler 把 `friend_category_logic:add` 返回的整行 map 当作 LastInsertId 放进了 `#{<<"id">> => LastInsertId}`；建议后端后续修正为裸 TSID。② 标签名服务端限 14 字（超长报「Tag 最多14个字」）。③ 移动端无独立好友分组页面，App 分组能力由好友标签（scene=friend）承担；`friend/category`+`friend/move` 为后端已有但客户端未接入的能力。
- 2026-08-17 生产只读复跑：`user_tag_api_test.dart` 以 `.env.pro` 注入运行 → 4/4 通过（无 SKIP：标签分页/数据结构/关系分页/匿名鉴权拒绝；登录 uid=4），未执行任何生产写入。
- 2026-08-17 阻塞：UI 级展示未验证——无 Android/iOS 真机在线（macOS 被其他会话独占），联系人页备注同步显示、标签管理页、按标签筛选页面的 UI 呈现仍待设备可用后复核；结论止步于 API 层。
- 2026-08-18：**alpha.36 复跑维持通过（8/8 All tests passed）**。备注回读、标签创建/打标/回读/筛选、分组创建/移动入组/category_id 回读全链路无回归。运行注意与 DF-02 同：上轮密码未持久化，本轮经本地 DB 重置两个 DEMO-FLOW 合成账号密码后以环境变量注入；API_BASE_URL 须传干净值（`scripts/test.env` 行内注释陷阱见 friend_flow.md 08-18 条目）。
- 2026-08-18 遗留问题复核（后端 alpha.36，未修改后端）：
  - **分组 id 契约缺陷未修复**：实测 `POST /api/v1/friend/category/add {name:"DF0818-contract-probe"}` → code=0，`payload.id` 仍是嵌套 map `{"groupname":"DF0818-contract-probe","id":107667256150067200,"name":"DF0818-contract-probe"}`（真实 TSID 在 `payload.id.id`）。代码定位维持：`friend_category_logic:add/2` 返回整行 map，`friend_category_handler.erl:46-47` 将其整体当作 LastInsertId 写入 `#{<<"id">> => LastInsertId}`。测试的兼容提取逻辑仍必要。
  - **分组 API 客户端未接入维持**：imboyapp `lib/` 全库无 `friend/category`、`friend/move`、`friend_category` 任何引用；移动端分组能力仍由好友标签（scene=friend）承担。
  - 探针数据：本轮新建分组 DF0818-contract-probe（id=107667256150067200）与测试内建的 DEMO-FLOW 标记标签/分组均保留在本地库，可回收。
- 2026-08-18 设备复核：Android 真机 MRD AL00 与 iPhone 16e 已在线（同 DF-02 记录），UI 级展示验证的设备条件恢复，但联系人页备注同步显示、标签筛选页 UI 呈现属真机验收轮次，本轮未执行；结论仍止步于 API 层。

## 6. 未来自动化目标

2026-08-17 已落地 `integration_test/demo_flow/contact_management_flow_api_test.dart`（建议中的文件名按 API 级实现，使用可回收测试好友与 DEMO-FLOW 标记标签；双账号/写入门禁缺失即 SKIP）。后续如需 UI 级流程，再扩展设备型 integration_test。
