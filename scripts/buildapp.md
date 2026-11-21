# buildapp.sh — 多客户统一 APP 构建入口

一份脚本服务所有客户；不写死任何 customer_id / 资源包版本。

## 用法

```bash
bash scripts/buildapp.sh <customer_id> [environment] [platforms...] [--dry-run]
# environment: development | staging | production   （默认 production）
# platforms:   android | ios | web                  （默认 all = android ios web）
bash scripts/buildapp.sh --help
bash scripts/buildapp.sh yaoxin development android   # 演示 APK
bash scripts/buildapp.sh yaoxin production all        # 现在 fail-closed（正式身份/API/Scheme 未配置）
```

## 目录契约

| 输入 | 路径 |
|---|---|
| 客户配置 | `../customers/<id>/config/`（`app.yaml`、`features.yaml`、`environments/<env>.env`、可选 `client/public.env`） |
| 客户资源 | `../customers/<id>/assets/[<assets.package>/]`（完整资源包，含 `manifest/SHA256SUMS`，每次构建强制校验；`assets.package` 可为 `.` 表示资源目录本身，或单个相对子目录名） |
| 构建收据（真实构建） | `../customers/<id>/builds/<env>/<version>-<build_number>-<run_id>/`（`android/`、`ios/`、`web/`、`build.log`、`build-manifest.yaml`、`SHA256SUMS`） |
| dry-run 收据 | `../customers/<id>/builds/dry-runs/<env>/<version>-<build_number>-<run_id>/`（无产物，`build_status: DRY_RUN`） |
| 失败证据 | `../customers/<id>/builds/failed-runs/<env>-<run_id>/`（`build-status.txt: FAIL` + 日志；**永不**包含 PASS 收据） |

每个收据目录以唯一 `run_id`（UTC 秒 + pid + 随机后缀）命名：同一客户同一分钟的两次构建互不混用产物。

`app.yaml` 关键字段：`brand.app_name`、`assets.{package,version,replacement_map,authorization_status}`、
`identity.{android_application_id,ios_bundle_id,url_scheme}`（**REQUIRED for production**）、
`identity.demo.*`（仅 development/staging）、`splash.{mode,source}`（inherit|regenerate）。

## URL Scheme 契约（identity.url_scheme）

- 合法值：`^[a-z][a-z0-9+.-]{0,39}$`（RFC 3986 scheme 子集；**显式小写策略**——含大写、空格、`://`、路径、查询即 fail-closed，绝不静默改写）。
- **production 必须提供客户自有 scheme**；等于 vendor `imboy` 即拒（不同客户的正式构建禁止默认共用 vendor Scheme）。
- development/staging 未配置 scheme 时，必须显式 `identity.demo.inherit_vendor_url_scheme: "true"` 才允许继承 vendor `imboy://`（继承事实写入收据 disclosures；显式把 `url_scheme` 配成 `imboy` 一律拒绝）。
- 注入范围（结构化解析断言，非 grep）：
  - Android：仅 MainActivity 深链 intent-filter 的 `android:scheme="imboy"` 数据属性（3 处）；VIEW/DEFAULT/BROWSABLE、host=`imboy.pub`、pathPrefix、HTTPS App Links（autoVerify）、`queries`（https/sms/tel）、微信/支付回调全部原样保留并逐项断言。
  - iOS：仅 `CFBundleURLName == "imboy.pub"` 的 URL Type 之 `CFBundleURLSchemes`；weixin/alipay/ShareMedia URL Types、E2EE 备份注册（DocumentTypes + UTI）、其余全部 plist 键原样保留并逐项断言。ShareExtension/Info.plist 无 URL 注册，不注入 Scheme；其 `AppGroupId` 必须注入为 `group.<customer Bundle ID>`，并与 Runner + ShareExtension 两侧全部 `.entitlements` 的 `com.apple.security.application-groups` 完全一致。
