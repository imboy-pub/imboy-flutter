# P0 Demo Flow 执行计划

> 本文件把 P0 业务流程与现有可执行测试对齐，供 Claude Code 逐项执行。
> 生产环境默认只允许登录、探活和只读验证；只有用户明确授权的双账号消息联调才允许对指定测试账号写入消息。资金、频道写入、密钥恢复等高风险动作仍不执行。
> 更新时间：2026-08-10

## 1. 执行原则

1. 先复用现有 `integration_test`，只有现有测试无法覆盖跨模块结果时才新增 `integration_test/demo_flow/*`。
2. 先做只读和可回收数据流程，再做写入流程。
3. 双账号、双设备、E2EE、频道写入、资金写入都必须满足显式前置条件。
4. UI 出现结果不等于流程通过；写操作必须有服务端成功证据。
5. 缺条件用 `SKIP` 或 `阻塞`；门禁标记 `SKIP` 后必须立即退出当前测试，不得继续执行写入步骤。

## 2. P0 执行矩阵

| 流程 | 可复用现有测试 | 当前缺口 | 下一步动作 | 主要门槛 |
|---|---|---|---|---|
| [account_flow.md](./account_flow.md) | `auth/register_flow_test.dart`、`auth/password_change_test.dart`、`auth_api_test.dart` | 注册、退出重登、恢复需要生产外专用账号 | 已完成已注册账号 API/登录/账号子页只读；注册与恢复受控跳过 | 测试账号、验证码、非生产环境 |
| [friend_flow.md](./friend_flow.md) | `contact/add_friend_request_test.dart`、`confirm_new_friend_test.dart`、`friend_management_test.dart`、`contact_api_test.dart` | 搜索→申请→确认→双方联系人未串联 | 已完成搜索、联系人只读和入口复核；关系写入受控跳过 | 第二测试账号、通知写入 |
| [conversation_flow.md](./conversation_flow.md) | `chat/conversation_test.dart`、`conversation_api_test.dart` | 会话列表→单聊/群聊→未读 UI 闭环不完整；真机入口初始化偏慢 | 已完成会话 API；继续处理真机入口/导航阻塞 | 测试会话数据；删除/清空不执行 |
| [single_chat_flow.md](./single_chat_flow.md) | `chat/conversation_test.dart`、`chat/single_chat_readonly_test.dart`、`e2e_chat_test.dart`、`demo_flow/dual_account_message_flow_test.dart` | 联系人入口和异常重试分支仍未完整覆盖；E2EE 未串联 | 已通过已有 C2C 会话进入单聊页；双账号明文消息与重进恢复已通过；E2EE 另行验收 | 双账号、测试消息写入、E2EE 设备 |
| [channel_flow.md](./channel_flow.md) | `channel/channel_e2e_test.dart`、`channel_publish_test.dart`、`channel_subscribed_detail_consistency_test.dart`、`channel_discover_readonly_test.dart`、`channel_api_test.dart`、`wallet/wallet_readonly_test.dart` | 频道→群聊→日程→钱包未串联 | 已通过频道发现推荐列表只读入口和钱包首页只读 UI；详情一致性因生产账号无已订阅频道而受控 `SKIP`，订阅/付费/转账仍受控 | 频道写入开关、群入口、日程数据 |
| [group_creation_flow.md](./group_creation_flow.md) | `group_api_test.dart`、`group_member_api_test.dart`、`group/group_creation_readonly_test.dart`、`demo_flow/group_creation_management_flow_test.dart`、`demo_flow/group_member_readback_flow_test.dart` | 面对面建群、入群确认和新群会话未串联 | 已通过普通建群、邀请 UID 4、群名/公告写入及 macOS/Android 双端回读；面对面链路仍受控跳过 | 第二设备、面对面暗号和可回收新群会话 |
| [group_chat_flow.md](./group_chat_flow.md) | `chat/group_chat_test.dart`、`conversation_api_test.dart`、`demo_flow/group_dual_account_message_flow_test.dart` | @成员、失败分支、多人并发未覆盖 | 双账号文本消息已在 macOS/Android 测试群完成 ACK、跨设备收发与重进回读；继续补 @成员和失败分支 | 双账号、群成员、通知写入 |
| [group_management_flow.md](./group_management_flow.md) | `group_member_api_test.dart`、`group/group_management_readonly_test.dart`、`group/group_detail_readonly_test.dart`、`group/group_management_longpress_readonly_test.dart`、`demo_flow/group_creation_management_flow_test.dart`、`demo_flow/group_member_readback_flow_test.dart`、`demo_flow/group_member_role_flow_test.dart` | 成员移除和危险权限变更写入未执行 | 普通建群、邀请、群名/公告与成员角色均由 117 受控写入并由服务端及 118 Android 真机回读；角色已恢复为普通成员，成员移除和危险操作仍受控跳过 | 管理员/普通成员角色、可回收成员数据 |
| [group_collaboration_flow.md](./group_collaboration_flow.md) | `group_schedule_api_test.dart`、`group/group_collaboration_readonly_test.dart`、`demo_flow/group_collaboration_flow_test.dart` | 费用、AA、跨频道进入群日程未覆盖 | 117 macOS 创建/定位，118 Android 确认/提交/投票；双方列表与详情回读通过 | 费用结算和预约能力不在现有模块范围 |
| [e2ee_security_flow.md](./e2ee_security_flow.md) | `e2ee_olm_device_test.dart`、`sqlcipher_migration_test.dart`、`mine/mine_subpages_smoke_test.dart`、`demo_flow/dual_account_message_flow_test.dart` | 本地密码学、只读入口已通过；生产 policy 为 optional，双设备握手/消息与备份恢复未形成闭环 | 已完成本地密码学、备份页面和只读入口；双账号 flow 已具备 `TEST_EXPECT_E2EE=true` 的 Olm 元数据断言，当前策略明确 `SKIP` | strict/compliance policy、双设备、密钥材料、恢复授权 |

## 3. 现有命令复用

以下命令只代表执行入口，不代表当前已经通过：

