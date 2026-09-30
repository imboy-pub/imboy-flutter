# 构建 / 发布（Build & Release）

> **最后更新 / Last updated**: 2026-09-30
> **真源 / Source of truth**: `scripts/build_play_aab.sh` · `scripts/check_play_release.sh` · `scripts/verify_web_shell.sh` · `scripts/build_android_apk.sh` · `android/app/build.gradle.kts`
> 本文由脚本内容提取生成；脚本改动后须同步本页。

## Android

### 正式 Play AAB（发布上架用）

```bash
./scripts/build_play_aab.sh <build_number> [build_name]
# 例：./scripts/build_play_aab.sh 70101
#     ./scripts/build_play_aab.sh 70102 0.7.2
```

脚本行为（按实际内容）：

1. 前置门禁：调用后端仓 `../imboy/scripts/generate_product_features.py --check --require-profile full-selected`，不满足即退出（exit 2）。
2. `build_name` 未传时从 `pubspec.yaml` 的 `version:` 读取；读不到则要求显式传参。
3. 注入支付宝公开 AppID：`--dart-define=ALIPAY_APP_ID`，默认 `2021004142626807`，可用环境变量 `ALIPAY_APP_ID` 覆盖（非密钥；商户密钥全在服务端）。不注入时客户端充值降级为「即将开通」。
4. 构建命令等价于：

   ```bash
   flutter build appbundle --flavor standard \
     --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" \
     --dart-define=ALIPAY_APP_ID="$ALIPAY_APP_ID"
   ```

5. 产物：`build/app/outputs/bundle/release/app-standard-release.aab`

⚠️ **必须显式 `--flavor standard`**：白标 flavor（standard / gzCustomer）引入后必传；standard = 原 imboy 基线（applicationId/显示名/图标不变），Play 上架包固定走 standard，gzCustomer 白标包不在本脚本范围内。`build_number` 必须单调递增（Play 要求，脚本经 `flutter.versionCode` 保证）。

### 正式 release APK（分渠道直发用）

```bash
./scripts/build_android_apk.sh <version>
# 例：./scripts/build_android_apk.sh 1.0.0-alpha.18
```

脚本行为：校验版本号格式 → 要求 `docs/changelog.md` 已存在 `# <version>` 标题（否则 exit 2）→ 同一 `full-selected` 门禁 → 回写 `pubspec.yaml` version → `flutter build apk --release --flavor standard --obfuscate --split-debug-info=debugInfo --split-per-abi --dart-define=APP_ENV=pro --dart-define=ALIPAY_APP_ID=...`。产物在 `build/app/outputs/flutter-apk/`。

### Debug 构建

```bash
flutter run -d <设备ID>            # 日常调试（真机，见根 README）
flutter build apk --debug --flavor standard
```

签名注意：`local.properties` 配了 `storeFile` 时，**debug 构建也用 release 签名**（JVerification 一键登录要求包签名与极光后台一致，否则 init 报 8004/1011）；缺配置（CI / 新环境）回落 Flutter 默认 debug 签名。见 `android/app/build.gradle.kts` buildTypes.debug。

### Play 发布前检查

```bash
./scripts/check_play_release.sh
# 可选环境变量：PLAY_BASE_URL（默认 https://pro.imboy.pub）、SKIP_URL_CHECK=1
```

检查项（任一 FAIL → exit 1）：

| 项 | 说明 |
|---|---|
| merged manifest | 不存在时自动跑 `:app:processStandardReleaseMainManifest` 生成 |
| 禁用权限 | manifest 中不得出现 `ACCESS_BACKGROUND_LOCATION`、`QUERY_ALL_PACKAGES`、`MANAGE_EXTERNAL_STORAGE`、`REQUEST_INSTALL_PACKAGES`、`PACKAGE_USAGE_STATS` |
| AAB 产物 | `app-standard-release.aab` 存在（仅 WARN） |
| flutter.versionCode | `android/local.properties` 已配置（仅 WARN；未配置请用 build_play_aab.sh 保证单调） |
| 商店 URL | `$PLAY_BASE_URL/privacy-policy` 与 `/account-deletion` 可达（10s 超时） |

## Web Shell 验证

```bash
./scripts/verify_web_shell.sh            # 完整验证
./scripts/verify_web_shell.sh --quick    # 跳过 build web
./scripts/verify_web_shell.sh --no-server  # 不启动本地 server
```

流程：检查 `web/pkg/vodozemac_bindings_dart.js/.wasm` E2EE 产物存在（缺失 exit 4）→ `flutter analyze lib/page/web_shell/`（exit 1）→ `flutter test test/unit_test/page/web_shell/`（exit 2）→ `flutter build web --release --no-tree-shake-icons`（exit 3）→ 可选 `python3 -m http.server 9820`（build/web）人工冒烟。

## Android 签名注意事项

- 签名四件套全部在 **`android/local.properties`（gitignored，不入库）**：`storeFile` / `keyAlias` / `keyPassword` / `storePassword`；`release.keystore` 也在 `android/app/` 下，路径以 local.properties 为准。
- release `signingConfig` 启用 V1 + V2 签名；`storeFile` 未配置时 release 构建取不到值会失败/回落（见 build.gradle.kts signingConfigs）。
- 包名 + 签名是第三方「双锁」：极光后台不符报 1005（包名）/ 1011（签名）；debug/release keystore 指纹都要在第三方登记。换 keystore = 全新应用身份，老包无法覆盖升级。
- 高德 Key 不填发布版 SHA1 → 定位必报 `errorCode=7`。
- 详见 [third-party-config-guide.md](./third-party-config-guide.md)（极光/高德/支付宝换号流程）。

## 相关文档

- [third-party-config-guide.md](./third-party-config-guide.md) — 支付宝/极光/高德换凭据
- [changelog.md](./changelog.md) — release APK 脚本校验的版本标题真源
- 根 [README.md](../README.md) — 本地启动与日常调试