- 交叉核验（F12）：收据中的 `android_registered_url_schemes` / `ios_registered_url_schemes` 从**注入后的原生文件**结构化回读，与配置不一致即构建失败。
- 真实产物复核（F13）：Android 在真实 APK 构建后用 apkanalyzer/aapt2 解析**合并 Manifest** 再断言；iOS 对构建出的 `Runner.app/Info.plist`（plistlib）再断言；结果写入收据 `artifact_checks`。dry-run 不适用（无产物）。
- 双 App 共存（F14）：真机验证前一律记 `device_coexistence_test_status: DEVICE_TEST_PENDING`，不得宣称通过。

## 隔离与安全模型

1. **锁**：`.buildapp-locks/<customer_id>/`（PID 存活检测；死锁/孤儿 worktree 下次运行自动回收；SIGKILL 属不可陷阱退出，同样由下次运行回收）。
2. **隔离 worktree**：`.buildapp-worktrees/<id>-<env>-<run_id>/` 从当前 HEAD detached 创建；submodule（`plugin/flutter_chat_ui`）自动 init；成功/失败/Ctrl-C/SIGTERM 均经 trap 清理并释放锁。
3. **共享工作区零污染**：注入只发生在 worktree；退出后 `git status --porcelain` 与运行前快照一致（测试 #17 守护）。
4. **收据隔离（run receipt isolation）**：每次运行先分配**独占空暂存目录** `builds/.staging/<run_id>/`，产物全部落入暂存并登记进 run inventory；`build-manifest.yaml` 与 `SHA256SUMS` **最后**生成且只覆盖本轮 inventory；随后单次原子 `mv` 发布为正式收据目录。构建失败/中断：暂存内的收据文件被剥离、写入 `build-status.txt: FAIL`、移入 `builds/failed-runs/`——**失败永不产生（或冒充）PASS 收据**；父目录的旧 APK/manifest/checksum 不可能混入本轮（唯一 run 目录 + inventory 驱动的 SHA256SUMS）。
5. **iOS Share Extension 客户隔离**：`ShareExtension/Info.plist:AppGroupId` 与 Runner/ShareExtension 的 App Groups entitlement 统一为 `group.<customer Bundle ID>`；`buildapp_ios_app_group_tools.py` 负责结构化注入和交叉验证，禁止残留 vendor 或其他客户 group。所有改动只发生在隔离 worktree，源仓 vendor 基线不变。
6. **local.properties 白名单拷贝**：仅携带构建路径键（sdk.dir/flutter.*）；**签名键（storeFile 等）与渠道凭据（jpush.appKey/jpush.masterSecret/huawei.appId/wl.*）一律剥离**——demo 构建用一次性 keystore，绝不使用 vendor release keystore。`google-services.json` 属客户端配置（非秘密），宿主存在则复制。
7. **fail-closed**：production 缺 `identity.*`（含 `url_scheme`）/ `API_BASE_URL` 即拒；demo 环境未给 API 覆盖时必须显式 `ALLOW_DEMO_INHERITED_API=yes`，未给 scheme 时必须显式 `inherit_vendor_url_scheme: "true"`（两个继承事实都写入收据，绝不静默）。
8. **产品无 secrets**：服务端秘密/签名材料永不经过本脚本；envied 混淆不视作秘密边界。

## 注入范围（以真实工程结构为准，replacement-map 仅为候选参考）

| 平台 | 内容 |
|---|---|
| android | `applicationId`（gradle `baseApplicationId` + JPUSH_PKGNAME 联动）、`android:label`、**URL scheme（3 处深链 data 属性，结构化等价断言）**、mipmap 全密度 + anydpi-v26 adaptive（xml+foreground+colors overlay） |
| ios | Bundle ID（Runner+ShareExtension，pbxproj 6 处）、`CFBundleDisplayName`（plistlib，Runner+ShareExtension）、**URL scheme（imboy.pub URL Type 的 CFBundleURLSchemes）**、app-group、AppIcon 逐槽生成（读真实 Contents.json，浮点尺寸安全，sips 重采样） |
| web | favicon（favicon-32→favicon.png）、PWA Icon-192/512、manifest name/theme_color、index.html 标题 + `?v=` cache-bust、像素级验证 |
| splash | `mode: inherit`（默认，不动生成物）或 `mode: regenerate`（改 flutter_native_splash 源配置后跑生成器） |