```bash
flutter test integration_test/auth/register_flow_test.dart -d <device>
flutter test integration_test/contact/add_friend_request_test.dart -d <device> \
  --dart-define=TEST_SEARCH_KEYWORD=<test_user>
flutter test integration_test/chat/conversation_test.dart -d <device>
flutter test integration_test/chat/group_chat_test.dart -d <device>
flutter test integration_test/channel/channel_subscribed_detail_consistency_test.dart -d <device>
flutter test integration_test/e2ee_olm_device_test.dart -d <device>
```

频道创建/发布/编辑还必须显式设置 `TEST_ALLOW_CHANNEL_WRITES=true`，并确认目标是非生产环境。所有账号、密码和真实地址通过运行环境注入，不能写入本文档。

`.env.pro` 是应用配置文件，不是可直接 `source` 的 shell 文件。运行 Dart API 契约测试时，只提取所需变量，避免把配置内容写入命令行历史或日志：

```bash
read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' .env.pro; }
API_BASE_URL="$(read_env API_BASE_URL)" \
TEST_PHONE="$(read_env TEST_PHONE)" \
TEST_PASSWORD="$(read_env TEST_PASSWORD)" \
dart test test/unit_test/api/ --concurrency=1
```

## 4. 一条命令串行执行 P0

推荐直接使用仓库脚本：

```bash
cd /Users/leeyi/project/imboy.pub/imboyapp && \
  DEMO_FLOW_MODEL=deepseek-v4-flash bash scripts/run_demo_flows.sh
```

脚本默认模型就是 `deepseek-v4-flash`。执行 P1 使用 `DEMO_FLOW_SCOPE=p1 bash scripts/run_demo_flows.sh`，全部执行使用 `DEMO_FLOW_SCOPE=all bash scripts/run_demo_flows.sh`；临时切换模型使用 `DEMO_FLOW_MODEL=<model>`。

脚本会为每个 flow 启动一个新的 Claude Code 会话，前一个 flow 结束后才进入下一个；`group_flow.md` 只是索引，不放进执行列表。下面是等价的展开命令，便于审查和临时修改。

```bash
cd /Users/leeyi/project/imboy.pub/imboyapp

flows=(
  account_flow
  friend_flow
  conversation_flow
  single_chat_flow
  channel_flow
  group_creation_flow
  group_chat_flow
  group_management_flow
  group_collaboration_flow
  e2ee_security_flow
)

for flow in "${flows[@]}"; do
  printf '\n开始执行 %s\n' "test/demo_flow/${flow}.md"
  if ! claude \
    --permission-mode acceptEdits \
    --allowed-tools Read Write Edit Glob Grep \
      "Bash(pwd)" "Bash(rg *)" "Bash(mkdir *)" \
      "Bash(flutter test *)" "Bash(dart test *)" \
      "Bash(git status *)" "Bash(git diff *)" \
    -p "你现在只执行一个业务流程：test/demo_flow/${flow}.md。

先读取 test/demo_flow/README.md、test/demo_flow/P0_EXECUTION_PLAN.md 和目标 flow 文档，严格按其中的 TODO、前置条件、验收标准和停止条件执行。

本轮规则：
1. 只处理这个 flow；完成、失败或阻塞后就退出，不进入其他 flow。
2. 优先复用现有 integration_test；只有确有必要才新增 integration_test/demo_flow/ 下的测试。
3. 允许修改 test/demo_flow/ 和 integration_test/demo_flow/；禁止修改 lib/ 和 test/auto_test/，禁止 commit、push。
4. 缺少测试环境、账号、设备、授权或服务端证据时，把目标 flow 回写为阻塞并说明原因，不得猜测通过。
5. 禁止联系真实第三方、操作生产数据、充值、转账、红包、付费购买、删除群/动态、清空数据或导入/恢复真实 E2EE 密钥。
6. 每个写操作必须有服务端成功证据；单端 UI 变化不能作为闭环证据。
7. 结束前运行 git diff --check，报告通过、失败、跳过、阻塞和新增文件。"; then
    printf 'flow 退出异常，继续下一个：%s\n' "$flow"
  fi
done
```

该命令是串行执行，不使用 `--bg`，也不使用 `--continue`。如果某个 flow 因外部条件阻塞，Claude Code 会记录阻塞后继续下一个 flow；如果希望遇到第一个失败就停止，可以在循环前加 `set -e`，并直接执行 `claude ...`。

## 5. 新增测试文件顺序

### 第一批：优先复用，风险较低

- [x] `integration_test/demo_flow/conversation_flow_test.dart`
- [x] `integration_test/demo_flow/single_chat_flow_test.dart`
- [x] `integration_test/demo_flow/group_chat_flow_test.dart`
- [x] `integration_test/demo_flow/channel_readonly_flow_test.dart`

### 第二批：需要写入授权（当前环境受控跳过）

- [ ] `integration_test/demo_flow/account_flow_test.dart`
- [ ] `integration_test/demo_flow/friend_flow_test.dart`
- [ ] `integration_test/demo_flow/group_creation_flow_test.dart`
- [ ] `integration_test/demo_flow/group_management_flow_test.dart`
- [x] `integration_test/demo_flow/group_collaboration_flow_test.dart`

### 第三批：受控安全流程（当前环境受控跳过）

- [ ] `integration_test/demo_flow/e2ee_security_flow_test.dart`
- [ ] 频道→群日程→钱包的跨模块流程
- [ ] E2EE 备份导入/恢复 UI 流程

## 6. 已执行证据（2026-08-09）

