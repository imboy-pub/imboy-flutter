# 执行状态快照 — imboy-enterprise-uiux-v1

更新：2026-10-19 B1 收口（夹具/环境/文案全部就绪）｜state revision 17｜状态：ACTIVE（B1 完成；下一批 B2，下一卡 T10）

| 批 | 卡 | 状态 |
|---|---|---|
| B0 | T00—T03 | DONE（PASS）：acceacde / dae918f6 / 4a728ead / e6c26e9f |
| B0 | T04 合同冻结 + T04.a/b/c 工具 | DONE（PASS）：3f9c2a46 / 233bfa2d / bbb53562 / 1cee8eb3 |
| B0 | M0 基线 | DONE：analyze exit=1 / 72 存量问题（改动前，evidence/M0/1） |
| B1 | T05 结构harness | DONE（PASS，bd91a79dd）：C-T05-1 6/6 无 skip |
| B1 | T05.a 视觉字体环境 | DONE（PASS，ff9ba066a）：C-T05-a-1 5/5；Arial Unicode sha256 登记（本地使用不分发） |
| B1 | T06 文案冻结 | DONE（PASS，47f02e3b3）：C-T06-1 4/4 + C-I18N 幂等；去箭头×10 locale、sourceWidget、键债 22+1 补齐 |
| B1 | T07 频道路由夹具 | DONE（PASS，5ef5366a3）：C-T07-1 11/11；八场景 + 真实内容组件 + gate fail-closed |
| B1 | T08 工作台入口夹具 | DONE（PASS，f529ddeb6）：C-T08-1 7/7；六输入场景 + 真实 CS tile + 点击 trace 基线 |
| B1 | T09 坐席三态夹具 | DONE（PASS，bada01525）：C-T09-1 8/8；真实 DTO 解析 + 固定时钟 + claim 409/403/in-flight |
| B2 | T10—T21（12 张实现卡） | TODO（**下一卡组**；T10/T13/T14 deps T07 ✓ READY） |

- base：`c61cd8d46`｜集成 HEAD：`bada01525`｜运行真源 events tx-0001..0017（rev17）
- 提交链（B1）：d553597d(R3)→bd91a79dd(T05)→ff9ba066a(T05.a)→47f02e3b3(T06)→5ef5366a3(T07)→f529ddeb6(T08)→bada01525(T09)
- 环境注记：子模块 `plugin/flutter_chat_ui`（7df955eb）已初始化；env_*.g.dart 本地生成物已就位（gitignored，从源工作区复制——build_runner 对 gitignored .env 的 aot 沙箱读取失败，本地以同等生成物替代，不视为通过证据）；.env* 六件已在 worktree（gitignored）
- 无 BLOCKED；golden=EXTERNAL_PINNED 冻结 + T05.a GOLDEN_ENV 字体/栅格环境就绪；STRUCTURE_ENV/GOLDEN_ENV 分离契约生效

## 下一卡与下一条命令

- 卡：**T10**（P1 收敛频道身份头部：ChannelHeaderBar 去重复大标题——P1-01 NEEDS_FIX 修复卡，夹具 T07 就绪）
- 命令：`flutter test test/uiux/p1/p1_fixture_smoke_test.dart`（夹具回归）+ T10 卡冻结命令（C-T10-1，见 COMMANDS.json）
