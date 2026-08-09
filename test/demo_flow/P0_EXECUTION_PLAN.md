# P0 Demo Flow 执行计划

> 本文件把 P0 业务流程与现有可执行测试对齐，供 Claude Code 逐项执行。
> 生产环境只允许登录、探活和只读验证；资金、通知、频道写入、密钥恢复等高风险动作仍不执行。
> 更新时间：2026-08-09

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
| [single_chat_flow.md](./single_chat_flow.md) | `chat/conversation_test.dart`、`chat/single_chat_readonly_test.dart`、`e2e_chat_test.dart` | 好友入口→单聊→双向消息→重进未串联 | 已通过已有 C2C 会话进入单聊页只读路径；双账号消息仍受控 | 双账号、测试消息写入 |
| [channel_flow.md](./channel_flow.md) | `channel/channel_e2e_test.dart`、`channel_publish_test.dart`、`channel_subscribed_detail_consistency_test.dart`、`channel_discover_readonly_test.dart`、`channel_api_test.dart`、`wallet/wallet_readonly_test.dart` | 频道→群聊→日程→钱包未串联 | 已通过频道发现推荐列表只读入口和钱包首页只读 UI；详情一致性因生产账号无已订阅频道而受控 `SKIP`，订阅/付费/转账仍受控 | 频道写入开关、群入口、日程数据 |
| [group_creation_flow.md](./group_creation_flow.md) | `group_api_test.dart`、`group_member_api_test.dart`、`group/group_creation_readonly_test.dart` | 普通建群、面对面建群、入群确认未串联 | 已通过三个建群入口只读页面；创建和入群受控跳过 | 第二账号/设备、建群写入 |
| [group_chat_flow.md](./group_chat_flow.md) | `chat/group_chat_test.dart`、`conversation_api_test.dart` | @成员、双向消息、失败分支未完整覆盖 | 已通过已有 C2G 会话进入群聊页和历史只读加载；继续补双账号消息 UI，但不在生产执行发送 | 双账号、群成员、通知写入 |
| [group_management_flow.md](./group_management_flow.md) | `group_member_api_test.dart`、`group/group_management_readonly_test.dart`、`group/group_detail_readonly_test.dart`、`group/group_management_longpress_readonly_test.dart` | 群名、公告、权限、成员变更写入未执行 | 群列表、长按菜单、群详情和成员只读 UI 已通过；管理写入受控跳过 | 管理员/普通成员角色 |
| [group_collaboration_flow.md](./group_collaboration_flow.md) | `group_schedule_api_test.dart`、`group/group_collaboration_readonly_test.dart` | 日程、任务、投票写入与确认未串联 | 已通过已有群进入日程/任务/投票列表页只读路径；创建/确认/回传受控跳过 | 群应用入口、测试群、写入授权 |
| [e2ee_security_flow.md](./e2ee_security_flow.md) | `e2ee_olm_device_test.dart`、`sqlcipher_migration_test.dart`、`mine/mine_subpages_smoke_test.dart` | 本地密码学、只读入口已通过；双设备握手/消息与备份恢复未形成闭环 | 已完成本地密码学、备份页面和只读入口；双设备与恢复受控跳过 | 双设备、密钥材料、恢复授权 |

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
- [ ] `integration_test/demo_flow/group_collaboration_flow_test.dart`

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
- [ ] macOS/Android App UI：macOS 基础入口和 Android 基础入口已通过；Android 联系人列表与会话列表只读入口也已形成通过证据，但 macOS 联系人页仍受本机既有加密 SQLite `out of memory` 影响，双账号写入闭环仍未执行。不能以 API 通过替代 UI 流程通过。
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
- [x] 2026-08-09 Android 群协作列表只读复核：`group/group_collaboration_readonly_test.dart` 通过 `1/1`；动态读取已有群 ID，分别挂载群日程、群任务、群投票列表并完成列表读取，未创建日程/任务/投票、未确认参加、未提交选项。创建、确认参加和结果回传仍未验收。
- [x] 2026-08-09 Android 建群入口只读复核：`group/group_creation_readonly_test.dart` 通过 `1/1`；发起群聊、选择群聊、面对面建群页面均成功挂载，未选择联系人、未输入暗号、未点击完成。普通建群、面对面入群和双方关系闭环仍未验收。
- [x] 2026-08-09 Android 钱包首页只读复核：`wallet/wallet_readonly_test.dart` 通过 `1/1`；余额与流水接口完成读取，页面路由显式关闭，未点击充值、提现、收款或转账。
- [x] 2026-08-09 Android 频道发现只读复核：新增 `channel/channel_discover_readonly_test.dart`，生产账号读取推荐频道并显示 5 个列表项，最终 `1/1 All tests passed`；未点击订阅、付费、分享或频道详情入口。
- [x] 2026-08-09 第一批 `integration_test/demo_flow` 只读入口复核：`conversation_flow_test.dart` 通过 `1/1`，`single_chat_flow_test.dart` 通过 `1/1`，`channel_readonly_flow_test.dart` 通过 `1/1`；`group_chat_flow_test.dart` 因当前账号无可识别已有 C2G 受控 `SKIP`。合计 `2 passed, 1 skipped, 0 failed`，未创建群、未发送消息、未订阅频道、未执行资金操作。
- [x] 2026-08-09 Android 会话操作面板只读复核：修正 `conversation_test.dart` 将不存在的长按菜单改为当前 `Slidable` 侧滑面板；生产会话列表侧滑显示“置顶、删除”等选项，`1/1 All tests passed`，未点击任何状态或删除操作。
- [x] 2026-08-09 会话侧滑面板本地 widget 回归：`conversation_list_test.dart` 侧滑操作面板用例 `1/1 All tests passed`；仅证明 UI 渲染，不替代置顶、已读和删除接口写入证据。
- [x] 2026-08-09 会话写入错误边界回归：`conversation_api_test.dart` 扩展后生产定向运行 `10/10 All tests passed`；置顶/取消置顶/删除/恢复对无效会话 ID 均结构化拒绝。有效会话写入和 BUG#129 的 TSID 契约仍待隔离环境复验。
- [x] 2026-08-09 业务写入门禁复核：新增 `TEST_ALLOW_BUSINESS_WRITES=true` 通用闸门，拒绝生产 `APP_ENV` 或生产 URL；群消息写入用例在 `.env.pro` 下最终 `0` 通过、`1` 受控跳过，且门禁后不再启动 App。频道写入继续使用独立频道闸门。
- [x] 2026-08-09 剩余 P0 受控结果回写：账号、好友、建群、群管理、群协作和 E2EE flow 的现有只读证据已整理；注册/关系/群管理/协作写入、双设备消息和密钥恢复均明确标记为 `SKIP` 或阻塞，没有伪造完整闭环。

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
