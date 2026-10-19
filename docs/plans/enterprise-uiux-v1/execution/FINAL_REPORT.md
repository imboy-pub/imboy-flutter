# FINAL REPORT（首轮 / B0 收口）— imboy-enterprise-uiux-v1

报告时间：2026-10-19（B0 收口更新）｜report_revision：3｜触发事件：batch_end（B0 完成，M0 门关闭）
**候选 K：NOT_VERIFIED**（T29 未执行；本报告不构成任何产品通过等级）

## 1. 计划身份与现场

| 项 | 值 |
|---|---|
| plan_id / 合同 | `imboy-enterprise-uiux-v1` / V1.1 PATHFIX-R1（package_release_hash `b8301b14e9870d10…`） |
| repo / base | `/Users/leeyi/project/imboy.pub/imboyapp`（main）@ `c61cd8d46e276496b2ddae8b89b17d6fe6856ddc`（干净，无外来 dirty） |
| 集成 worktree / 分支 | `/Users/leeyi/project/imboy.pub/.worktrees/imboy-enterprise-uiux-v1` @ `ux/imboy-enterprise-uiux-v1-integration` |
| 当前 HEAD | `3f9c2a46`（T04）；链：acceacde(T00)→dae918f6(T01)→4a728ead(T02)→e6c26e9f(T03)→450fce96(R1)→3f9c2a46(T04) |
| 运行真源 | `<common-dir>/imboy-uiux/imboy-enterprise-uiux-v1/`（registry rev·state revision 4·events tx-0001..0004·admission epoch1 ACTIVE） |
| owner | zcode-cli PID 2525 / session a7661d43…（心跳随事务刷新） |

## 2. 已完成（自动义务）

| 卡 | 提交 | 内容 | 验证 |
|---|---|---|---|
| T00 | `acceacde` | bootstrap：runtime/registry/state/events/admission、集成 worktree、发行包归档+自检（源与归档副本双 exit=0） | C-PACKAGE/C-BOOT-GIT/C-BOOT-WORKTREES exit=0；parent/trailer/tree 核验 |
| T01 | `dae918f6` | P1 inventory：P1-01/03/04/05/06 NEEDS_FIX，P1-02/07 VERIFY_EXISTING，subscriber 0/未知数据边界 | 符号级源码取证（inbox/T01/1） |
| T02 | `4a728ead` | P2 inventory：P2-01/02/03 VERIFY_EXISTING，P2-04/05 NEEDS_FIX（图标槽/空组壳） | 符号级源码取证（inbox/T02/1） |
| T03 | `e6c26e9f` | P3 inventory：P3-01/02/05 VERIFY_EXISTING，P3-03 NEEDS_FIX（source wire 外露/'Web' 硬编码），未读/末条时间确认不在本版 | 符号级源码取证（inbox/T03/1） |

## 3. 待验 / 未运行

- T04—T32 全部 TODO（含 T04.a/b/c 工具、T05—T21 页面实施、T22—24 golden、T25—27 调用回归、T28 恢复演练、T29 最终门）。
- 312 golden：未生成（0/312）；原生 51 场景：MANUAL_PENDING；T28.m 跨会话：未发生（不能自称 verified）。
- 全量 Flutter analyze/test：NOT_RUN（M0 门尚缺 T04）。

## 4. 阻塞与风险

- 无当前 BLOCKED。已知待决点（非阻塞）：P1 重复标题根因在 ChannelHeaderBar；P2 空组壳需 T13 可见性投影方案；P3 来源映射需新 i18n 键。
- 旧计划 `imboyapp-uiux-v1`（已 COMPLETE、锁 RELEASED）目录/注册表保留原样，未接管。

## 5. 下一步

T04 已完成（3f9c2a46：47 命令零未解析、EXTERNAL_PINNED、白名单冻结）。下一卡：**T04.a** scope 工具（tool/uiux/check_scope.py + 正反例自测），随后 T04.b locks、T04.c state 事务工具。
下一条命令：实现 check_scope.py 后在集成树运行 `python3 tool/uiux/check_scope.py --base c61cd8d46…` 并保存退出码证据。

## 6. 幂等与边界

- 本报告由 batch_end 事件触发一次；report_input_hash 已随 revision 1 登记，未变不重复提交。
- 本提交 R 仅改动 REPORT_ONLY_ALLOWLIST 内路径（STATUS.md/FINAL_REPORT.md/ACCEPTANCE_RESULTS.*）；K 未冻结，R 不引用任何"已全量验证"结论。

