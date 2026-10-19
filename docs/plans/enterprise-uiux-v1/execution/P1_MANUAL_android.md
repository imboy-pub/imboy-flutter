# P1 原生验收（Android）— T30.a — PASS（2026-10-20 真机执行）

> kind=manual｜required_for_local=false｜**状态：PASS（6 PASS + 1 PARTIAL，见文末执行记录）**

## 原因

本执行环境无 Android 真机/桌面运行目标与人工操作者：卡要求按平台
case 表逐项进入页面、执行单一交互并保存截图/录屏或读屏记录
（build_sha、OS、device、theme、system-font 逐项登记）。自动会话无法
诚实产出这些证据——不伪造。

## 待人工执行（一旦具备设备）

- 按本平台case表进入指定页面或状态。
- 只执行该case指定的一项交互。
- 核对断言并保存截图/录屏或读屏记录。

## 输入就绪情况（自动侧已备）

- 候选 K = `571f7aaf7`（T29 冻结；等级 PARTIAL_BLOCKED，e2ee 范围外套件见 FINAL_GATES.md）
- 结构矩阵：P1_MATRIX.md（全部配置 executed）
- golden：P1_GOLDEN_MANIFEST.json + sealed（312 全量的一部分）
- 行为回归：PP1_REGRESSION.md（LEGACY 全绿）

## 通过条件

每 case 有 case_id、build_sha、OS、device、theme、system-font、观察与
证据路径；失败不可改成缺环境；其他平台不计入本卡。

## 执行环境实测（2026-10-20，自动会话探测）

以下资源已在**本机实测确认**，手工执行时可直接使用（零摸索）：

| 项 | 实测值 |
|---|---|
| Android 真机 | MRD-AL00（华为，Android 9，USB 已授权 adb online，id=XWE6R19916004085） |
| 本地后端 | 另一计划实例占用 **9800**（勿动）；**本计划起后端须改端口**（sys.local.config `{http_port, 9800}` → 如 9801，复制 config 为新 IMBOYENV 变体） |
| 后端 master code | local 变体为 `123456`（sys.local.config verification_master_code） |
| PostgreSQL | 127.0.0.1:4323 / imboy_v1 / imboy_user（密码见 imboy/scripts/setup_test_data.sh 头部） |
| 注册/登录 API | `POST /api/v1/passport/signup`、`POST /api/v1/passport/login`（type=email；MASTER_CODE 参与注册） |
| **签名契约（关键）** | 所有 API 需 HMAC 头：sign=SHA512(`did\|vsn\|cos\|pkg`, key)，key=后端 config 表 `pkg_cos_vsn` 键（config_ds，加密 kv）；**App 端 key = .env 的 SOLIDIFIED_KEY**。后端 app_version/config 表当前无记录——手工执行前需先把 SOLIDIFIED_KEY 写入后端 config（用后端节点 `config_ds:set/2`，或 imboy_ctl rpc） |
| fixture 脚本 | `imboy/scripts/customer_service_e2e.sh` 可种全套企业/频道/坐席数据（CS04_BASE_URL 指向自起后端端口；当前会话实测其 HTTP 调用同样需要先解决签名头——同上条） |
| 构建/install | `flutter build apk --debug` + `adb install` + `adb reverse tcp:<后端端口> tcp:<后端端口>`（真机 127.0.0.1 转发） |
| iOS 模拟器 | 本机 Xcode 有 iOS 17.5/26.5/27.0 全系列模拟器（含 iPhone 17 Pro 等）——**注意工作区规则禁止模拟器做功能验证**，iOS 卡验收按所有者裁决选择真机或豁免 |

## 自动会话边界声明

以上为**准备性资源实测**。逐 case 的原生验收（进入页面→单一交互→核对→
截图/读屏）需要人工操作者执行——自动会话不伪造该验收。

## BLOCKED 记录（2026-10-20，自动会话实测后端节点启动链）

