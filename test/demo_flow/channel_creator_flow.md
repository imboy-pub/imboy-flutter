# DF-12 创建频道 → 发布内容 → 评论 → 管理

> 优先级：P1
> 状态：`API 级闭环通过（本地，2026-08-19 复跑 7/7 维持，marker 更新 DEMO-FLOW-20260819）/ UI 链路未覆盖，订阅者视角与邀请阻塞`

## 1. 目标

验证频道创建者可以创建频道、发布文本/文章内容，查看评论和订阅者，并使用管理员入口维护频道。

## 2. 前置条件

- [x] 使用非生产环境和专用测试频道。（2026-08-17：本地后端 `http://127.0.0.1:9800/healthz` → alpha.27 db=up；写入均带 `DEMO-FLOW-20260817` 前缀。2026-08-18：本地后端已升级，`/healthz` → alpha.36 db=up（imboy main@e6d785d0），复跑闭环不受影响）
- [ ] 明确创建者、管理员、订阅者三种角色。（仅覆盖创建者单角色；本地无第二可登录测试账号）
- [x] 频道发布、评论、邀请和删除均可能写入服务端；删除频道默认不执行。（本轮未执行任何删除）

## 3. TODO 步骤

- [x] 创建测试频道并完成基本资料。（2026-08-17 API 级：`POST /api/v1/channel/create` type=0 → id=107539722597042176；另创建 type=2 频道 id=107539722630596608 验证付费类型可创建（价格需 fixture 写入）；`POST /api/v1/channel/{id}/update` 编辑简介后详情回读一致。UI 创建页未覆盖）
  - 预期：名称、头像、简介和可见性保存成功。
  - 页面计划：[channel_create_page.md](../auto_test/channel/channel_create_page.md)、[channel_edit_page.md](../auto_test/channel/channel_edit_page.md)
- [x] 发布一条文本内容并回读。（2026-08-17 API 级：`POST /api/v1/channel/{id}/message` msg_type=text → messageId=107539722699802624，`GET messages` 服务端列表命中；「文章」类型发布未覆盖）
  - 预期：内容发布成功，详情页可见，刷新后仍存在。
  - 页面计划：[channel_compose_page.md](../auto_test/channel/channel_compose_page.md)、[channel_article_page.md](../auto_test/channel/channel_article_page.md)
- [x] 发表评论并回读（创作者视角）。（2026-08-17 API 级：`POST .../message/{mid}/comment` → commentId=107539722754328576，comments 列表回读命中。**订阅者账号视角未覆盖**：本地无第二可登录测试账号）
  - 预期：评论、计数和权限符合频道设置。
  - 页面计划：[channel_comment_page.md](../auto_test/channel/channel_comment_page.md)
- [x] 创建者查看管理员和订阅者列表。（2026-08-17 API 级：`GET channels/managed` 命中新频道；creator 订阅自己的免费频道后 `GET subscribers` 返回 1 条、`GET admins` 返回 1 条。服务端权限边界：未订阅的 creator 访问订阅者列表返回 403「只有订阅者才能查看订阅者列表」）
  - 预期：角色、订阅状态和列表刷新正确。
  - 页面计划：[channel_admin_page.md](../auto_test/channel/channel_admin_page.md)、[channel_subscriber_page.md](../auto_test/channel/channel_subscriber_page.md)
- [ ] 使用频道邀请入口邀请测试账号。（阻塞：无第二测试账号可接受邀请）

## 4. 验收标准

- [x] 创建、发布、订阅者查看、评论和管理形成完整证据链。（2026-08-17：API 级证据链完整，全部有服务端响应；UI 层证据链未覆盖）
- [ ] 创建者、管理员、订阅者的权限边界清晰。（仅验证 creator 订阅前后的订阅者列表权限边界；管理员/订阅者角色操作未覆盖）
- [x] 失败时不把本地乐观内容当作服务端已发布。（所有写入均以服务端回读为准）

## 5. 当前覆盖与阻塞

- 现有频道页面计划覆盖较多，但跨页面创建者流程尚未闭环（UI 层）。
- 频道附件授权、邀请和管理员操作需非生产数据或人工确认。
- 2026-08-09：已完成频道只读/API及本地页面的部分检查；创建频道、发布内容、评论互动、管理员/订阅者角色维护和邀请写入均因缺少隔离测试频道/角色授权而 `BLOCKED`。
- 2026-08-17：本地 API 级创作者闭环打通（详见下方证据），写入阻塞解除（本地环境）；剩余阻塞收敛为：UI 链路未覆盖、第二订阅者账号视角、邀请接受、文章类型发布。
- 不能用普通频道浏览或本地乐观内容替代创建者完整闭环证据。

### 2026-08-17 证据（本地 API 级，`dart test` 全绿 7/7）

执行：`API_BASE_URL=<scripts/test.env> TEST_PHONE/TEST_PASSWORD=<scripts/test.env> IMBOY_ENV_PRO=.env.local TEST_ALLOW_CHANNEL_WRITES=true TEST_ALLOW_API_WRITES=true dart test integration_test/demo_flow/channel_creator_flow_test.dart --concurrency=1 --reporter expanded`

