# 第三方服务账号更换配置手册（支付宝 / 极光 / 高德）

> 面向零基础操作者。按顺序做完每一步、看到每步的 ✅ 验证结果，即算成功。
> 适用版本：2026-08-22（支付宝配置已 env 化，构建不再依赖 --dart-define）。
>
> **通用前提**：三处工作区——
> - 客户端仓 `~/project/imboy.pub/imboyapp/`（Flutter App）
> - 服务端仓 `~/project/imboy.pub/imboy/`（Erlang 后端，配置文件 `config/sys.pro.config`）
> - 生产服务器 `ssh -p <SSH_PORT> root@<PROD_HOST>`

---

## 1. 换一个支付宝商户账号（App 支付）

### 第 1 步：支付宝开放平台控制台

1. 打开 https://open.alipay.com → 控制台 → **创建网页/移动应用**，平台选 Android + iOS。
2. 记下 **APPID**（2021 开头的 16 位数字）。
3. 在「产品绑定」里签约 **App 支付**。
   ✅ 验证：产品列表里 App 支付显示「已签约」。
   ⚠️ 未签约时调用必报 `isv.insufficient-isv-permissions`。
4. **接口加签方式**选「公钥证书模式」（本项目按此实现），用支付宝官方「密钥工具」生成 RSA2 (2048) 密钥对：
   - 密钥工具里「获取 CSR 文件」→ 上传 CSR → 得到三张证书：
     - 应用公钥证书 `appCertPublicKey_<APPID>.crt`
     - 支付宝公钥证书 `alipayCertPublicKey_RSA2.crt`
     - 支付宝根证书 `alipayRootCert.crt`
5. 记下账户中心里的 **PID**（2088 开头）。AES 密钥可不配（留空）。

### 第 2 步：服务器（生产 root@<PROD_HOST>）

1. 上传文件（私钥 + 三张证书）：

   ```bash
   # 本地执行
   scp -P <SSH_PORT> 应用私钥.pem root@<PROD_HOST>:/etc/imboy/keys/alipay_private_key.pem
   ssh -p <SSH_PORT> root@<PROD_HOST> "mkdir -p /etc/imboy/keys/alipay_certs"
   scp -P <SSH_PORT> appCertPublicKey_<APPID>.crt alipayCertPublicKey_RSA2.crt alipayRootCert.crt \
     root@<PROD_HOST>:/etc/imboy/keys/alipay_certs/
   ```

2. **重算两张证书的 SN**（关键！SN 配错 = 收银台报「商家订单参数异常」）。
   算法 = `md5hex(IssuerDN + 十进制serial)`，IssuerDN 按 `CN=..,OU=..,O=..,C=..` 顺序拼接。
   直接用服务器上 imboy 的代码算（`cert_sn` 单证书、`root_cert_sn` 根证书链，结果 hex 即填配置的值）：

   ```bash
   ssh -p <SSH_PORT> root@<PROD_HOST> "echo 'io:format(\"~s~n~s~n\", [imboy_lib:cert_sn(\"/etc/imboy/keys/alipay_certs/appCertPublicKey_<APPID>.crt\"), alipay_openapi:root_cert_sn(\"/etc/imboy/keys/alipay_certs/alipayRootCert.crt\")]).' | /usr/local/imboy-*/releases/*/erts*/bin/erl_call -r -c <ERLANG_COOKIE> -address 127.0.0.1:<NODE_PORT> -e -fetch_stdout"
   ```

   > 端口 <NODE_PORT> 以 `epmd -names` 实查为准。SN 计算的权威实现在 `imboy/src/lib/alipay_openapi.erl`。

3. 改 `imboy/config/sys.pro.config` 中 7 个键（本地仓 + 服务器双写）：

   | 键 | 值 |
   |---|---|
   | `alipay_app_id` | 新 APPID |
   | `alipay_private_key` | `/etc/imboy/keys/alipay_private_key.pem`（路径一般不变）|
   | `alipay_pid` | 新 PID |
   | `alipay_aes_key` | 留空 `<<>>` |
   | `alipay_app_cert_sn` | 第 2 步算出的**应用证书 SN** |
   | `alipay_root_cert_sn` | 第 2 步算出的**根证书链 SN**（多段 `_` 连接）|
   | `alipay_notify_url` | `https://pro.imboy.pub/api/v1/payment/callback/alipay`（域名不变则不动）|