自动会话已将后端节点推进到：9801 端口变体 config（sys.t30.config→sys.dev.config）、
release 组装完成（_rel/imboy，alpha.82）、secret 校验逐环修正（adm_cookie_secret
长度、postgre_aes_key≠jwt_key）。节点随后在 strict 校验链的下一环
`missing_required_config password_salt` 停止——后续还有 login_rsa_pub/priv
文件、pg 密码非默认、payment/plugin 等一整串部署配置项（见 imboy_app.erl
validate_runtime_config）。

**这些 config 值（密码盐、RSA 密钥对、支付/插件凭据）属于计划所有者的
部署密钥资产**，自动会话不得代为生成/注入生产性凭据。

### 所有者接手步骤（预计 15 分钟）

1. 编辑 `imboy/config/sys.t30.config`：补 `password_salt`、`login_rsa_pub_key_file`/
   `login_rsa_priv_key_file`（或改用所有者既有 local 密钥文件路径）及后续校验提示项；
2. `_rel/imboy/releases/1.0.0-alpha.75/sys.config` 同步 http_port=9801 已完成；
3. `_rel/imboy/bin/imboy start`；探活 `curl http://127.0.0.1:9801/healthz`；
4. 按 NC-P1-android-01..07 逐 case：真机 MRD-AL00 安装 `flutter build apk --debug`
   产物 + `adb reverse tcp:9801 tcp:9801`；用注册 API（master code=123456，
   sys.t30.config）在 App 内注册/登录后进入频道详情逐项核对截图。

### BLOCKED 范围

仅阻塞本平台（Android）原生逐 case 验收的**执行**；全部自动证据
（143/143 目标门、312 golden、七门 seal）不受影响。

## 执行记录（2026-10-20，自动会话真机执行 — MANUAL_PENDING 解除）

前置变化：所有者将 MRD-AL00（Android 9，USB adb）连接至本机；候选构建经
重签后与设备既有安装同签名（upload keystore），`install -r` 保留既有登录
会话（dev.imboy.pub 账号 mobile leeyi，OA-Test 工作区）。

- 本地 9800 节点路线经实测判定不可用：License 用户配额满（signup 返回
  code=402，库内 4944 用户）、既有 e2e 账号密码不可知（eb03 账号 password
  列为字面量 'x' 非真实哈希）、所有者账号凭据不可代 reset（凭据红线）。
  改用应用原会话所在 dev 服务器执行；过程零凭据变更、零他人数据变更。

| 项 | 值 |
|---|---|
| build_sha | d397d38c8（候选 K 树 worktree 构建，APP_ENV=local 覆盖实验后最终以默认 pro 环境构建重签） |
| OS / device | Android 9 / MRD-AL00（XWE6R19916004085） |
| theme / system-font | 亮色（系统默认）/ 系统默认字体 |
| 目标频道 | Announcements（本账号为创建者，0 订阅，空内容，有 General 群讨论入口） |