- 登录：uid=104250986822109184（本地测试账号，登录 code=0）。
- 创建免费频道：id=107539722597042176，name 含 `DEMO-FLOW-20260817`，type=0，code=0。
- 创建付费类型频道：id=107539722630596608，type=2，code=0（无 channel_price 行，订单会被「频道价格未配置」拒绝——价格设置无普通用户 API，仅 `/api/adm/channel/:id/price` 管理端与 fixture 脚本）。
- 编辑：`POST /api/v1/channel/{id}/update`（handler 不校验方法，body 解析与 lib 客户端 PUT 等价）→ 详情回读 description 含「v2」。
- 发布：messageId=107539722699802624；`GET /api/v1/channel/{id}/messages` 列表命中发布内容。
- 评论：commentId=107539722754328576；comments 列表回读命中。
- 订阅者列表权限边界：未订阅时 `GET subscribers` → code=403「只有订阅者才能查看订阅者列表」；creator 订阅（`POST .../subscribe` code=0）后 → subscribers=1、admins=1、managed 命中新频道。
- 清理：频道与内容保留在本地库（marker=DEMO-FLOW-20260817），未执行删除。

### 2026-08-18 复跑（本地 API 级，后端升级 alpha.36 后回归）

环境：`http://127.0.0.1:9800/healthz` → `{"status":"ok","db":"up","version":"1.0.0-alpha.36"}`（imboy main@e6d785d0 编译代码）。执行命令同上节（测试文件未改动，marker 常量仍为 `DEMO-FLOW-20260817`）。

结果：`dart test` 全绿 **7/7**，闭环行为与 08-17 完全一致：

1. 登录 uid=104250986822109184（同一本地测试账号，未注册新账号）。
2. 创建免费频道 id=107666556160575488（type=0，code=0）；创建付费类型频道 id=107666556196227072（type=2，无 channel_price 行）。
3. 编辑（update）→ 详情回读一致。
4. 发布 messageId=107666556254947328，服务端列表回读命中。
5. 评论 commentId=107666556298987520，回读命中（仍为创作者视角）。
6. managed 命中新频道；订阅后 subscribers=1、admins=1。
7. 清理：同上轮，保留在本地库，未删除。

三重门禁复核：不带 `TEST_ALLOW_CHANNEL_WRITES` / `TEST_ALLOW_API_WRITES` 运行 → `0 passed, 7 skipped`（All tests skipped），未发出任何请求，默认 SKIP 行为仍属设计。

剩余阻塞不变：UI 创建/编辑/发布/评论链路未覆盖（无设备）；第二订阅者账号视角与邀请接受阻塞（本地无第二可登录测试账号）；「文章」类型发布未覆盖。

### 2026-08-19 复跑（本地 API 级，按本轮数据标记规则更新 marker）

环境：`http://127.0.0.1:9800/healthz` → `{"status":"ok","db":"up","version":"1.0.0-alpha.36"}`（imboy main@e6d785d0，与 08-18 相同版本，未重启）。测试文件 marker 常量由 `DEMO-FLOW-20260817` 更新为 `DEMO-FLOW-20260819`（同步更新用例名与注释），执行命令同 08-17 节。

结果：`dart test` 全绿 **7/7**，闭环行为与 08-17/08-18 完全一致：

1. 登录 uid=104250986822109184（同一本地测试账号）。
2. 创建免费频道 id=107851076715415552（type=0，code=0，name 含 `DEMO-FLOW-20260819`）；创建付费类型频道 id=107851076774135808（type=2，无 channel_price 行）。
3. 编辑（update）→ 详情回读一致。
4. 发布 messageId=107851076851730432，服务端列表回读命中。
5. 评论 commentId=107851076904159232，回读命中（仍为创作者视角）。
6. managed 命中新频道；订阅后 subscribers=1、admins=1。
7. 清理：同前轮，频道与内容保留在本地库（marker=DEMO-FLOW-20260819），未删除。

三重门禁复核：不带 `TEST_ALLOW_CHANNEL_WRITES` / `TEST_ALLOW_API_WRITES` 运行 → `0 passed, 7 skipped`（All tests skipped），未发出任何请求，默认 SKIP 属设计。

剩余阻塞不变：UI 创建/编辑/发布/评论链路未覆盖（无设备轮次）；第二订阅者账号视角与邀请接受阻塞（本地无第二可登录测试账号，本轮文档与测试均无 smoke_bob 作为频道订阅者的既定命令）；「文章」类型发布未覆盖。

## 6. 未来自动化目标

- [x] 已新增 `integration_test/demo_flow/channel_creator_flow_test.dart`（纯 Dart，`dart test` 可跑，默认 SKIP，需 `TEST_ALLOW_CHANNEL_WRITES=true` + `TEST_ALLOW_API_WRITES=true` + 非生产地址三重门禁）。
- [x] 2026-08-18：该测试作为后端升级（alpha.27 → alpha.36）后的回归手段复跑通过 7/7，值得保留为本地频道写入闭环的标准回归入口。
