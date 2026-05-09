# Pull Request — imboyapp (Flutter Client)

> 关联：`.claude/plans/quality-loop.md` v1.3 T4.5 / v1.1 §304 三仓各一份

## 摘要 / Summary

<!-- 一句话说明本 PR 解决什么问题 -->

## 改动类型 / Type of Change

- [ ] 🐛 Bug fix（非破坏性）
- [ ] ✨ Feature（新增功能）
- [ ] 🎨 UI / 🎬 Animation
- [ ] 💥 Breaking change（API 契约 / state schema 不兼容）
- [ ] 📝 Docs / 🌐 i18n
- [ ] 🔧 Refactor（不改行为）
- [ ] ⚡ Performance
- [ ] ✅ Tests / 🧪 CI

## 自检清单 / Self-Review

### 编码规范

- [ ] 遵守 [imboyapp/CLAUDE.md](CLAUDE.md) UI 设计规范（DESIGN.md §13 For Coding Agents）
- [ ] 颜色/间距/字号通过 `AppColors` / `AppSpacing` / `FontSizeType` Token，无硬编码
- [ ] 最小触达区 ≥ 44×44pt
- [ ] `MessageModel.id` 用 `String`（Xid base32hex），禁 `int.tryParse`
- [ ] 资源 URL 经 `AssetsService.viewUrl` 重新授权（`cachedImageProvider` / `Avatar`），禁 `Image.network`

### 状态管理

- [ ] 用 Riverpod，无新增 GetX 引入（已 100% 迁移完成）
- [ ] 路由用 go_router

### 质量门（自动跑，但请提前自查）

- [ ] `flutter analyze` 0 error / warning ≤ 830 / info ≤ 703（ratchet）
- [ ] `dart format .` 通过
- [ ] `flutter test` 全绿
- [ ] `flutter test --coverage` 不下降

### 契约变更（如适用）

- [ ] imboy 端 `api/openapi.yaml` 或 `proto/*.proto` 变更后 → 跑过 `bash imboy/api/codegen/dart.sh` 同步
- [ ] 生成代码 commit（受 analysis_options.yaml exclude 保护，但 git 跟踪）
- [ ] **Breaking change** → 已与 imboy / admin 同步发版

### 数据库 (SQLite)

- [ ] 改动 schema → 升 `_dbVersion`（当前 21）+ 写 migration 脚本到 `assets/migrations/`
- [ ] migration 幂等 + 含回滚说明

### 文档

- [ ] 新增 / 改动 Markdown → 双语（zh-CN 权威 + en），commit prefix `docs(bilingual):`
- [ ] 例外目录（仅中文）：`.claude/plan/*` / `.claude/memory/*` / 内部会议纪要

### 保留区（绝对不改）

- [ ] **未触碰** `ios/*` / `macos/*` / `plugin/r_upgrade`

### 安全

- [ ] 无 hardcoded credentials（gitleaks ratchet 22）
- [ ] Firebase / Apple 密钥通过受控生成文件（非源码）

## 关联 / Related

- Issue: #
- 主计划任务: <!-- 如 T3.6 / T5.1 -->
- 相关 PR (imboy / admin): <!-- 跨仓改动需链接 -->

## 测试计划 / Test Plan

<!-- 真机测试（Android 不许用模拟器）/ 影响范围 / Widget 测试覆盖 -->

## CI 触发的检查

本 PR 会自动跑（详见 `.github/workflows/`）：
- `quality.yml` → flutter-analyze + secrets-scan
- `sonar.yml` → SonarCloud 扫描（含 coverage trend）
- `ci.yml` / `core-automation.yml` / `integration_test.yml` → 业务 CI

合并前所有上述 status check 必须 ✅。
