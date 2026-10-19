# IMBoy UI/UX V1.1：逐项验收合同

计划ID：`imboy-enterprise-uiux-v1`｜37项初始未验；实际状态写execution/ACCEPTANCE_RESULTS.json/md，不能改合同消除义务。

自动、原生、真实恢复分开记账。N/A不豁免必需UI或golden；报告成功不代表产品成功。


## P1 验收项

- [ ] **AC-P1-01**（T10, T22, T25）：真实企业路由只有一个负责本级返回的导航入口；频道身份标题只出现一次；embedded/standalone都不重复；更多/DM/发布栏未丢。
- [ ] **AC-P1-02**（T11）：autoLoadStats=false时无永久统计骨架；已有订阅数来自现有字段；不新增请求，不混淆角色与真实创建者姓名。
- [ ] **AC-P1-03**（T15）：首屏失败有图标、标题、说明、可用重试；一次点击原回调一次；分页失败保留已加载内容。
- [ ] **AC-P1-04**（T12）：管理/静音或订阅/转发/分享中的原可见动作都可辨识；enabled/selected/disabled/pending分离；无空回调伪可用。
- [ ] **AC-P1-05**（T13）：讨论文案无箭头字符，尾部只有一个方向图标；一次点击到原群入口；中英文大字无溢出。
- [ ] **AC-P1-06a**（T14）：默认搜索+筛选入口；高级标签/分段不常驻；展开/收起保留条件且不产生额外请求；原筛选结果/提交语义不变。
- [ ] **AC-P1-06b**（T15）：空/无结果/首屏错误/初始加载下日期装饰为0；有日期装饰时其后存在真实内容项。

## P2 验收项

- [ ] **AC-P2-01**（T16, T23）：资源/应用/辅助登录入口为同一背景和分组容器；无上白下灰断裂、重复标题或空资源卡片。
- [ ] **AC-P2-02**（T17）：办公分组及OA直列入口为0，应用入口为1；OA entries、免登桥及现有按需签发未被删除。
- [ ] **AC-P2-03**（T17, T26）：应用行可见文本/tooltip/semantics不显示URL；原打开目标与bridge行为不变；未把隐藏URL宣称为生产化完成。
- [ ] **AC-P2-04**（T18）：客服/项目/群组/频道/附件/应用的实际可见行均有统一图标槽和文本起点；原权限、顺序、目标保持。
- [ ] **AC-P2-05**（T17, T26）：Android原条件确认登录入口仍在；空资源/隐藏坐席/feature关闭没有被“修复”为越权展示。

## P3 验收项

- [ ] **AC-P3-01**（T19, T20）：有安全摘要时，三个状态都展示；同掩码不同摘要能区分；没有安全摘要时遵守原隐私回退，局限已明确。
- [ ] **AC-P3-02**（T19, T24）：三态信息顺序一致；只有等待/接入动作按状态不同；大字自然增高，不塞空行假装三行相同。
- [ ] **AC-P3-03**（T21）：widget→网页咨询，未知→其他渠道，空→来源未知；文字/tooltip/semantics不暴露原枚举；协议原值不变。
- [ ] **AC-P3-04**（T27）：原掩码、org/workspace隔离、expected_version、分页游标、SSE、徽标、接单/打开行为全部保持；不推造未读/末条时间。

## Q 验收项

- [ ] **AC-Q-01**（T04.a, T29）：冻结候选完整diff未越过展示范围；Backend/Admin/数据库/业务模型未变；混合页面文件的业务函数也未被越权修改。
- [ ] **AC-Q-02**（T04.a, T12, T22, T23, T24）：样式取值来自现有Token，无新增Color字面量、Colors.*、数字fontSize；不关闭TextScaler。
- [ ] **AC-Q-03**（T22, T22.a, T22.b, T23, T23.a, T23.b, T24, T24.a, T24.b）：MATRIX.json规定312个配置的结构/图像/普通比较/审查分别计数；缺图或漏项不得skip；有环境和封存manifest证据。
- [ ] **AC-Q-04**（T22, T23, T24）：无overflow/裁剪/不可达按钮；命中区≥48；正文4.5:1，可操作状态视觉3:1；禁用语义不靠颜色猜。
- [ ] **AC-Q-05**（T25, T29, T26, T27）：定向回归通过；最终候选analyze零问题，全量Flutter测试通过；EUnit明确N/A；不把需要设备的integration当成已跑。
- [ ] **AC-Q-06**（T06）：所有当前支持语言键完整且生成可复现；i18n无并发生成覆盖。
- [ ] **AC-Q-07**（T29）：最终测试绑定冻结候选K；报告R单独白名单验证；记录渲染环境/输入及hash，代码变化证据STALE，报告不冒充新HEAD全量已测。

