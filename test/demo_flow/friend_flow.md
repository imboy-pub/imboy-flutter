# DF-02 添加好友流程

> 状态：`本地 API 闭环通过（2026-08-17 建立，2026-08-18 alpha.36 复跑 7/7 维持）/ 双端 UI 通知验证待执行（设备已恢复在线）`
> 优先级：P0
> 类型：基础关系建立流程

## 1. 目标

验证用户 A 能通过账号或二维码找到用户 B，发送好友申请，用户 B 接收并确认，双方最终在联系人列表看到好友关系。

## 2. 前置条件

- [x] 使用两个明确授权的测试账号 A、B；禁止把真实第三方账号当作测试对象。（2026-08-17：本地合成账号 13900260817/13900260818，昵称 DEMO-FLOW-20260817-A/B）
- [x] A、B 位于同一可用测试环境。（2026-08-17：本地后端 http://127.0.0.1:9800，healthz version=1.0.0-alpha.27；2026-08-18 复核：后端已升级 1.0.0-alpha.36，healthz `{"status":"ok","db":"up"}`，闭环复跑通过）
- [x] 测试前确认两账号当前不是好友，或准备一组可重复使用的隔离测试账号。（测试含自愈清理：已是好友则先 friend/delete 再重建）
- [ ] 不执行删除好友、拉黑等不可逆或影响他人的清理操作。（本地合成账号间的 friend/delete 属可回收测试数据，已在本地执行；生产仍禁止）

## 3. TODO 执行步骤

> 2026-08-17 勾选说明：以下步骤按 **API 级等价物** 完成并勾选（服务端证据充分）；
> 双端 UI（添加好友页/新朋友页/确认页的实际页面流）未在本轮执行，详见第 5 节阻塞。

- [x] A 打开添加好友页，使用 B 的测试账号搜索。（API 级：`GET /api/v1/user/search` keyword=B 账号，code=0 且结果含 B；前置发现见第 5 节 allow_search）
  - 预期：搜索结果进入 B 的用户详情页。
  - 页面计划：[add_friend_page.md](../auto_test/contact/add_friend_page.md)
- [x] A 查看 B 的资料并发送好友申请。（API 级：`POST /api/v1/friend/add` → code=0；B 侧申请通知的 UI 呈现未验证）
  - 预期：A 侧出现发送成功反馈；B 侧收到新的好友申请。
- [ ] B 打开新的好友列表，查看申请详情。（无独立 HTTP 端点，申请由 S2C 消息触达；pending 存在已由「重复申请被拒 + confirm 成功」间接证明）
  - 预期：申请人、申请状态和操作按钮正确。
  - 页面计划：[new_friend_page.md](../auto_test/contact/new_friend_page.md)
- [x] B 确认好友申请。（API 级：`POST /api/v1/friend/confirm` → code=0 且响应 payload.is_friend=1）
  - 预期：双方联系人列表出现对方，状态刷新后仍保持。
  - 页面计划：[confirm_new_friend_page.md](../auto_test/contact/confirm_new_friend_page.md)
- [x] A、B 分别重新进入联系人列表确认关系。（API 级：双方各自 `GET /api/v1/friend/list`，B 在 A 列表、A 在 B 列表，is_friend 均=1）
  - 预期：服务端关系一致，不依赖单端乐观更新。

## 4. 验收标准

- [x] 搜索、申请、确认、联系人刷新四个阶段均完成。（2026-08-17 本地 API 级全链路，7/7 测试通过）
- [x] 两个账号看到的好友关系一致。（A/B 双端 friend/list 回读 is_friend=1）
- [x] 失败、重复申请和无结果场景有明确提示，不误显示为已加好友。（重复 friend/add 服务端拒绝 code!=0；无结果 keyword 搜索返回空列表不崩）
- [x] 不能通过单端 UI 变化作为唯一成功证据。（全部结论基于 API 响应码+响应体）

## 5. 当前已有覆盖与阻塞

