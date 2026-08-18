# DF-05 朋友圈发布 → 查看 → 互动

> 状态：`本地 API 闭环通过（发布/自读/好友可见/点赞/评论/回读）；UI 链路未复验`
> 优先级：P1
> 类型：社交内容流程

## 1. 目标

验证测试账号能发布一条朋友圈，回到信息流查看，进入详情并完成一项可回收互动，例如点赞或评论。

## 2. 前置条件

- [ ] 使用非生产环境和明确授权的测试账号。
- [ ] 准备可回收的文本或测试媒体素材；定位权限、相册权限和视频素材另行确认。
- [ ] 确认联系人入口和朋友圈入口没有被当前 APK 的已知问题阻塞。
- [ ] 发布、评论、点赞都会写入数据；没有授权时只做只读页面检查。

## 3. TODO 执行步骤

- [ ] 从朋友圈入口打开信息流。（UI 步骤，本轮无真机未复验；2026-08-09 本地 UI 部分检查通过，API 层 feed 见下）
  - 预期：信息流首屏、发布入口和通知入口正常。
  - 页面计划：[moment_feed_page.md](../auto_test/moment/moment_feed_page.md)
- [x] 打开发布页，输入唯一测试文本并确认发布。（2026-08-17 本地 API：`POST /api/v1/moment/create` code=0）
  - 预期：确认按钮状态正确，发布成功后返回信息流并出现新动态。
  - 页面计划：[moment_create_page.md](../auto_test/moment/moment_create_page.md)
- [x] 点击自己的动态进入详情。（2026-08-17 本地 API：`GET /api/v1/moment/:id` 回读成功，like/comment 计数一致）
  - 预期：正文、媒体、作者信息和操作入口正确。
  - 页面计划：[moment_detail_page.md](../auto_test/moment/moment_detail_page.md)
- [x] 在授权测试账号下执行点赞或评论其中一项。（2026-08-17 本地 API：点赞与评论均完成服务端闭环）
  - 预期：服务端成功，计数和详情刷新一致。
- [x] 返回信息流并刷新。（2026-08-17 本地 API：A 自身 feed 首页回读命中；B 经 `/moments/user/:uid` 命中）
  - 预期：动态仍可见，互动状态与服务端一致。
- [x] 不执行默认删除动态；如需清理，先取得人工授权并使用专用测试数据。（本轮未删除，遵守红线）

## 4. 验收标准

- [x] 发布成功必须有服务端成功证据，不能只看本地乐观插入。（2026-08-17 create code=0 + id 回读）
- [x] 信息流和详情页展示同一条动态。（API 层 feed 与 detail 均命中同一 moment_id）
- [x] 点赞/评论至少有一项完成服务端闭环。（两项均完成：like_count=1、comment_count=1）
- [x] 入口被阻塞、缺素材或缺权限时，流程结果标记为 `阻塞`。（本轮 UI 入口未复验，非阻塞项已按 API 证据记录）

## 5. 当前已有覆盖与阻塞

- 当前页面计划显示朋友圈入口曾受联系人页 BUG#131 和 APK 版本条件影响，执行前必须重新确认。
- 页面级计划已有信息流、发布、详情、点赞、评论等覆盖，但没有本流程级的集成测试文件。
- 发布、评论、点赞和删除均涉及数据写入；不使用真实第三方动态。
- 2026-08-09：`moment_api_test.dart` 的信息流只读检查和本地朋友圈 UI 部分检查通过，计入本轮汇总。
- 2026-08-17 生产只读复跑：`moment_api_test.dart` 以 `.env.pro` 注入运行 `4/4 All tests passed`（feed 信封/结构/无效 id 边界），未做任何生产写入。
- 2026-08-17 本地 API 闭环通过（详见第 7 节证据）；删除动态未执行。

## 6. 未来自动化目标

建议新增：`integration_test/demo_flow/moments_flow_test.dart`。

第一版优先覆盖只读进入、测试文本发布和信息流回显；媒体上传、位置、可见性、提醒谁看和删除动态在有稳定测试素材及清理策略后再加入。

**2026-08-17 已落地**：`integration_test/demo_flow/moments_flow_test.dart`（纯 dart test，本地门禁默认 SKIP），覆盖发布→feed 回读→好友可见→点赞→评论→详情/评论列表回读+4 个错误分支。

## 7. 2026-08-17 本地闭环证据

环境：本地后端 `http://127.0.0.1:9800`（healthz `1.0.0-alpha.27`，运行中节点、未干预进程）；
账号 A=`13900001002`（uid=104250986822109184），账号 B=`smoke_bob`（uid=1000000056，本地合成测试账号，
为本轮验收重设密码）；A↔B 好友关系经 `/api/v1/friend/add`+`/confirm` 建立（服务端 visibility=1 为仅好友可见，
非好友不可见且点赞/评论会被 ACL 拒绝，故好友是互动闭环的必要前置）。

命令（`--concurrency=1`）：

```bash
read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' .env.local; }
API_BASE_URL=http://127.0.0.1:9800 \
IMBOY_SOLIDIFIED_KEY="$(read_env SOLIDIFIED_KEY)" \
TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
TEST_PHONE2=smoke_bob TEST_PASSWORD2=demoflow888 \
TEST_ALLOW_API_WRITES=true \
dart test integration_test/demo_flow/moments_flow_test.dart --concurrency=1
# 结果：5 passed, 0 failed（All tests passed!）
```

关键数字与响应（全部带 `DEMO-FLOW-20260817` 标记）：

1. 好友前置（幂等重跑时）：add `code=1(already_friends)`、confirm `code=1(no_pending_request)`，功能由 B 可见性断言证明。
2. `POST /api/v1/moment/create`（content 含标记，visibility=1，allow_comment=true）→ `code=0`，moment_id=`107541600240142336`。
3. A `GET /api/v1/moments/feed?limit=20` → 首页命中新动态。
4. B `GET /api/v1/moments/user/104250986822109184` → 命中同一动态（好友可见性通过）。
5. B `POST /api/v1/moment/:id/like` → `code=0`；B `POST /api/v1/moment/:id/comment` → `code=0`。
6. A `GET /api/v1/moment/:id` → `stats.like_count=1`、`stats.comment_count=1`。
7. B `GET /api/v1/moment/:id/comments` → 命中标记评论。
8. 错误分支（均为结构化业务错误 code=1，无崩溃）：空内容「动态内容不能为空」、visibility=9「可见性参数无效」、
   `moment/0/like`「动态不存在」、空评论「动态不存在」。
9. 红线遵守：未调用 `moment/:id/delete`；未向生产发布任何动态。

未覆盖/后续：真机 UI 链路（信息流入口→发布页→详情页操作）本轮无设备未复验；
媒体上传、位置、@提醒、可见性 0/3/4 分支未覆盖。