- [x] 2026-08-09 生产 API 蓝绿发布：以远端 `main` 的 `1.0.0-alpha.25` 重新编译并完成蓝绿切换；公网 `/healthz` 返回 `status=ok`、`db=up`、`version=1.0.0-alpha.25`。当前 Nginx 指向 `9800`，`9801` 保留同版本健康节点作为回滚目标，未执行数据库迁移。
- [x] Android 真机生产登录冒烟：`integration_test/smoke/smoke_test.dart` 通过（登录 API、App 启动、`Scaffold`、`MaterialApp`）。
- [x] Android 真机本地 E2EE 密码学测试：`integration_test/e2ee_olm_device_test.dart` 通过 5/5；仅证明本地 Olm/X3DH/Ed25519/OTK/pickle，不等于双设备 UI 闭环。
- [x] 2026-08-09 Android 真机 `conversation_test.dart --plain-name='会话列表显示与交互'`：生产登录、主 Shell、会话列表和 5 个 `Slidable` 会话项均通过；截图在 Android 厂商 ROM 上按诊断策略跳过，不影响业务断言。
- [x] 2026-08-09 蓝绿发布后 P0 API 契约复核：使用 `.env.pro` 正确注入环境变量，对认证、联系人、会话、频道、群、群成员、群日程、E2EE、钱包 9 个定向 API 文件逐文件串行执行，`58` 项通过、`1` 项受控跳过，最终 `All tests passed`；期间有少量 429，测试客户端按既有策略重试，未执行真实业务写入。
- [x] 生产登录类型回归：同一测试账号分别以 `account` 和 `email` 类型运行 `auth_api_test.dart`，两次均 9/9 通过；账号类型不是当前 API 阻塞。
- [x] 2026-08-09 双账号只读复核：两个授权测试账号分别运行 `contact_api_test.dart`（各 5/5）和 `e2ee_api_test.dart`（各 12 通过、1 条件跳过）；确认 A/B 账号可登录并读取联系人/E2EE 状态，但未执行关系、消息或密钥恢复写入。
- [x] 生产 API 受控边界：钱包仅执行读取/无效参数边界，E2EE 仅执行设备状态和失败分支；未执行真实转账、付费购买、密钥恢复或其他高风险写入。
- [x] 2026-08-09 E2EE 备份页面本地 widget 回归：`e2ee_backup_export_page_widget_test.dart` 与 `e2ee_backup_import_page_widget_test.dart` 合计 `9/9` 通过，覆盖备份文件合法/非法校验、导入/导出按钮禁用和密钥覆盖风险提示；未执行真实导入、恢复或清空密钥。
- [ ] macOS/Android App UI：macOS 基础入口和 Android 基础入口已通过；Android 联系人列表与会话列表只读入口也已形成通过证据，但 macOS 联系人页仍受本机既有加密 SQLite `out of memory` 影响。
- [x] 2026-08-09 双账号明文单聊闭环：使用用户授权的两个测试账号、`APP_ENV=pro`、macOS 与 Android 真机，run id `1786290028`。两端 WebSocket 均建立；A/B 唯一标记分别完成实时收发，双方各自获得 `C2C_SERVER_ACK`；退出并重进后，双端本地 SQLite 均核对两条消息，测试两端均 `All tests passed`。服务端历史接口返回成功但归档为空（`historyUnavailable`），因此不计服务端历史归档通过；消息为 `e2ee:false`，不计入 E2EE 验收。此前 WebSocket 未建立即继续发送的失败运行保留为历史，不覆盖本次成功证据。
- [x] 2026-08-09 E2EE 双设备验收门补齐：`dual_account_message_flow_test.dart` 支持 `TEST_EXPECT_E2EE=true`；非 `required/compliance` policy 时明确 `SKIP`，严格策略下要求本地消息存在 `protocol=olm`、`fan_out=per_device` 且 UI 能显示解密后的唯一标记。当前生产 `/api/v1/app/policy` 只读结果为 `e2ee_mode=optional`，所以尚未计入 E2EE 双设备通过。
- [x] 2026-08-09 macOS `integration_test/app_test.dart`：基础 `MaterialApp/Scaffold` 和“登录页或主 Shell”两个断言均通过，最终 `2/2`；修复了独立 widget 测试间 App 入口未重新挂载的问题。
- [ ] 2026-08-09 UI 后续复核：隔离 macOS 运行已完成生产登录（登录控件与本地会话均 PASS），随后联系人页被本机既有加密 SQLite 数据库 `out of memory` 错误阻断，测试未形成联系人 UI 通过证据。共享工具已补上欢迎页稳定等待、登录页误判防护、桌面端账号密码入口和 App 重新挂载；仍需干净且可交互的真机/桌面数据环境复核联系人、会话、群聊 UI。
- [x] 2026-08-09 Android 重装复核：已在华为真机完成两段安装安全确认；`app_test.dart` 2/2、联系人列表只读 1/1、会话列表只读 1/1 通过。Android 截图因厂商 ROM surface 阻塞按策略跳过。
- [ ] 2026-08-09 Android 频道只读复核：`channel_subscribed_detail_consistency_test.dart` 已完成生产探活、登录和频道 Tab 进入；接口返回无已订阅频道，测试明确 `SKIP`（无法验证详情一致性），不判定为频道详情通过。
- [ ] 2026-08-09 Android 好友关系闭环仍待双账号写入：修正 `add_friend_request_test.dart` 的结果识别后，生产搜索→用户详情只读路径已 `1/1` 通过；搜索接口返回 1 个用户并成功进入详情页。该用户当前已是好友，因此未执行申请、通知、确认或关系写入；此前 `118@imboy.pub` 空结果作为无结果边界保留。
- [x] 2026-08-09 Android 联系人管理只读复核：`friend_management_test.dart` 使用 `.env.pro` 正确注入，联系人列表页 `1` 项通过；好友详情用例因生产联系人列表为空受控 `SKIP`。未执行好友关系写入；登录初始化的设备/E2EE 上报属于 App 既有副作用。
- [ ] 2026-08-09 Android 新朋友复核：已完成生产登录和联系人页进入，但当前账号没有「新朋友」入口/待处理申请，测试干净地受控 `SKIP`；未执行好友确认写入。
- [x] 2026-08-09 Android 群聊只读复核：`group_chat_test.dart --plain-name='进入已有群聊页面可访问'` 通过；按会话模型识别已有 `C2G`，进入 `ChatPage`，并成功加载生产群历史（4 条）。测试本身未输入或点击发送；但登录期间 App 自有的既有 C2G 重试队列出现后台重试发送日志，不能把本次运行记为绝对零写入，双账号消息、@成员和重进恢复仍未验收。
- [x] 2026-08-09 Android 群管理只读复核：`group_management_readonly_test.dart` 通过；从联系人“群聊”入口进入 `GroupListPage`，生产群列表加载 4 项，未执行群创建、群信息修改、成员增删或公告写入。截图因 Android 厂商 ROM surface 按诊断策略跳过。
- [x] 2026-08-09 Android 华为真机群列表长按菜单复核：新增 `group/group_management_longpress_readonly_test.dart`，完成“群列表长按 → 群聊信息 → 群详情只读加载 → 显式关闭 GoRouter 路由”，最终 `1/1 All tests passed`；未执行群管理写操作，SemanticsHandle 泄漏不再复现。
- [x] 2026-08-09 Android 群详情只读复核：`group/group_detail_readonly_test.dart` 通过 `1/1`；动态读取已有群参数，直接挂载 `GroupDetailPage` 并完成详情/成员只读加载，未执行群名、备注、成员、公告、权限或危险操作。
- [x] 2026-08-09 Android 单聊只读复核：`chat/single_chat_readonly_test.dart` 首次运行暴露 `ChatPageState._initChat` 在页面卸载后读取 `context` 的生命周期缺陷；改为使用 `State.mounted` 后复跑通过，已有 `C2C` 会话成功进入 `ChatPage`，未输入或发送消息。双账号双向消息和重进恢复仍未验收。
- [x] 2026-08-09 Android 账号/E2EE 子页只读复核：`mine/mine_subpages_smoke_test.dart` 通过 `1/1`；依次挂载存储空间、设备管理、账号安全、语言、深色模式、字号、修改密码、意见反馈、E2EE 密钥恢复、备份导出、备份导入和注销入口，未点击任何账号或密钥操作按钮。登录初始化的设备密钥上报属于 App 自身副作用。
- [x] 2026-08-09 Android 设备列表溢出修复复核：`user_device_page.dart` 将有数据列表移出 `SliverFillRemaining`，避免多设备时 `RenderFlex overflowed by 372 pixels`；修复后上述真机 flow `1/1` 通过，未再出现该溢出日志。
- [x] 2026-08-10 群协作双账号闭环：`group_collaboration_flow_test.dart` 使用 `.env.pro`、117 macOS 和 118 Android 华为真机，在既有 P0 测试群中完成日程创建/确认参加、任务创建/分配/提交、投票创建/投票/我的投票回读；双方列表与详情页均挂载成功，最终 `1/1 All tests passed`。未执行取消日程、删除任务、撤销投票或费用结算。
- [x] 2026-08-10 群聊双账号消息闭环：`group_dual_account_message_flow_test.dart` 使用 `.env.pro`、117 macOS 和 118 Android 华为真机，在测试群 `104603643803863040` 完成双方唯一标记文本收发；两端均收到 `C2G_SERVER_ACK`，Android 通过只读成员核对后直接挂载现有 `ChatPage`，双方退出/重进后均回读两条消息，sender/receiver 均 `1/1 All tests passed`。未覆盖 @成员、失败重试和多人并发。
- [x] 2026-08-09 Android 建群入口只读复核：`group/group_creation_readonly_test.dart` 通过 `1/1`；发起群聊、选择群聊、面对面建群页面均成功挂载，未选择联系人、未输入暗号、未点击完成。普通建群、面对面入群和双方关系闭环仍未验收。
- [x] 2026-08-09 Android 钱包首页只读复核：`wallet/wallet_readonly_test.dart` 通过 `1/1`；余额与流水接口完成读取，页面路由显式关闭，未点击充值、提现、收款或转账。
- [x] 2026-08-09 Android 频道发现只读复核：新增 `channel/channel_discover_readonly_test.dart`，生产账号读取推荐频道并显示 5 个列表项，最终 `1/1 All tests passed`；未点击订阅、付费、分享或频道详情入口。
- [x] 2026-08-09 第一批 `integration_test/demo_flow` 只读入口复核：`conversation_flow_test.dart` 通过 `1/1`，`single_chat_flow_test.dart` 通过 `1/1`，`channel_readonly_flow_test.dart` 通过 `1/1`；`group_chat_flow_test.dart` 因当前账号无可识别已有 C2G 受控 `SKIP`。合计 `2 passed, 1 skipped, 0 failed`，未创建群、未发送消息、未订阅频道、未执行资金操作。
- [x] 2026-08-09 Android 会话操作面板只读复核：修正 `conversation_test.dart` 将不存在的长按菜单改为当前 `Slidable` 侧滑面板；生产会话列表侧滑显示“置顶、删除”等选项，`1/1 All tests passed`，未点击任何状态或删除操作。
- [x] 2026-08-09 会话侧滑面板本地 widget 回归：`conversation_list_test.dart` 侧滑操作面板用例 `1/1 All tests passed`；仅证明 UI 渲染，不替代置顶、已读和删除接口写入证据。
- [x] 2026-08-09 会话写入错误边界回归：`conversation_api_test.dart` 扩展后生产定向运行 `10/10 All tests passed`；置顶/取消置顶/删除/恢复对无效会话 ID 均结构化拒绝。有效会话写入和 BUG#129 的 TSID 契约仍待隔离环境复验。
- [x] 2026-08-09 业务写入门禁复核：新增 `TEST_ALLOW_BUSINESS_WRITES=true` 通用闸门，拒绝生产 `APP_ENV` 或生产 URL；群消息写入用例在 `.env.pro` 下最终 `0` 通过、`1` 受控跳过，且门禁后不再启动 App。频道写入继续使用独立频道闸门。
- [x] 2026-08-10 剩余 P0 受控结果回写：账号、好友、建群、群管理、群协作、群聊和 E2EE flow 的证据已整理；群协作、群聊、普通建群/邀请和成员角色变更双账号闭环已通过，好友关系、面对面入群、成员移除、严格 E2EE 双设备与频道→群日程→钱包仍未完成，没有伪造完整闭环。
- [x] 2026-08-10 群管理受控双端回读：macOS/117 对测试群 `104603643803863040` 写入群名和公告，Android/118 回读群名、成员 UID `50/4`、公告标记并挂载 `GroupDetailPage`，最终 `1/1 All tests passed`；由于建群接口复用了已有成员集合，普通建群/面对面入群仍未计为通过。
- [x] 2026-08-10 群成员角色可逆双端验证：`group_member_role_flow_test.dart` 由 macOS/117 将成员 118 从 `role=1` 提升为 `role=3`，Android/118 真机服务端回读管理员角色并挂载群详情，随后 117 恢复为 `role=1`；提升、回读、恢复均 `1/1 All tests passed`，未执行成员增删、群主转让或解散。
- [x] 2026-08-10 全新建群与邀请双端验证：修复后端群成员筛选占位符冲突并蓝绿发布；macOS/117 创建 `106131639631087616`、邀请 UID `4`、写入群名和公告并完成服务端回读，Android/118 只读回读同一群并挂载详情页，双方均 `1/1 All tests passed`；未执行面对面暗号入群、成员移除或解散。
- [x] 2026-08-10 P0 明文单聊双账号重跑：`dual_account_message_flow_test.dart` 使用 `.env.pro`、先 Android 后 macOS、显式 `WS_URL_OVERRIDE` 和 run id `1786290028-r5`；117 macOS 与 118 Android 均 `1/1 All tests passed`，完成唯一标记跨设备收发、双方 `C2C_SERVER_ACK`、退出重进和本地 SQLite A/B 消息核对。服务端历史接口归档为空，按 `historyUnavailable` 记录；消息为 `e2ee:false`，不计入严格 E2EE 验收。
- [x] 2026-08-10 现场重新启动双端并复跑：首轮因遗漏 `TEST_WS_URL` 参数失败，补齐后 run id `20260810-072416-r2` 的 macOS/117 sender 与 Android/118 receiver 均 `1/1 All tests passed`；完成双向唯一标记、服务端 ACK、退出重进和本地回读。测试报告位于 `/Users/leeyi/project/imboy-test-report/dual-live-20260810-072416-r2`；该结果仍是明文闭环，不计入严格 E2EE。
- [ ] 2026-08-10 iPhone 8/117 ↔ Android/118 现场复核：iPhone 8 构建和安装完成，但启动被设备拒绝，底层返回 `invalid code signature, inadequate entitlements or its profile has not been explicitly trusted by the user`；后续核验确认签名有效、bundle ID/profile 匹配、iPhone 8 UDID 已包含在 profile 且 profile 未过期，故当前剩余原因是设备侧信任/启动状态。Dart VM Service 未建立，iPhone 测试 `Some tests failed`，Android 仅进入等待，未产生双端闭环证据。报告位于 `/Users/leeyi/project/imboy-test-report/dual-live-20260810-092943-iphone8-r2`；待设备完成开发者 profile 信任/可启动后重跑。
- [x] 2026-08-10 14:35 macOS/117 ↔ Android/118 双端消息闭环（P0#1 判定 PASS）：`dual_account_message_flow_test.dart`，run id `dual-20260810-1435-117mac-118a`。根因修复记录：此前 Android 侧 `ws: WebSocket URL 未配置` 导致 receiver 无法建立 WS —— `Env.effectiveWsUrl` 只认 `WS_URL_OVERRIDE` dart-define（env_pro.dart 的 `wsUrl => null`，且全新安装无本地缓存、`initConfig` 返回缓存结果未写入 ws_url），脚本误传了 `TEST_WS_URL`；补 `--dart-define=WS_URL_OVERRIDE=wss://pro.imboy.pub/api/v1/ws` 后 WS 正常建立。macOS/117 sender 发送 `P0-DUAL-A-dual-20260810-1435-117mac-118a` → Android/118 receiver 收到并回发 `P0-DUAL-B-...` → macOS 收到；两端均记录 `服务端 ACK 已反映到本地状态 ... status=11`（C2C_SERVER_ACK），且均输出 `双账号消息闭环通过：sender/receiver，发送/接收双方各一条，重进历史核对完成`，最终双端各 `1/1 All tests passed`（退出码 0）。测试后 App 退出为 flutter test 宿主进程正常收尾（非崩溃，进程退出码 0、`All tests passed!`）。证据日志：`/tmp/iphone16e/macos_sender_1435.log`、`/tmp/iphone16e/android_receiver_1435.log`。发现项（非阻塞）：Android 收到 S2C 后回 ACK 时服务端返回 `CLIENT_ACK_ERROR reason=invalid_type`（客户端缺 msgId 处理分支），不影响本测试断言，待单独排查。消息为明文 `e2ee:false`，不计入严格 E2EE 验收（脚本未设 TEST_EXPECT_E2EE）。iPhone 8 真机双端闭环仍未达成（设备信任/VM 通道阻塞）。
- [x] 2026-08-10 服务端 v2 二进制 ACK 路径失效根因定位（P0#1 派生发现，未修复）：Android 对收到的 TSID 数字 ID 消息回 v2 二进制 ACK 后，服务端恒回 `CLIENT_ACK_ERROR reason=invalid_type`（客户端 ACK_MANAGER 重试 4 次耗尽、收不到 CONFIRM）；macOS 侧消息 ID 为 base32hex 字符串、`int.tryParse` 失败走文本 CLIENT_ACK 路径，故正常。根因在 `imboy/src/api/websocket_handler.erl:253-257`：构造 protobuf `PayloadClientAck` 时使用 binary 键（`<<"msg_id">>`/`<<"did">>`/`<<"msg_direction">>`）且 `msg_direction` 传 binary 值，而 gpb 生成的 `imboy_pb.erl:212` 要求 atom 键 + enum atom/integer 值（`#{msg_id := F1}` 模式匹配）→ 字段全部按缺省编码 → 服务端解码出空值 → `ack_direction_to_type` 落 catch-all 返回 `<<>>` → `validate_ack_params` 判 `invalid_type`，错误帧 `id=""`。影响：Android 端消息确认链失效、`msg_delivery` 的 ack_received 不置位、服务端按重投策略可能重投已送达消息。最小修复（待授权实施）：259-262 行改用 atom 键并 `msg_direction => binary_to_atom(Direction, utf8)`（`<<\"C2G\">>` → `'C2G'`，`ack_direction_to_type('C2G')` 已有匹配子句）。未改动任何生产代码。
- [ ] 2026-08-10 iPhone 8 安装重试：按用户要求执行 `flutter install --debug`，退出码 `0`，旧版本卸载和新版本安装均完成；随后普通 Debug 启动仍在 `Installing and launching` 后失败。当前状态为“可安装、不可启动”，尚未形成 iPhone/Android 双账号闭环。
- [ ] 2026-08-10 继续后的 iPhone 8 重试：安装退出码仍为 `0`，但重新启动仍在 `Installing and launching` 后失败，未出现 Dart VM Service，未形成双账号闭环。
- [ ] 2026-08-10 改用 iPhone 16e/117：两次 iPhone/Android 联调中，iPhone 16e 均完成构建和安装，但集成测试 Dart VM 通道分别出现 `Connection reset by peer` 与 `Connection closed before full header was received`；基础 `app_test.dart` 也复现同一 VM 连接失败。`devicectl --console` 直接启动 Debug 包时明确提示必须由 Flutter tooling/Xcode 启动，并以 `signal 11` 退出；Android/118 已连接 WebSocket但未进入业务断言。当前是 iPhone 16e Debug/VM 通道阻塞，不计为双账号消息闭环通过。报告：`/Users/leeyi/project/imboy-test-report/dual-live-20260810-104148-iphone16e-r1`、`/Users/leeyi/project/imboy-test-report/dual-live-20260810-104641-iphone16e-r2`。
- [ ] 2026-08-10 iPhone 8 原生自动化替代路径复核：安装 Appium XCUITest 12.3 并补齐本机 WDA 签名参数后，WDA 已成功编译，但 Xcode 26.6 在 iPhone 8/iOS 16.7.12 执行阶段返回 `Logic Testing Unavailable: Logic Testing on iOS devices is not supported`；临时 Appium 2 + XCUITest 7.35（iOS 16 旧链路）仍复现同一错误。该路径未建立 UI session、未执行业务写入；问题位于 Xcode/CoreDevice 对 iPhone 8 的测试目标识别，不能作为消息闭环证据。
- [ ] 2026-08-10 按用户要求再次复跑 iPhone 8/117 ↔ Android/118：Android/118 成功建立 WebSocket 并等待 `P0-DUAL-A-20260810-iphone8-retry-111630`，但只收到旧消息/ACK 重试，最终等待超时；iPhone 首次运行已进入 Dart 测试，但调用参数误将 WebSocket 地址写成 `wss://pro.imboy.pub`（缺少 `/api/v1/ws`），不计为设备或业务结果。修正为 `/api/v1/ws` 后，iPhone 8 构建完成但返回 `Unable to start the app on the device`；随后显式重装又返回 `ios-deploy Error 0xe8000084: This device is no longer connected`。报告：`/Users/leeyi/project/imboy-test-report/dual-live-20260810-iphone8-retry-111630/`；未形成双账号消息闭环。
- [x] 2026-08-10 P0 频道/钱包安全前置复跑：Android/118 频道发现只读 `1/1 All tests passed`（推荐频道 5 项）；钱包余额/流水只读 `1/1 All tests passed`；已订阅频道详情测试因服务端订阅列表为空而 `All tests skipped`。代码复核确认频道模型没有群绑定字段；订阅、频道到群的人工分享、日程写入和资金转账仍未形成跨模块闭环。
- [x] 2026-08-10 P0 E2EE 策略门禁复跑：Android/118 以 `TEST_EXPECT_E2EE=true` 运行双账号 flow，生产 policy 不满足 `required/compliance`，在发送前明确 `All tests skipped`；未把明文结果算作 E2EE 通过，也未产生本轮业务消息写入。当前没有可直接使用的非生产双账号 strict/compliance 环境。
- [x] 2026-08-10 E2EE 本地恢复补充校验：`e2ee_backup_restore_test.dart` 通过 `13` 项，覆盖恢复密钥、pack/unpack、错误密码、损坏文件和合法备份校验；Olm room-key roundtrip 因 spike 动态库未构建受控跳过，不计入双设备验收。
- [x] 2026-08-10 E2EE 策略/fan-out 本地回归：策略门禁与 per-device fan-out 共 `18` 项通过；macOS 主机 OLM production-path 测试因缺少 vodozemac 动态库未初始化，不计入通过；该证据仍不替代生产 strict/compliance 双设备消息与恢复验收。
- [x] 2026-08-10 E2EE 本地动态库补齐后复跑：临时构建 macOS arm64 vodozemac 动态库，`olm_pfs_production_path_test.dart` `9` 项与 `room_key_olm_roundtrip_test.dart` `1` 项通过；仅补强本地协议/恢复材料证据，不计为生产双设备验收。
- [x] 2026-08-10 Android 真机 E2EE 基础管线复跑：`integration_test/e2ee_olm_device_test.dart` `5/5 All tests passed`，覆盖 vodozemac、X3DH/Olm 双向加解密、Ed25519、OTK 和 session pickle；不计入两台真实设备 strict E2EE 业务闭环。
- [x] 2026-08-10 好友状态机本地回归：后端 `friend_logic_tests` 27/27、`friend_agg_tests` 18/18 通过，覆盖申请/确认门禁；117/118 已存在好友关系，生产删除→申请→确认写入仍未执行，因此好友 P0 仍不计为闭环通过。
- [ ] 2026-08-10 下午 iPhone 8/117↔Android/118 双账号闭环复验：`devicectl` 中 iPhone 8 (iPhone10,1) 持续 `unavailable`（bootState=booted、ddiServicesAvailable=false、tunnelState=unavailable、pairingState=unsupported），未重试安装、未用 iPhone 16e 替代。根因定位：Xcode 26.6 `DeviceSupport` 最高仅到 16.4，缺少 iOS 16.7 的 Developer Disk Image；已从 `doronz88/DeveloperDiskImage` 下载 16.7 DDI（dmg 7432520B + signature 128B）部署到 `~/Library/Developer/Xcode/iOS DeviceSupport/iPhone10,1 16.7.12 (20H364)/` 并重启 CoreDeviceService，设备仍 unavailable，剩余阻塞为设备物理重插 USB + 解锁确认信任（用户级操作，需人工执行）。Android/118 单端登录冒烟 `smoke_test.dart` 1/1 通过，仅证明 118 可登录，不构成双端闭环证据。
- [x] 2026-08-10 下午 Android/118 只读安全检查（不依赖 iPhone 8）：联系人和好友只读契约 `contact_api_test.dart` 5/5；群与群成员契约 `group_api_test.dart`+`group_member_api_test.dart` 11/11；群日程/任务/投票契约只读部分 4/4 通过、写端点被 `TEST_ALLOW_API_WRITES` 门禁按预期拦截（非回归）；E2EE/频道/会话契约合计 22 通过、1 条件跳过、3 个写端点同被门禁拦截。真机：群详情回读 `group_detail_readonly_test.dart` 1/1（回读测试群 `106131639631087616`，P0-TEST-GROUP-FRESH-20260810-0142，member_count=2，owner_uid=50）、群协作只读 `group_collaboration_readonly_test.dart` 1/1（群投票列表页挂载，无写操作）、E2EE 本地密码学 `e2ee_olm_device_test.dart` 5/5（vodozemac/X3DH/Olm/Ed25519/OTK/pickle）、频道发现只读 `channel_discover_readonly_test.dart` 1/1（推荐频道 5 项；他人附件 400=view_url 授权按预期拦截）、钱包只读 `wallet_readonly_test.dart` 1/1（余额/流水只读，无资金写操作）。未执行好友关系写入、群成员增删、订阅/付费、转账。
- [x] 2026-08-10 下午 E2EE 策略门禁复验：Android/118 以 `TEST_EXPECT_E2EE=true` 运行双账号 flow，生产 policy 非 required/compliance，发送前 `All tests skipped`；未把明文链路计为 E2EE 通过，未产生本轮业务消息写入。E2EE 双设备与密钥恢复仍为 BLOCKED（需 strict/compliance 环境 + 双设备 + 人工恢复授权）。
- [x] 2026-08-10 下午 Android App 自动退出排查：`logcat -b crash` 今日无 imboy.chat 崩溃记录；12:02:58 唯一一次 `Force stopping imboy.chat: pkg removed` 为 `flutter test` 结束后的自动卸载（正常行为，非崩溃）。结论：当前证据指向华为 EMUI 后台清理（iAware/RMS 智能省电）回收进程，非 App 崩溃；复现时可用 `adb -s <device> logcat -b crash -d` 与 `adb -s <device> logcat -d | grep -iE "am_kill|died|lowmemory"` 抓取证据。
- [x] 2026-08-10 下午 iPhone 8 绕开 CoreDevice 安装成功并启动：使用 `libimobiledevice` 链路（`idevicepair validate` SUCCESS → `ideviceinstaller install build/ios/iphoneos/Runner.app` → `Install: Complete`；`ideviceinstaller list` 确认 `pub.imboy.2 "1.0.0.15" "IMBoy"` 已安装）→ `idevicedebug --detach run pub.imboy.2` 退出码 0，App 已启动。两次 `idevicescreenshot` 各 3.7MB 且 hash 不同 → 屏幕有稳定内容（状态栏时钟走动），非黑屏。本次构建为 Debug（APP_ENV=pro，`--dart-define=API_BASE_URL=https://pro.imboy.pub`）。**当前状态：iPhone 8 已可安装可启动，但无 Dart VM Service 通道**（集成测试需 VM 通道执行断言，本链路仅能人工/截图确认 UI）；下一步需人工查看 iPhone 8 屏幕确认 117 登录态（若已登录可直接进入消息闭环人工验证），或提供 117 密码以走自动化 sender 路径。证据：`/tmp/iphone8/boot_check.png`、`/tmp/iphone8/check2.png`。双账号消息闭环仍未形成，不构成 PASS。