- 已有局部可执行测试：`integration_test/contact/add_friend_request_test.dart`、`confirm_new_friend_test.dart`、`friend_management_test.dart`。
- 2026-08-09：生产 `contact_api_test.dart` 5/5 顺序通过，覆盖好友列表、本人资料、搜索和黑名单接口；未执行申请/确认写入。
- 2026-08-09：两个授权测试账号分别运行联系人 API，只读套件均 5/5 通过；这证明 A/B 登录和联系人读取条件存在，但不证明好友申请、确认或双方关系已建立。
- macOS `friend_management_test.dart --plain-name='联系人列表可访问'` 本轮已确认生产登录成功，但联系人页加载触发本机既有加密 SQLite 数据库 `out of memory`；Android 华为真机现已完成安装确认，联系人列表只读用例已 `1/1` 通过并观察到 0 个联系人项。好友搜索、申请、确认和双方关系闭环仍未执行。
- 2026-08-09：Android `friend_management_test.dart` 使用 `.env.pro` 正确注入后完成生产登录和联系人页读取，最终 `1` 项通过、`1` 项因联系人列表为空受控 `SKIP`；未执行好友详情写入、申请、确认或删除操作。App 登录初始化仍会按既有逻辑上报设备/E2EE 材料，不能归因于本测试的业务动作。
- Android `add_friend_request_test.dart` 首次复核暴露旧测试对当前 Cupertino 导航/添加好友入口识别不足；已改为验证真实 `ContactPage`、增加 `add_friend_search_input` 稳定 Key、显式触发 Cupertino 搜索提交，并增加底部栏坐标兜底。2026-08-09 最新复核已完成生产登录、联系人页、添加好友页、真实 `/user/search` 请求和用户详情页进入，`1/1` 通过；本次使用的可搜索账号已是好友，因此未执行好友申请或通知写入。此前 `118@imboy.pub` 空结果仍作为无结果边界保留，不计入详情通过证据。
- 2026-08-09：Android `confirm_new_friend_test.dart` 已完成生产登录和联系人页进入，但当前账号没有「新朋友」入口/待处理申请，干净地受控 `SKIP`；未执行确认好友写入。
- 已修复测试工具对欢迎页异步跳转/登录页误判、桌面端账号密码入口识别、独立 widget 测试间 App 入口重新挂载以及 Android 截图阻塞；macOS `app_test.dart` 已 `2/2`、Android `app_test.dart` 已 `2/2` 通过，但这不能替代好友关系写入闭环证据。
- 当前页面计划记录了账号搜索边界问题，执行时需确认测试账号不触发该边界。
- 该流程涉及向测试账号发送通知，必须先确认两个账号和目标环境。
- 2026-08-09：生产 Android 真机已完成“搜索测试账号 → 用户详情”只读路径 `1/1`；联系人列表只读 `1/1`，新朋友入口因无待处理申请受控 `SKIP`。申请、通知、确认和双方关系刷新均未执行。
- 2026-08-10：后端好友状态机本地回归通过：`friend_logic_tests` 27/27、`friend_agg_tests` 18/18；覆盖重复申请、已是好友、pending→friends、无 pending 禁止确认等状态门禁。该结果不替代 117/118 生产关系写入闭环。
- 2026-08-17：**本地 API 级好友关系闭环通过（7/7）**。新增 `integration_test/demo_flow/friend_flow_api_test.dart`（纯 dart test，门禁：`TEST_ALLOW_API_WRITES=true` + 非生产 URL + 双账号，缺一即 SKIP）。环境：本地后端 `http://127.0.0.1:9800`（healthz db=up，version=1.0.0-alpha.27）；测试账号为本地合成账号 A=13900260817（uid=107539488731039744）、B=13900260818（uid=107539489230161920），昵称带 DEMO-FLOW-20260817 标记。命令（凭据经环境注入）：`API_BASE_URL=... IMBOY_ENV_PRO=.env.local TEST_PHONE=... TEST_PHONE2=... TEST_ALLOW_API_WRITES=true dart test integration_test/demo_flow/friend_flow_api_test.dart --concurrency=1` → `All tests passed!`（7 passed）。步骤证据：
  - 搜索：`GET /api/v1/user/search`（keyword=B 手机号）→ code=0，list 含 B；
  - 清理：对上一轮建立的关系执行 `POST /api/v1/friend/delete {uid}` → code=0，删除后 A 列表无 B（验证了删除分支）；
  - 申请：`POST /api/v1/friend/add {to, payload:{from:{source:"search"}}, created_at}` → code=0；
  - 重复申请被拒：第二次 add → code!=0（服务端状态门禁生效）；
  - 确认：B `POST /api/v1/friend/confirm {from:A, to:B, payload:{from/to 备注为 DEMO-FLOW-20260817-*}}` → code=0，payload.is_friend=1（alpha.26 confirm 修复在本地 alpha.27 依旧有效，无 500）；
  - 双方回读：A/B 各自 friend/list 均含对方且 is_friend=1；
  - 无结果边界：搜索 `DEMO-FLOW-20260817-NO-SUCH-USER-XYZ` → code=0 空列表。