## R 验收项

- [ ] **AC-R-01**（T00, T04.b, T04.c）：registry把plan_id唯一映射到原集成与lane worktree；common-dir正确；不能通过随机新路径绕开恢复。
- [ ] **AC-R-02**（T28）：临时Git夹具覆盖活锁、commit未记账、dirty/漂移/证据失效、缺worktree；均有预期结果与退出码。
- [ ] **AC-R-03**（T28.m）：真的结束过一次会话，再用同一个提示词恢复；原worktree/branch/base与下一任务正确，无重复commit。未实做只能待验。
- [ ] **AC-R-04**（T00, T01, T02, T03, T04, T04.a, T04.b, T04.c, T05, T05.a, T06, T07, T08, T09, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20, T21, T22, T22.a, T22.b, T23, T23.a, T23.b, T24, T24.a, T24.b, T25, T26, T27, T28, T29, T33）：累计尝试、进程身份、锁owner/fencing、提交映射、下步动作持久化；没有reset/clean/stash吞改动，没有自动push/merge/部署。
- [ ] **AC-R-05**（T33）：所有任务可追提交/证据；T33在失败/阻塞时也能报告；报告成功不是产品PASS；原worktree及下一步明确。

## M 验收项

- [ ] **AC-M-P1**（T30, T30.a, T30.b）：P1在iOS/Android真机与macOS窗口分别有平台case证据；前置测试数据已授权，九张原生卡不得互相冒充。
- [ ] **AC-M-P2**（T31, T31.a, T31.b）：P2在iOS/Android真机与macOS窗口分别有平台case证据；前置测试数据已授权，九张原生卡不得互相冒充。
- [ ] **AC-M-P3**（T32, T32.a, T32.b）：P3在iOS/Android真机与macOS窗口分别有平台case证据；前置测试数据已授权，九张原生卡不得互相冒充。

## Q 验收项

- [ ] **AC-Q-08**（T00, T01, T02, T03, T04）：启动路径不依赖未来检查器；TASKS.json、TASKS.md、COMMANDS.json不出现空命令或产物前置循环。
- [ ] **AC-Q-09**（T22.a, T23.a, T24.a, T29）：测试图目录或manifest缺一项必需baseline则门禁非0，fresh checkout/外置归档恢复不能update后冒充旧图通过。
- [ ] **AC-Q-10**（T29, T33）：仅批准的报告路径可形成R；PRD/测试/配置/执行工具/golden变更不能走report-only豁免。

## R 验收项

- [ ] **AC-R-06**（T00, T04.c）：V1→V1.1迁移保留plan_id/原worktree/任务ID/commit/累计attempt；只对变更义务复验。
- [ ] **AC-R-07**（T04.b, T04.c, T28）：锁与状态案例调用实际运行模块；PREPARE/snapshot/COMMIT、PID复用、半行日志、活worker拒绝均有反例证据。
- [ ] **AC-R-08**（T04, T05, T33）：一个页面的颜色/字体/设备阻塞不构成无关卡硬依赖；状态调度使用真实依赖而非仅按任务数字递增。

## 必须填写的结果字段

| 字段 | 要求 |
|---|---|
| 代码候选 | candidate K SHA/tree；测试前后输入一致 |
| 报告附件 | 当前R SHA；report-only差异检查；不宣称R已全量验证 |
| 自动 | 每项NOT_RUN/PASS/FAIL/STALE/BLOCKED及证据；M4A通过才LOCAL_CANDIDATE_PASS |
| 原生 | iOS/Android/macOS逐平台case；九张人工卡通过才UX_ACCEPTED |
| 真实恢复 | T28.m两个真实会话证据；模拟测试不能替代 |
| 失败/缺资源 | 缺陷ID、影响AC、owner、下一动作；不清零累计attempt |
| Golden | expected/executed/compared/reviewed及环境/图hash；312配置不得漏项 |
| 授权 | merge main / push / deploy / 删除worktree均NOT_AUTHORIZED |

回归清单和case依据：[TEST_CONTRACT](TEST_CONTRACT.md)、[MATRIX](MATRIX.json)、[NATIVE_CASES](NATIVE_CASES.json)、[RECOVERY_CASES](RECOVERY_CASES.json)。