## 7. revision 2 附记

T04 完成于 revision 2 前（tx-0006）；命令冻结要点：FLUTTER_EXE 直连 wrapper（无 FVM）、i18n=dart run slang（10 locale）、golden=EXTERNAL_PINNED（.gitignore test/**/goldens/ 既有策略）。M0 门剩余 T04.a/b/c。

## 8. revision 3 附记（B0 收口 / M0 门关闭）

- T04.a scope 门（233bfa2d）：自测 5/5（负例非 0）；真实树 PASS（45 路径，committed+untracked）。
- T04.b 进程锁（bbb53562）：自测 7/7——活 owner 拒绝、PID 复用拒绝、超时≠接管、旧 epoch 释放拒绝、子进程存活阻断接管、未知身份 fail-closed、实弹 kill -9 后接管 epoch+1。
- T04.c 状态事务（1cee8eb3）：自测 7/7——悬空 PREPARE 不采纳、缺 COMMIT 只补记一次、撕裂尾行隔离+截断、revision 冲突拒绝、example 不可覆盖 live、枚举词表、只读校验不放行缺 COMMIT；真实 runtime check_state valid（rev10）。
- M0 基线：`flutter analyze --fatal-infos` exit=1 / **72 存量问题**（改动前记录；新 worktree 曾因子模块未初始化解析失败，已按固定 commit 7df955eb 初始化 `plugin/flutter_chat_ui`，pubspec.lock 未动）。Erlang EUnit=N/A。
- 下一卡：T05（结构 harness）+ T05.a（视觉字体环境，独立记账）；T33 保持可重复报告。

## 9. revision 4 附记（B1 收口 / 夹具·环境·文案就绪）

- T05 结构 harness（bd91a79dd）：C-T05-1 6/6 无 skip——真实 AppTheme 构建器挂载 + TranslationProvider + UiuxViewport(360×800/1280×800)/平台/locale/TextScaler 参数化；平台覆盖 pumpUiux 返回前 try/finally 同步复位（flutter_test foundation invariant 检查早于 dart-test addTearDown，实测踩坑并记入夹具注释）；冻结时钟仅作断言输入；STRUCTURE_ENV.md 契约落盘。
- T05.a 视觉环境（ff9ba066a）：C-T05-a-1 5/5——Arial Unicode（/Library/Fonts，sha256 876af2cd…，macOS 附带仅本地使用不分发）+ 最小 cmap(3,1) fmt4 解析器验证 28 必需 CJK 码点；Ahem/hash 不匹配/缺失一律 visualBlocked（绝不静默降级）；goldenEnvironmentHash 覆盖字体/SDK/Dart/OS/locale/DPR/emoji 策略；emoji=forbidden-in-golden-fixtures；GOLDEN_ENV.md 落盘。
- T06 文案（47f02e3b3）：C-T06-1 4/4 + C-I18N 两次 slang 幂等（modulo 'Built on' 时间戳行，如实记账）——discussInGroupGuide 10 locale 去箭头（P1-05）；customerService.sourceWidget（zh-CN/en-US，其余 locale 既有回退现状）；键债补齐 22 workspace 键 + enterpriseOa.apps（9/8 locale）；parity 断言对 slang 参数注解 `key(param)` 归一化。
- T07 频道夹具（5ef5366a3）：C-T07-1 11/11——真实 WorkspaceChannelDetailPage/ChannelDetailPage/ChannelMessageFeed；替身仅 provider override（channelDetail 带调用 trace、静默语音）；微社区门不 mock（fail-closed 断言）；八场景 + autoLoadStats:false 消测试期出站；StorageService 内存 mock（publish bar 草稿路径）。
- T08 工作台夹具（f529ddeb6）：C-T08-1 7/7——真实 CsWorkspaceEntryTile（风险项点名覆盖）+ shell 同构 resourceEntries；六输入场景（无工作区/普通成员/有坐席/feature 关闭/有 OA/Android inbound）；HttpClient.adapterForTest 拦截；点击 trace 基线=csWorkspace push。
- T09 坐席夹具（bada01525）：C-T09-1 8/8——合成 wire DTO 走真实 CsQueueItem.fromJson（DTO 未动）；固定时钟=queued_at 偏移回推；三态摘要（有/缺失/无消息兜底'页面数据不存在或已失效'）+ 同掩码不同摘要 + 来源三态（widget→Web/未知/空隐藏，二次掩码实证）+ claim in-flight 禁用与 CAS body 记录/409 刷新/403 无 crash。
- 运行真源：rev17（tx-0012..0017）；无 BLOCKED；312 golden 仍未生成（B3 才开始）；K 未冻结。
- 下一批 B2：T10（P1 频道身份头部收敛，P1-01 修复）等 12 张实现卡，T10/T13/T14 依赖 T07 已 READY。