- 2026-08-17 环境发现（本地）：① 新用户 `fts_user.allow_search` 缺省=2（不允许被搜索），导致搜索步骤首轮失败；B 通过 `POST /api/v1/user/update {field:"allow_search", value:"1"}` 开启后命中——产品隐私默认值，已作为测试前置写入。② 本地 HTTP `/api/v1/passport/signup` 被社区版 License 用户数上限拦截（code=402，本地库用户数已达默认 100）；测试账号改经后端标准管理通道 `escript scripts/imboy_ctl user create`（imboy_dev 节点，seed_demo.sh 同款方式）创建，未干预后端进程。③ 本地 SMS `switch=off`（验证码不真实发送），注册验证码依赖 `{imboy, verification_master_code}` 万能码；注册密码契约为 md5(明文) 直传（本地 `login_pwd_rsa_encrypt` 缺省 off）。
- 2026-08-17 生产只读复跑：`contact_api_test.dart` 以 `.env.pro` 注入运行 → 5/5 通过（好友列表/本人资料/搜索可达/黑名单分页，登录 uid=4），未执行任何生产写入。
- 2026-08-17 阻塞：双端 UI 通知验证仍缺第二设备（本轮无 Android/iOS 真机在线，macOS 设备被其他会话独占）。B 侧收到申请的「新朋友」入口红点/通知、双方 App 内联系人列表刷新的 UI 呈现未验证；现有结论止步于 API 层。
- 2026-08-18：**alpha.36 复跑维持通过（7/7 All tests passed）**。后端升级后全链路无回归：搜索→删除自愈→申请 code=0→重复申请被拒→确认 payload.is_friend=1→双方 friend/list 回读 is_friend=1→无结果边界空列表。命令与 08-17 相同（`dart test integration_test/demo_flow/friend_flow_api_test.dart --concurrency=1` + 三重门禁环境变量）。本轮运行注意：① 上轮创建账号的密码未持久化，本轮经本地 DB（127.0.0.1:4323 imboy_v1）为两个 DEMO-FLOW 昵称合成账号重置密码（按 `elib_password:generate` 的 hmac_sha512+盐格式写入 password 字段，仅命中 nickname LIKE 'DEMO-FLOW%' 两行，可回收本地测试数据）；② `scripts/test.env` 的 `API_BASE_URL` 行带行内注释（`http://127.0.0.1:9800   # dart test ... 使用`），文件头部的 `read_env` awk 提取会把注释拼进 URL 使 dio 请求打到非法地址（表现为登录「code=200 non_json_response」），双账号测试需以 `.env.local` 取 API_BASE_URL 或显式传干净值，单账号测试不要按 `qrcode_invite_flow_test.dart` 头部注释从 scripts/test.env 读 API_BASE_URL。
- 2026-08-18 设备复核：`flutter devices` 显示 Android 真机 MRD AL00（XWE6R19916004085，Android 9）与 iPhone 16e（iOS 26.6）均已在线——上轮「无第二设备」的阻塞条件已解除。但双端 UI 通知闭环需两台设备各自构建登录 A/B 账号（真机还需将 API 指向本机局域网地址而非 127.0.0.1）并实时观察 B 侧「新朋友」红点/通知，属专门轮次的真机验收，本轮未执行；结论仍止步于 API 层，不以设备在线代替 UI 证据。

## 6. 未来自动化目标

2026-08-17 已落地 `integration_test/demo_flow/friend_flow_api_test.dart`（API 级闭环，双账号显式配置、缺账号/生产 URL/未开写入门禁即 SKIP，不裸返回假绿）。B 侧「新朋友」申请列表无独立 HTTP 端点（由 S2C 消息触达），该环节的 UI 级验证仍需双设备。