4. 生产节点**热改**（立即生效，不用重启）+ `sys.config` 持久化（重启后仍生效）：

   ```bash
   # 热改（erl_call 通道，cookie 用 <ERLANG_COOKIE>）
   ssh -p <SSH_PORT> root@<PROD_HOST> "echo 'application:set_env(imboy, alipay_app_id, <<\"新APPID\">>), application:set_env(imboy, alipay_pid, <<\"新PID\">>), application:set_env(imboy, alipay_app_cert_sn, <<\"新SN\">>), application:set_env(imboy, alipay_root_cert_sn, <<\"新根SN\">>).' | erl_call -r -c <ERLANG_COOKIE> -address 127.0.0.1:<NODE_PORT> -e"
   # 持久化：sed 替换 release 目录下 sys.config 里的旧值（先备份！）
   ```

   ✅ 服务端自验：`payment_gateway:query_order(<<"alipay">>, <<"任意订单号">>)` 返回
   `{error,<<"交易不存在">>}` = **验签通过**（错误是 GBK 显示会像乱码「½»Ò×²»´æÔÚ」）。

### 第 3 步：客户端（imboyapp）

1. 改 5 个文件（值都是公开非密钥）：
   `.env`、`.env.dev`、`.env.pro`、`.env.local`、`.env.local_home`、`.env.local_office` 里：

   ```
   ALIPAY_APP_ID=新APPID
   ALIPAY_UNIVERSAL_LINK=https://pro.imboy.pub/app/   # 域名没变就不用动
   ```

2. **重新生成烘焙代码**（⚠️ 必须先 clean，否则新值不生效）：

   ```bash
   cd ~/project/imboy.pub/imboyapp
   dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs
   # 验证：rg alipayAppId lib/config/env_pro.g.dart 应显示新 APPID
   ```

3. 重新构建安装 App（脚本**无需传参**，配置自动带上）：
   - Android：`scripts/build_play_aab.sh` 或 `flutter run --release`
   - iOS：`scripts/build_ios.sh <build_number>`

### 第 4 步：端到端验证

真机充值 **0.01 元**，然后查生产 DB（三表全绿才算成功）：

```bash
ssh -p <SSH_PORT> root@<PROD_HOST> "docker exec prod_imboy_pg18 psql -U imboy_user -d imboy_pro \
  -c 'SELECT order_no,amount,status,payment_no,paid_at FROM recharge_order ORDER BY id DESC LIMIT 1;' \
  -c 'SELECT user_id,balance FROM wallet ORDER BY updated_at DESC LIMIT 1;' \
  -c 'SELECT amount,tx_type,reference_no FROM wallet_transaction ORDER BY id DESC LIMIT 1;'"
```

✅ `status=1` + `payment_no` 有支付宝交易号 + `wallet.balance` 增加 = 成功。

### 常见坑

| 现象 | 原因 |
|---|---|
| 收银台「商家订单参数异常」| `alipay_app_cert_sn` 配错（不是证书文件错，是 SN 值错）|
| 网关返回「应用公钥证书不存在」| 同上，SN 指向了不存在的证书 |
| 付了钱但 App 一直转圈 | 回调丢失——App 内 confirm 轮询会在 1 分钟内自动补账，查 DB 为准 |
| iOS 付完款不自动跳回 App | 需**付费**开发者账号启用 Associated Domains（免费账号无此能力）；资金不受影响 |
| 改了 .env 没生效 | 没 `build_runner clean`（envied 不把 .env 当增量输入）|

---

## 2. 换一个极光账号（JPush 推送 + JVerify 一键登录）

> 现状提醒：JVerify（一键登录）已接线并实测通过；**JPush 后端从未集成**，换 AppKey 只影响客户端 SDK 初始化。

### 第 1 步：极光开发者控制台

1. 打开 https://www.jiguang.cn → 创建应用。
2. **Android**：填包名 `pub.imboy.app` + **发布版签名 SHA1**（keystore 指纹，可用
   `keytool -list -v -keystore xxx.keystore` 查看）。
   ⚠️ 包名和签名是「双锁」：任何一个与极光后台不符，SDK 报 1005（包名）/ 1011（签名）。
   ⚠️ 换包名 = 全新应用身份，老包无法覆盖升级——一般不要动包名。