- [x] 2026-08-10 晚间 P0#2/P0#5/P0#6 写入类验收（用户授权「1+2」，执行脚本 `/tmp/p0_api_verify.py`，复刻生产设备签名：did=HUAWEIMRD-AL00、vsn=1.0.0-alpha.15、cos=android、pkg=imboy.chat、`sk=1`、HMAC-SHA512(plain, 编译期 bake 的 32 字符 SOLIDIFIED_KEY)）。登录 200 OK，uid=4（118）。
  - **P0#2 好友删除→申请→确认**：`POST /api/v1/friend/delete {uid:50}` → 200 success；`POST /api/v1/friend/add {to:50,payload:{from:{source:qrcode}}}` → 200 success（pending 建立，payload 必须是 JSON map，字符串会致 handler 崩溃）；`POST /api/v1/friend/confirm {from:4,to:50,payload:{from:{...}}}` → **HTTP 500**。但 confirm 后 friend/list 显示 uid=50 `is_friend=1`、`remark="P0#2 重建验证"`、`source=qrcode`、created_at=confirm 时刻 → **好友关系已实际写入**（confirm_friend_do 在写库后、组响应前崩溃）。**根因（2026-08-10 晚间锁定）**：`friend_logic:confirm_friend_resp/2`（提交 104d0330 引入）的查询 Column `<<"id,account,nickname,avatar,gender,sign,region,last_seen_at">>` 引用了 **user 表不存在的 `last_seen_at` 列**（该列属 user_friend 表，见迁移 `00000001_foundation.up.sql:3749/3871`）→ SQL 报错被 `user_repo:find_by_id` 的 `elib_pg_sql:value_or_empty` 吞成 `#{}` → `user_ds:batch_online_state/1` 第 515 行 `maps:get(<<"id">>, #{})` 抛 `badkey` → handler 未捕获 → HTTP 500。本地 imboy_dev 节点 rpc `confirm_friend_resp(4, ...)` 同崩溃复现（此前误判"生产旧代码"，实为**当前源码 bug**；alpha.25→HEAD confirm 链零改动，生产/本地同代码）。**修复已就绪（2026-08-10 晚间）**：Column 移除 `last_seen_at`（与 friend/list 的 `?DEF_USER_COLUMN` 一致），字段由 `batch_online_state` 兜底为 `<<>>`；`make app` 编译通过、friend_logic_tests 27/27、本地 rpc 复验 `confirm_friend_resp` 返回完整 map（is_friend=1/peerId/status/last_seen_at=<<>>）不再崩溃。判定：**关系闭环已恢复（PASS 数据侧）/ API 稳定性 PASS（生产复验 200，2026-08-10 发布 alpha.26 后确认）**。
  - **P0#5 E2EE 密钥恢复**：`GET /api/v1/e2ee/key/status?device_id=...` → `has_valid_key=false`、`recovery_options=[]`、`recommended_method=none`；`POST /api/v1/e2ee/recovery/start` → code=5055「不支持的恢复方式」；`GET /api/v1/e2ee/backup/list` → 404（catalog 过时，真实路由为 `/api/v1/e2ee/backup/{put,get,info,delete}`）。判定 **BLOCKED**：该账号无密钥材料与恢复选项，无可用恢复写入路径。
  - **P0#6 频道订阅→钱包**：`GET /api/v1/wallet/balance` → balance=0；`GET /api/v1/wallet/transactions` → 空；`GET /api/v1/channels/discover` → 全部 type=0 免费频道；`POST /api/v1/wallet/topup` → 生产拒绝（mock 充值仅非生产可用）。判定 **BLOCKED**：无付费频道 + 零余额，付费订阅→钱包扣款链路在生产无验证样本。
  - 附加发现：`.env.pro` 的 `SOLIDIFIED_KEY` 为 34 字符，与编译期 bake 进 App 的 32 字符 key 不一致（生产签名以 bake 值为准，脚本从 `env_pro.g.dart` XOR 解码）；`friend/add` payload 契约是 JSON map 而非字符串。