## 10. revision 5 附记（B2 收口 / P1·P2·P3 实现与验证全绿）

- T10（c3f98c4f9）：ChannelHeaderBar showIdentityTitle 参数（默认 true，唯一调用方详情页选紧凑），认证徽标并入元信息行；P1-01 双标题消除；standalone GlassAppBar/embedded 宿主 AppBar 均保持唯一标题与一次返回。
- T11（aff8b5ad5）：P1-02 VERIFY_EXISTING——2026-10-17 兜底修复已正确，按卡 change 仅补 4 断言（无骨架/兜底直显无 /stats 请求/服务端真实值不伪造/无新增请求）。
- T12（7c3ffd056）：_buildCircleActionItem onTap 可空化——回调缺失与 pending 一律禁用（onPressed=null + iosGray3 弱化色），全部 `?? (){}` 假可用回退删除；可用图标对比度 ≥3:1、命中 ≥48×48、静音保持可切换；静音函数与权限来源未动。
- T13（e53e38248）：讨论横幅唯一尾部 chevron（RTL 镜像 + ExcludeSemantics）；T06 无箭头文案联动断言；en deferred 库必须经 tester.runAsync 加载（FakeAsync 下永挂）且 setLocale 为异步（setLocaleSync 抛 _DeferredNotLoadedError）——已记入夹具注释。
- T14（fa9e833bf）：高级筛选默认折叠（常驻搜索+入口，_searchActive 主色指示）；_advancedOpen 纯本地状态不动查询语义与 provider 参数；controller 常驻收起不丢条件；收起先 unfocus；微社区门经真实 FeatureScope/manifest/registry 测试接线开启（不 mock gate）。
- T15（995527db5）：两处错误视图补两段结构（安全标题 + 固定说明复用 enterpriseOa.statusErrorHint 现有键）+ 既有 loadChannel 重试；空/无结果零孤立日期；只读空态无发布 CTA。
- T16（d11f87f64）：三组 CupertinoListSection.insetGrouped → _GroupedSection（同 token 同节奏，高度随子项自然收缩）——CS gate 隐藏（shrink）后不再留空壳卡（P2-05）；可见性仍在子 gate 内。
- T17（ae6f90d58）：P2-02/03 VERIFY_EXISTING 仅补测试：办公入口 0/应用入口 1、URL 不进文本/语义/提示、tap 保留目的地与桥、Android inbound 保持；webview 平台替身按官方 example 模式。
- T18（21cb90401）：CS 行 29×29→24 槽、shell._resourceEntry 与 workbench 行统一 24 槽 + 垂直 padding 达 ≥48 命中；可见性表达式与 onTap 未动；ALLOWLIST 首次修订（T18 write_paths 授权的 cs_workspace_entry.dart 投影遗漏补录）。
- T19/T20/T21（285537bb6，单原子提交）：CsSessionRowContent 纯展示提取（名→摘要→来源）；摘要三态与 ≤2 行合同；csSourceDisplayLabel 映射（widget→sourceWidget，未知/空→t.common.unknown，wire 不外露）；两页保留各自 fetchPage/claim/open；DTO/HTTP 未动。三卡解耦回滚=整体 revert（消息内声明）。
- gate 修复（688a5c8b3，T04.a 追加）：声明正则类型段混入 \s 导致缩进裸调用行误判为声明（T19 实测假阳性）；diff 新增行坐标被同时与 base/HEAD 范围判交（挪动代码假阳性）。双修复 + 新回归用例，自测 6/6。
- 运行真源：rev30（tx-0019..0030）；无 BLOCKED；312 golden 未生成（B3）；K 未冻结。
- 下一批 B3：T22（P1 结构矩阵）等 9 卡 + T25—T27 调用回归，deps 全满足。
