# PATHS — imboy-enterprise-uiux-v1（T04 冻结）

冻结时间：2026-10-19T11:16:01Z｜冻结者：协调器（session a7661d43…）｜修改须递增 contract_revision 并走迁移

## 变量绑定（真值）

| 变量 | 值 | 依据 |
|---|---|---|
| PACKAGE_ROOT | `/Users/leeyi/project/imboy.pub/.worktrees/imboy-enterprise-uiux-v1/docs/plans/enterprise-uiux-v1` | T00 归档（registry.active_package） |
| SOURCE_ROOT | `/Users/leeyi/project/imboy.pub/imboyapp` | 只读源仓库（main 基线） |
| WORKTREE | `/Users/leeyi/project/imboy.pub/.worktrees/imboy-enterprise-uiux-v1` | 集成 worktree（lane 建立前为默认执行树；T05/T06 后页面卡在各自 lane，最终门回集成树） |
| FLUTTER_EXE | `/Users/leeyi/dev/flutter/bin/flutter` | 无 FVM（无 .fvmrc）；直接 wrapper，单元素 argv 前缀 |
| SDK_REALPATH_HASH | `7a1a3c8f08e3eeba…`（sha256(realpath)） | 资源锁 key 身份 |
| UIUX_BASE_SHA | `c61cd8d46e276496b2ddae8b89b17d6fe6856ddc` | T00 基线（main 提交 HEAD） |
| GOLDEN_*(candidates/sealed/assembled) | `<common-dir>/imboy-uiux/imboy-enterprise-uiux-v1/golden/...` | 见下「Golden 存储模式」 |
| I18N_ARGV | `["/Users/leeyi/dev/flutter/bin/dart","run","slang"]` | pubspec slang ^4.19.2 + slang.yaml（无 build_runner 集成） |
| LEGACY_P1/P2/P3_ARGV | 见 commands.resolved.json | 逐文件实证存在（inventories §test 索引） |

## SDK 能力（静态取证，未运行 SDK 命令、未抢占缓存）

- Flutter 3.47.7 stable（framework `abaf9c5237…`，engine `deb287481e…`，Dart 3.13.5）——读取
  `bin/cache/flutter.version.json`（只读缓存文件）。
- TextScaler 可用（Flutter ≥3.16 稳定 API，测试合同 §7 用当前 SDK 支持）。

## i18n（slang）

- 源：`assets/i18n/<locale>/<namespace>.i18n.yaml`（base zh-CN，namespace 开启）；
  产物：`lib/i18n/strings_<locale>.g.dart` + `strings.g.dart`。
- 生效 locale（10）：zh-CN(基础)、zh-Hant、en-US、ja-JP、ko-KR、fr-FR、de-DE、ru-RU、it-IT、ar-SA。
- 生成命令：`dart run slang`（两次运行第二次无变化 = 幂等证据，T06 执行）。

## Golden 存储模式：**EXTERNAL_PINNED**（W0 冻结）

- 依据：仓库 `.gitignore` L212-214 `test/**/goldens/` 不入库（2026-10-17 用户确认的既有策略）→ 不得为方便改全仓 ignore（TRACKED 前提不成立）。
- sealed 基线：`/Users/leeyi/project/imboy.pub/imboyapp/.git/imboy-uiux/imboy-enterprise-uiux-v1/golden/pN/sealed/<manifest-hash>/`；本计划必需 golden 测试在目录/图/manifest 缺失时**失败而非 skip**；
  测试环境显式绑定 `UIUX_GOLDEN_BASELINE_ROOT`（组合只读根 `/Users/leeyi/project/imboy.pub/imboyapp/.git/imboy-uiux/imboy-enterprise-uiux-v1/golden/assembled-sealed`，由 T22—24.b 物化并记 hash）。
- 恢复演练（T29）：临时 hydration→普通比较→删一图必败。

## 页面/测试源映射（old→new 唯一）

| 页 | 现有文件（改动目标） | 既有定向测试 |
|---|---|---|
| P1 | `lib/page/workspace/workspace_channel_detail_page.dart`、`lib/page/channel/channel_detail_page.dart`、`lib/page/channel/widgets/channel_header_bar.dart`、`lib/page/channel/widgets/channel_message_feed.dart`、（只读引用）`channel_discussion_entry.dart`、`nodata_view.dart`* | LEGACY_P1_ARGV 5 文件 |
| P2 | `lib/modules/enterprise_oa/presentation/enterprise_workbench_page.dart`、`lib/page/workspace_shell/enterprise_shell_page.dart`、（只读引用）`cs_workspace_entry.dart` | LEGACY_P2_ARGV 4 文件 |
| P3 | `lib/modules/customer_service/presentation/cs_queue_view.dart`、`cs_session_list_view.dart`（掩码/格式化 domain 只读调用） | LEGACY_P3_ARGV 5 文件 |

*nodata_view.dart 为共享组件：仅当 P1-03 需要补 title/description 结构参数时允许**向后兼容**扩展（默认参数不破坏其他调用者），并在 ALLOWLIST 登记。

新增测试统一落位：`test/uiux/contract|p1|p2|p3|golden/`（T05 harness 起）。
