# 构建 / 发布（Build & Release）

> **最后更新 / Last updated**: 2026-11-05
> **真源 / Source of truth**: `scripts/build_play_aab.sh` · `scripts/check_play_release.sh` · `scripts/verify_web_shell.sh` · `scripts/build_android_apk.sh` · `android/app/build.gradle.kts`
> 本文由脚本内容提取生成；脚本改动后须同步本页。

## Android

### 正式 Play AAB（发布上架用）

```bash
./scripts/build_play_aab.sh <build_number> [build_name]
# 例：./scripts/build_play_aab.sh 70101
#     ./scripts/build_play_aab.sh 70102 0.7.2
```

脚本校验 versionCode（1–2100000000）后检查 Flutter SDK 与后端 `full-selected` 生成物；`build_name` 默认从 `pubspec.yaml` 读取并去掉 `+build`。实际构建使用 `--release --flavor standard --obfuscate`，注入公开的 `ALIPAY_APP_ID`，并将 Dart 符号写到 `debugInfo/play/<build_number>`；可用 `PLAY_SYMBOL_DIR` 指定安全目录。

产物：`build/app/outputs/bundle/standardRelease/app-standard-release.aab`。每次发布前须到 Play Console 核对并分配大于所有已用版本的 versionCode，脚本不能验证远端历史。构建成功也不代表已正式签名或通过 Play 审核。须用 `jarsigner -verify -verbose -certs <AAB>` 检查完整性，用 `keytool -printcert -jarfile <AAB>` 对照预期上传证书的 SHA-256，并用 bundletool 检查实际包名、版本、targetSdk 和 ABI。保存该 AAB 对应的 Dart symbols、R8 mapping 和原生符号并真机回归；`PLAY_SYMBOL_DIR` 不能使用临时或公开位置。

签名通过 `android/key.properties` 优先配置，四个属性可分别回退到 `android/local.properties`；不得混用旧值或使用 debug keystore。Play 上传证书与 Play 分发 APK 的应用签名证书可能不同，第三方 SDK 应核对实际分发证书。构建与签名操作详见产品主仓 `docs/guides/release/android-googleplay-checklist.md`。

CI 的 AAB 是临时 debug key 签名的构建冒烟检查，不能用于 Play 上传。

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
| AAB 产物 | `bundle/standardRelease/app-standard-release.aab` 存在（仅 WARN，不检查签名或版本） |
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

- `android/key.properties` 读取 `storeFile`、`keyAlias`、`keyPassword`、`storePassword`；缺少的属性逐项回退 `android/local.properties`。签名配置和 keystore 不得提交或输出；推荐使用 keystore 绝对路径。
- release 使用 release signingConfig；脚本不会证明证书是正式上传证书，必须核对签名和 Play Console 的证书指纹。上传密钥与 Play 应用签名密钥可不同，分别做好安全备份和第三方平台登记。
- debug 构建在 `local.properties` 配置 `storeFile` 时也使用 release 签名，否则使用默认 debug 签名。
- 高德、极光等第三方需核对包名与实际安装包的证书指纹；具体见 [third-party-config-guide.md](./third-party-config-guide.md)。

## 相关文档

- [third-party-config-guide.md](./third-party-config-guide.md) — 支付宝/极光/高德换凭据
- [changelog.md](./changelog.md) — release APK 脚本校验的版本标题真源
- 根 [README.md](../README.md) — 本地启动与日常调试