## 与既有脚本的关系（复用决策）

- **复用**：`web/build_web.sh`（原样调用）、`scripts/check_sdk_compatibility.py`、后端 `generate_product_features.py --check --require-profile full-selected`（与现有一致的前置门）。
- **门策略**：客户配置 `build_policy.features_gate` 默认 `enforce`（与 vendor 发布一致）；demo/staging 可显式设 `skip_with_disclosure`（该分支不需要本机存在后端仓；跳过事实披露进 build-manifest；**production 无条件 enforce**）。
- **不直接复用**（行为已核对，属 vendor 发布专用）：`build_android_apk.sh`（changelog 版本门 + vendor 支付宝 ID + `APP_ENV=pro` + pubspec 改写）、`build_ios.sh`（vendor 默认签名 + vendor 支付宝 UL）。buildapp.sh 以客户驱动的等价 flutter 命令替代，平台构建逻辑不复制重写。

## 平台可移植性（macOS / Linux CI）

macOS 保留已验证的原生工具（sips 重采样为交付已验证路径）；其余全部走可移植封装：`sed -i`（BSD/GNU 自适应）、plist 读写（python3 plistlib，替代 plutil）、sha256（shasum/sha256sum 自适应）、PNG 尺寸探针（纯 python IHDR 解析）、PNG 重采样（无 sips 时回退 `scripts/buildapp_png_tools.py` 纯 stdlib 最近邻实现，Linux CI 走此路径）。核心逻辑（收据隔离、scheme 契约/注入/核验）在两个平台跑同一套 `buildapp_test.sh`（80 断言）。

## 已知限制

1. **iOS 不出 IPA**：无客户签名凭据时仅产出 unsigned `Runner.app.zip`（`flutter build ios --no-codesign`）；Archive/Export 需客户证书+ExportOptions。
2. splash `regenerate` 路径实现但未被当前客户配置启用（Yaoxin 概念稿待视觉审），该分支未做真实构建验证。
3. **双 App 共存未做真机验证**（F14）：收据恒记 `DEVICE_TEST_PENDING`；需要真机（原版 IMBoy + 客户版并存、intent resolution / URL 打开归属验证）后才能翻转。
4. demo 继承 vendor scheme/后端属显式披露行为，不适用于任何对外承诺；production 永不继承。
5. ShareExtension `AppGroupId` 与两侧 entitlements 在客户隔离 worktree 内统一注入为 `group.<customer Bundle ID>`；T5a–T5c 覆盖 alpha/beta 不串扰、旧 vendor group 拒绝及源仓基线不变。

## 测试与 CI

```bash
bash scripts/buildapp_test.sh     # 86 项断言 / 四层（01-20 原契约 + T 工具级 + S scheme 端到端 + R 收据隔离）
```

- fixture 由 `scripts/buildapp_fixture.sh` 生成（`selftest-*` / `customer-alpha` scheme=alphaapp / `customer-beta` scheme=betaapp / `customer-prod` 等），全部取材仓内中性 vendor 图标，运行后自清理，不使用任何真实客户资源。
- CI（`.github/workflows/buildapp.yml`）：macOS + Linux shell 全量测试；Android 真实 APK 合并 Manifest 检查（F13）；macOS 真实 Runner.app plist 检查（F13）。
- 测试钩子：`BUILDAPP_FAKE_UTC`（确定性时间戳）、`BUILDAPP_TEST_HOLD`（确定性中断窗口，供 SIGTERM 恢复用例）。
