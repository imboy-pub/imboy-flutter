# P3 原生验收（Android）— T32.a — MANUAL_PENDING

> kind=manual｜required_for_local=false｜**状态：MANUAL_PENDING（诚实记账）**

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
- 结构矩阵：P3_MATRIX.md（全部配置 executed）
- golden：P3_GOLDEN_MANIFEST.json + sealed（312 全量的一部分）
- 行为回归：PP3_REGRESSION.md（LEGACY 全绿）

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
