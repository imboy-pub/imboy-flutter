# AI 真机回归规格索引

`specs/` 是 AI 真机回归的权威输入；本文件由 `python3 scripts/auto_test.py report` 生成。
真实通过必须以 `reports/<run-id>/summary.json` 为证据；本索引不记录假绿。
完整页面迁移队列见 [AI_COVERAGE_MATRIX.md](./AI_COVERAGE_MATRIX.md)：样板页不等于全页功能已覆盖。
建议的下一批规格见 [AI_SPEC_BACKLOG.md](./AI_SPEC_BACKLOG.md)：必须先完成风险与数据前置分级。

## 三期落地状态

| 期次 | 交付 | 状态 |
|---|---|---|
| 一期 | JSON 规格、静态校验、视觉准则与报告生成 | 已落地 |
| 二期 | 6 个 P0 页面样板、源码/测试映射、关键入口语义标识样例 | 已落地；视觉基线待真机采集 |
| 三期 | 改动影响分析、dry-run/显式执行编排、可归档报告 | 已落地 |

## 样板 case

| Case | 风险 | 页面 | 执行器 | 截图检查点 | 视觉基线 | 高风险门禁 |
|---|---|---|---|---|---|---|
| `CHAT-PAGE-001` | P0 | 单聊消息展示、输入与发送状态 | `integration_test/e2e_chat_test.dart` | `c2c_01_chat_page`<br>`c2c_02_after_send` | 待真机采集 | 是 |
| `CONVERSATION-LIST-001` | P0 | 会话列表、搜索与进入聊天 | `integration_test/chat/conversation_test.dart` | `conv_03_conversation_list`<br>`conv_search_typed` | 待真机采集 | 否 |
| `E2EE-BACKUP-IMPORT-001` | P0 | E2EE 备份导入前置与危险操作门禁 | `integration_test/mine/mine_subpages_smoke_test.dart` | `e2ee_01_backup_import` | 待真机采集 | 是 |
| `GROUP-SCHEDULE-001` | P0 | 群日程列表、创建入口与详情导航 | `integration_test/group/group_collaboration_readonly_test.dart` | `group_schedule_01_list` | 待真机采集 | 否 |
| `PASSPORT-LOGIN-001` | P0 | 登录与主界面可见 | `integration_test/smoke/smoke_test.dart` | `smoke_01_main_shell` | 待真机采集 | 否 |
| `WALLET-TRANSFER-001` | P0 | 钱包余额、转账校验与确认界面 | `integration_test/wallet/wallet_readonly_test.dart` | `wallet_01_readonly` | 待真机采集 | 是 |

## 使用

```bash
python3 scripts/auto_test.py validate
python3 scripts/auto_test.py plan --phase p0
python3 scripts/auto_test.py impact lib/page/wallet/transfer_send_page.dart
python3 scripts/auto_test.py run --phase p0 --device <真实设备ID> --dry-run
python3 scripts/auto_test.py capture --case CONVERSATION-LIST-001 --device <Android真实设备ID>
```
