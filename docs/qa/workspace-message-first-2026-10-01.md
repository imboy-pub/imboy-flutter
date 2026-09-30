# 企业空间默认进入消息 / Workspace opens messages first

日期：2026-10-01；App 基线 f2ac7a7925ed73fc86ad8b9fd8fc5d5a0c7eb518。

冷启动、切企业、切工作区及创建/加入成功后的默认目的地为授权消息列表。功能关闭使原目的地不可见时，同样回落消息，并按实际目的地决定顶栏，避免重复顶栏。用户主动选择概览等页面后，同工作区选择、无效选择及普通刷新保持其页面；另一企业加入回填不改变当前企业页面。

English summary: Default enterprise workspace entry opens authorized conversations. Explicit navigation and unrelated organization updates preserve the current destination.

## 验证 / Checks

修复前切企业后进入消息的验收失败；修复后以下 49 项测试通过（exit=0）：

```sh
flutter test test/unit_test/page/workspace_shell/workspace_shell_provider_test.dart test/unit_test/page/workspace_shell/workspace_shell_page_test.dart test/unit_test/page/workspace_shell/workspace_organization_selection_test.dart test/unit_test/page/workspace_shell/workspace_restore_test.dart test/unit_test/page/workspace/workspace_conversations_page_test.dart
```

两源文件与三个修改测试 dart analyze 无问题；格式及 diff 检查通过。覆盖冷启动、切换失败/迟到响应、显式页面保留、加入回填、移动/桌面高亮、项目隐藏回落和授权消息列表。

## 尚未完成 / Limits

局部本地验证；没有真机或完整导航改版证明。现有五项导航仍待收敛为定稿企业三/四项；个人四项、组织目录、企业频道合并、统一选择器、OA 工作台与老板治理仍须逐项闭环。未部署。本轮按共享函数调用链人工复核，未使用独立审查代理。

## 内容绑定 / Source hashes

| File | SHA256 |
|---|---|
| lib/page/workspace_shell/workspace_shell_provider.dart | `07dbd1844913404ca55c90114f0e7ca0f84bac5da274fdf457ebb8279afd506b` |
| lib/page/workspace_shell/workspace_shell_page.dart | `ffc7c002c78329a5bd14d0142223380b94a5fa0efe68a70f7c716bae521f84ae` |
| test/unit_test/page/workspace_shell/workspace_shell_provider_test.dart | `714cd1e2bea2e76535027839d8833a618239d179e1fce330f88dd1477415a8ab` |
| test/unit_test/page/workspace_shell/workspace_shell_page_test.dart | `da4ebf3ec7eacadc0f1653ff88b7f6104213142da5ac5c20d4c7f4d5812341bc` |
| test/unit_test/page/workspace_shell/workspace_organization_selection_test.dart | `890215f8afb74d8f31f3df61044cfe7925044499788b3392d0f9997172c59021` |