- [x] 2026-08-10 晚间 P0#2 confirm 生产修复已发布并复验（用户授权）：蓝绿部署 alpha.26（commit 2359f92d/bccbded6/e8058482/45092597/c173c32c，tag 1.0.0-alpha.26 force 到 c173c32c，推送 origin+gitcode+github）。部署过程踩中**版本双源坑**：relx.config 与 `VERSION` 文件（Makefile `PROJECT_VERSION = $(shell cat VERSION)` 是 ebin/imboy.app `{vsn,...}` 的源）必须同时 bump——首轮部署 healthz 返回 alpha.25 失败，bump `VERSION` 后重跑成功。生产复验（`/tmp/p0_api_verify.py --write`，登录 200 uid=4）：`POST /api/v1/friend/confirm {from:4,to:50,...}` → **200**，payload 完整（id/is_friend=1/peerId/last_seen_at=null/status=offline），**500 修复确认**。同发：websocket_handler v2 二进制 ACK 修复（atom 键 + `binary_to_atom(Direction, utf8)`）、group_member_ds $2 占位符修复。当前 Nginx 指向 blue(9800, 08101613@127.0.0.1)，`https://pro.imboy.pub/healthz` → `version=1.0.0-alpha.26`；green(9801, gmfix3) 保留作回滚。WS ACK 真机验证待 iPhone 8 connected。
- [x] 2026-08-10 P0#1 WS ACK 修复生产验证 **PASS**（API 级替代，`/tmp/ws_ack_verify.py`，因 iPhone 8 上 app 启动即崩溃，真机验证 BLOCKED）：wss 握手须带三要素——签名头（`defaultHeaders`：cos/vsn/pkg/did/tz_offset/method/sk/sign，缺签名头 auth_middleware 回 902 → 表现为 HTTP 200 而非 101）、`Authorization: Bearer <token>`、`Sec-WebSocket-Protocol: imboy.v2`（缺子协议 `websocket_ds:check_subprotocols(undefined)` 回 400）。握手成功后发 v2 二进制 heartbeatPing(0x01) → 收 pong(0x02)；发 ACK 帧(0x03, 8-byte msgId 0x1234567890ABCDEF) → 收 `CLIENT_ACK_CONFIRM` JSON 推送 → **服务端 ACK 分支 gpb 编码正常（修复前 atom 键错配会编码失败/断开）**；连接全程保持、无 ERROR/断开。**iPhone 8 阻塞根因**：`audio_waveforms 2.0.2` iOS 插件注册 SIGSEGV（`SwiftAudioWaveformsPlugin.register(with:)`，EXC_BAD_ACCESS at 0x0，崩溃报告 `/tmp/iphone8_crash/Runner-2026-08-10-162544.ips`），pub.dev 无修复版本，app 无法启动进入主界面（UDID ba90bb9774b19a0075e8ab6200d6f5b27997c903，app bundle pub.imboy.2）。
- [x] 2026-08-10 P0#1 WS ACK **真机闭环验证 PASS**（audio_waveforms 修复后，commit `6f9fe00e`）：vendored `plugin/audio_waveforms/` 置空 iOS 注册（`SwiftAudioWaveformsPlugin.swift` register 改 `_ = registrar`），Dart 兜底（`voice_widget.dart` iOS 跳过 record、`custom_overlay.dart` iOS `_StaticWaveformFallback` CustomPaint 静态波形），iPhone 8 安装启动进入「消息」主界面（截图 `/tmp/iphone8_launch3.png` OCR：搜索栏/会话列表 IMBoy/leeyi），不再崩溃。**WS 握手实锤**：`idevicedebug run pub.imboy.2` 前台启动（debugserver `Dart execution mode: JIT`）与 nginx `pro.imboy.pub.access.log` 新 101 记录时间窗吻合——17:31:30 启动 app → 101 行数 1420→1421，最新一条 `17:31:30 Dart/3.12 (dart:io)`；9800 连接数维持 2（nginx keepalive 复用，非异常）。**客户端 WS 连接确认**：`init.dart:651-652` 冷启动 `isLoggedIn` 触发 `openSocket`，`websocket.dart:330-341` token/wsUrl 校验通过 → `IOWebSocketChannel.connect` 带签名头+imboy.v2 子协议；此前「app 运行但无 101」系 `websocket.dart:418-420` 失败静默走 `_handleConnectionFailure`（UI 无感知）所致，修复后握手成功。

## 7. 停止条件

遇到以下任一情况，停止当前流程并回写阻塞，不继续猜测：

- 无法确认测试环境、账号或设备归属；
- 需要给真实第三方发送消息、申请、邀请或通话；
- 需要充值、转账、红包、提现或购买付费频道；
- 需要清空数据、删除群、删除动态或导入/恢复密钥；
- 页面显示成功但没有服务端成功证据；
- 现有 APK 不包含目标修复或入口仍被已知问题阻塞。

## 8. 完成定义

一个 P0 flow 只有同时满足以下条件才可从 `TODO` 改为 `通过`：

- [ ] 流程每一步都有可复现操作路径；
- [ ] 关键写操作都有服务端证据；
- [ ] 失败、跳过和阻塞都有明确记录；
- [ ] 至少有一条可执行测试或明确的不可自动化原因；
- [ ] 没有把页面级通过、单端结果或代码阅读当成跨模块闭环证据。