3. **iOS**：填 Bundle ID `pub.imboy.app`；推送还需上传 APNs 证书（p12 或 p8）。
4. 记下 **AppKey**（公开值）和 **Master Secret**（⚠️ 绝密，只放服务器，禁入任何仓库/聊天记录）。

### 第 2 步：客户端（imboyapp）

1. `android/local.properties`（gitignored 本地文件）：

   ```
   jpush.appKey=新AppKey
   jpush.masterSecret=新MasterSecret
   ```

2. `.env` 系列全部文件改：`JPUSH_APPKEY=新AppKey`
3. 重新生成 + 构建：

   ```bash
   dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs
   ```

### 第 3 步：JVerify 一键登录（服务端验签链）

JVerify 登录流程：App 拿极光 token → 发给 imboy 服务端 → 服务端调极光 REST 验证。
服务端配置在 `imboy/config/sys.pro.config`：

| 键 | 值 |
|---|---|
| `jpush_app_key` | 新 AppKey |
| `jpush_master_secret` | 新 Master Secret（热改命令同支付宝第 2.4 步）|
| `jverification_rsa_priv_key_file` | `/etc/imboy/keys/login_rsa_priv.pem` |

**RSA 公私钥对**（极光控制台「认证设置」里要填公钥）：

```bash
# 服务器上已有这对钥匙；换新钥匙时：
openssl genrsa -out login_rsa_priv.pem 2048
openssl rsa -in login_rsa_priv.pem -pubout -out login_rsa_pub.pem
# 控制台填的值 = 公钥的 base64 DER：
openssl rsa -pubin -in login_rsa_pub.pem -outform DER | base64
```

把输出贴到极光控制台「认证设置 → RSA 公钥」，私钥路径写进 sys.pro.config。

### 第 4 步：验证

- **JVerify**：真机退出登录 → 登录页点「本机号码一键登录」→ 能进 App = 通。
  ✅ 服务端日志出现 jverify 验证成功记录。
- **JPush**：目前仅客户端 SDK 初始化（可看启动日志无 1005/1011 报错）；推送收发需后端集成（未做）。

### 常见坑

| 现象 | 原因 |
|---|---|
| SDK 报 1005 | 包名与极光后台不符 |
| SDK 报 1011 | 签名 SHA1 不符（debug/release keystore 指纹不同，两个都配上）|
| 一键登录报验签失败 | 控制台 RSA 公钥与服务器私钥不配对 |
| App 登录报 902 | 与极光无关，是 IMBOY 签名密钥（solidified_key）漂移 |

---

## 3. 换一个高德地图 Key

### 第 1 步：高德开放平台控制台

1. 打开 https://console.amap.com → 应用管理 → 创建新应用 → 添加 **3 个 Key**：

   | 平台 | 配置 | 用途 |
   |---|---|---|
   | Android | 包名 `pub.imboy.app` + **发布版 SHA1**（建议同时配调试版 SHA1）| 定位 |
   | iOS | Bundle ID `pub.imboy.app` | 定位 |
   | Web 服务 | 白名单留空 | 地图/搜索 API |

   ⚠️ Android Key 不填 SHA1 → 定位必报 `errorCode=7`（这是最常见的坑）。

### 第 2 步：客户端（imboyapp）

1. `.env` 系列全部文件改三个键：

   ```
   A_MAP_ANDROID_KEY=新AndroidKey
   A_MAP_IOS_KEY=新iOSKey
   A_MAP_WEBS_KEY=新WebKey
   ```

2. 重新生成 + 构建：

   ```bash
   dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs
   # 验证：rg A_MAP_ANDROID_KEY 的值出现在 lib/config/env_pro.g.dart
   ```

3. 无需改代码：Key 由 `lib/component/location/amap_helper.dart` 从 `Env()` 读取后传给定位 SDK。

### 第 3 步：验证

真机打开「附近的人」或任何定位功能：

✅ 能拿到经纬度、地图正常显示 = 成功。
❌ 日志报 `errorCode=7` → 回第 1 步检查 Android Key 的 SHA1/包名。

---

## 附：改 .env 后的标准三连（所有第三方通用）

```bash
cd ~/project/imboy.pub/imboyapp
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
rg 你的新KEY lib/config/env_pro.g.dart   # 确认烘焙成功
```

构建 APK/AAB/IPA 无需任何 --dart-define（2026-08-22 起）。