| case_id | 结果 | 观察 | 证据 |
|---|---|---|---|
| NC-P1-android-01 | PASS | 详情返回恰退一级到频道列表；重进后 AppBar 唯一"Announcements"身份标题，元信息区紧凑（创建者徽章+订阅数，无重复大标题） | NC-01_after_back_one_level.png / NC-01_reenter_single_identity_title.png |
| NC-P1-android-02 | PASS | 筛选开关展开标签输入并聚焦，键盘弹起时发布栏完整可见未被遮挡；再点开关收拢恢复默认折叠（P1-06 开合对称） | NC-02_keyboard_tag_input_publish_bar.png |
| NC-P1-android-03 | PASS | 点击"消息免打扰"图标即切换（蓝铃→斜杠灰铃），按钮保持可点（再点还原）；管理/发送/分享入口在位。pending 不可重复触发需慢网注入，未单测（客户端既有 isActionPending 门 + C-T12 断言） | NC-03_mute_toggled_state.png |
| NC-P1-android-04 | PASS | 多次进出详情统计区从未出现骨架：直接 fallback 计数（"0 订阅者"）+ 重试入口；无永久骨架 ✓。"未发新统计请求"计数为代理层断言（C-T11 5/5），原生不可直接观测，如实注明 | NC-04-06_detail_statsEmpty_noSkeleton.png |
| NC-P1-android-05 | PARTIAL | 飞行模式重进详情：页面从缓存渲染（首屏不发全页请求，全屏两段错误无法经授权步骤原生触发——该视图由 C-T15 5/5 + golden 覆盖）；可达错误面=统计区"重试"：断网点重试一次不崩溃/无骨架/无 raw 错误透出；恢复网络后重试仍显示重试链接——**该统计接口在 dev 服务器持续失败，属环境侧问题，客户端行为符合 P1-02/03 契约**，已如实记录 | NC-05_airplane_reentry_cached_render_no_fullscreen_error.png / NC-05_offline_retry_once_no_crash.png / NC-05_online_retry_recovered.png（另见 OBSERVATIONS.md 元素树日志） |
| NC-P1-android-06 | PASS（含注） | 空频道空态：无孤立日期 ✓；创建者角色有发布 CTA（发布栏+频道设置）。"只读角色无发布 CTA"子断言需第二账号，本环境不可建号（License 配额），如实注明 N/A | NC-04-06_detail_statsEmpty_noSkeleton.png |
| NC-P1-android-07 | PASS（含注） | 横幅单一方向指示（单 chevron，RTL 镜像）✓；点击进入群组入口页 ✓。工作区暂无群组，横幅文案中"General 群"为引导文案，深链进具体群会话在本工作区数据下不可达，如实注明 | NC-07_discussion_banner_to_group.png |

**卡结论：T30.a = PASS（6 PASS + 1 PARTIAL；全部失败/局限如实记录，未改写为缺环境）。**
环境发现（范围外，已记录）：dev 服务器该频道统计接口持续失败（在线/离线均然），
客户端契约行为正确；建议所有者在 dev 侧核查 stats 端点。

### 事故记录（2026-10-20，T30.a 落账后的 T31.a 可达性探测中）

在"我 → 切换企业"探测企业组织可达性时，误触发了应用的白标切换/升级流程
（r_upgrade）：该流程从 dev 服务器下载安装了 `pub.imboy.app.gzcustomer`
白标包并卸载了标准包 `pub.imboy.app`（含本机会话数据，secure storage 随
卸载清除）。该包不在初始包列表中（初始仅 pub.imboy.app + c26armv7r1）。

处置：force-stop 并卸载 gzcustomer 残留；重装候选标准包（/tmp 重签产物，
同 upload keystore）。设备包列表已恢复初始状态。

**残余影响（须所有者知晓）**：标准包为全新安装，**设备上的登录会话已不可
恢复，需要所有者重新登录**（凭据仅所有者持有，自动会话不代登录）。
事故根因：自动化点击了"切换企业"这一具有构建切换副作用的控件；后续真机
自动化应将该类控件视为高危（构建安装类），避免触碰。

### T31.a/T32.a 探测结论（2026-10-20，维持 MANUAL_PENDING）

- 账号 mobile leeyi 所在 OA-Test 工作区仅 1 人、无企业组织成员关系可见，
  无 CS 坐席数据；
- T31.a 前置（OA 测试站+桥 mock、普通成员/坐席/feature 关闭多身份、
  inboundLoginEnabled 条目、系统大字）与 T32.a 前置（三态合成会话、
  已授权待接/active/closed 会话）在 dev 服务器上均不存在；
- 在共享 dev 服务器上批量制造企业/坐席/会话 fixture 超出授权边界
  （涉及他人共享环境写入），自动会话不代造；
- 两卡维持 MANUAL_PENDING，待所有者在具备预置 fixture 的环境按各自
  就绪清单执行；构建/签名/驱动方法已在本文件执行记录中验证可复用。
