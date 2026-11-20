# buildapp.sh — 多客户统一 APP 构建入口

一份脚本服务所有客户；不写死任何 customer_id / 资源包版本。

## 用法

```bash
bash scripts/buildapp.sh <customer_id> [environment] [platforms...] [--dry-run]
# environment: development | staging | production   （默认 production）
# platforms:   android | ios | web                  （默认 all = android ios web）
bash scripts/buildapp.sh --help
bash scripts/buildapp.sh yaoxin development android   # 演示 APK（当前 Yaoxin 可行路径）
bash scripts/buildapp.sh yaoxin production all        # 现在 fail-closed（正式身份/API 未配置）
```

## 目录契约

| 输入 | 路径 |
|---|---|
| 客户配置 | `../customers/<id>/config/`（`app.yaml`、`features.yaml`、`environments/<env>.env`、可选 `client/public.env`） |
| 客户资源 | `../customers/<id>/assets/[<assets.package>/]`（完整资源包，含 `manifest/SHA256SUMS`，每次构建强制校验；`assets.package` 可为 `.` 表示资源目录本身，或单个相对子目录名） |
| 构建产物 | `../customers/<id>/builds/<env>/<version>-<build_number>/`（`android/`、`ios/`、`web/`、`build.log`、`build-manifest.yaml`、`SHA256SUMS`） |

`app.yaml` 关键字段：`brand.app_name`、`assets.{package,version,replacement_map,authorization_status}`、
`identity.{android_application_id,ios_bundle_id,url_scheme}`（**REQUIRED for production**）、
`identity.demo.*`（仅 development/staging）、`splash.{mode,source}`（inherit|regenerate）。

## 隔离与安全模型

1. **锁**：`.buildapp-locks/<customer_id>/`（PID 存活检测；死锁/孤儿 worktree 下次运行自动回收；SIGKILL 属不可陷阱退出，同样由下次运行回收）。
2. **隔离 worktree**：`.buildapp-worktrees/<id>-<env>-<ts>/` 从当前 HEAD detached 创建；submodule（`plugin/flutter_chat_ui`）自动 init；成功/失败/Ctrl+C/SIGTERM 均经 trap 清理并释放锁。
3. **共享工作区零污染**：注入只发生在 worktree；退出后 `git status --porcelain` 保持干净（测试 #17 守护）。
4. **local.properties 白名单拷贝**：仅携带构建路径键（sdk.dir/flutter.*）；**签名键（storeFile 等）与渠道凭据（jpush.appKey/jpush.masterSecret/huawei.appId/wl.*）一律剥离**——demo 构建落 debug 签名，绝不使用 vendor release keystore。
5. **fail-closed**：production 缺 `identity.*` / `API_BASE_URL` 即拒；demo 环境未给 API 覆盖时必须显式 `ALLOW_DEMO_INHERITED_API=yes`（继承事实写入 build-manifest，绝不静默）。
6. **产品无 secrets**：服务端秘密/签名材料永不经过本脚本；envied 混淆不视作秘密边界。

## 注入范围（以真实工程结构为准，replacement-map 仅为候选参考）

| 平台 | 内容 |
|---|---|
| android | `applicationId`（gradle `baseApplicationId` + JPUSH_PKGNAME 联动）、`android:label`、mipmap 全密度 + anydpi-v26 adaptive（xml+foreground+colors overlay） |
| ios | Bundle ID（Runner+ShareExtension，pbxproj 6 处）、`CFBundleDisplayName`（plutil）、app-group、AppIcon 逐槽生成（读真实 Contents.json，浮点尺寸安全，sips 重采样） |
| web | favicon（favicon-32→favicon.png）、PWA Icon-192/512、manifest name/theme_color、index.html 标题 + `?v=` cache-bust、像素级验证（sips） |
| splash | `mode: inherit`（默认，不动生成物）或 `mode: regenerate`（改 flutter_native_splash 源配置后跑生成器） |

## 与既有脚本的关系（复用决策）

- **复用**：`web/build_web.sh`（原样调用）、`scripts/check_sdk_compatibility.py`、后端 `generate_product_features.py --check --require-profile full-selected`（与现有一致的前置门）。
- **门策略**：客户配置 `build_policy.features_gate` 默认 `enforce`（与 vendor 发布一致）；demo/staging 可显式设 `skip_with_disclosure`（跳过事实披露进 build-manifest；**production 无条件 enforce**）。用于后端工作区 profile 与 full-selected 暂不一致的演示场景，不削弱任何发布门。
- **不直接复用**（行为已核对，属 vendor 发布专用）：`build_android_apk.sh`（changelog 版本门 + vendor 支付宝 ID + `APP_ENV=pro` + pubspec 改写）、`build_ios.sh`（vendor 默认签名 + vendor 支付宝 UL）。buildapp.sh 以客户驱动的等价 flutter 命令替代，平台构建逻辑不复制重写。

## 已知限制

1. **iOS 不出 IPA**：无客户签名凭据时仅产出 unsigned `Runner.app.zip`（`flutter build ios --no-codesign`）；Archive/Export 需客户证书+ExportOptions。
2. splash `regenerate` 路径实现但未被当前客户配置启用（Yaoxin 概念稿待视觉审），该分支未做真实构建验证。
3. 同一客户同一分钟内的连续构建复用同一产物目录（demo 语义；正式构建建议每分钟一次或扩展秒级目录）。
4. macOS 优先（BSD sed/plutil/sips）；Linux 需适配 sed 参数。
5. demo 构建继承 vendor 演示后端属显式披露行为，不适用于任何对外承诺。

## 测试

```bash
bash scripts/buildapp_test.sh     # 23 项断言 / 20 场景，含 SIGINT 恢复、并发拒止、基线零污染
```

测试 fixture 为合成客户（`customers/selftest-*`，中性 vendor 图标），运行后自清理，不使用任何真实客户资源。
