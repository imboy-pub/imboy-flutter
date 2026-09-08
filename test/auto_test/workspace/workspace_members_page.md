# `page/workspace/workspace_members_page.dart`

> 功能点 13 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | 零工作区账号 | `page/workspace/workspace_members_page.dart` | 无当前工作区时整页空态提示先加入或创建工作区 | 已通过 | 批次121 | 0 | 0 | 0 | 批次121实测(AT-WS1~WS4,macOS)：零工作区登录落点=bootstrap 引导页（还没有工作区+创建/加入/切换到个人/重试四入口）整页空态实证；tab 页 WorkspaceEmptyView 为防御分支（零工作区时 shell 不挂载），空态职责由引导页等价承担（AT-WS5 深链 /workspace/members 被「请先选择或创建一个工作区」拦截） |
| 无待办 | 幽灵工作区注入(非法wsId=999999999) | `page/workspace/workspace_members_page.dart` | 成员列表先显示加载态，加载失败展示错误消息与重试按钮重新拉取 | 已通过 | 批次121 | 0 | 0 | 0 | 批次121实测(AT-WS7,macOS)：同 WS6 幽灵注入法，403 透出+重试可点；members provider 分页拉取错误视图渲染慢，waitFor 放宽 30s（与 WS6 同款） |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 成员行渲染头像/昵称（空则账号）/@账号/角色徽标（Owner/Member/Guest 三色） | 已通过 | 批次W2R4 | 1 | 1 | 0 | W2R4 重设计页（ea682e31 单卡片分组+细分隔线+成员数小节头）复测：甲/乙行头像/昵称独占整行/@账号单行截断/Owner蓝·Member绿·Guest灰三色徽标（乙 Guest 态实测）均正常 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 成员列表为空时空态展示标题与副标题提示 | 已通过 | 批次131 | 0 | 0 | 0 | AT-WVM1 全绿（integration_test/workspace/workspace_members_empty_test.dart）：adapterForTest 注入空 members payload（code=0+list 默认空）→ 深链 /workspace/members 显示「暂无工作区成员」标题+邀请副标题且稳定展示；「成员列表恒含Owner」定性推翻——注入空 payload 即可构造，无需删改 DB；配方同批次130 AT-WOV1 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | Owner 顶部展示邀请按钮，点击进入邀请向导页 /workspace/:wsId/members/invite | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 重设计页：FilledButton 邀请按钮进向导页实测正常（WS2；见邀请向导页行1） |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | Owner 视角其他成员行展示移除/改角色/转移按钮，自己所在行不展示 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：重设计后行操作紧凑为三个图标按钮（key 不变）；Owner 视角乙行三按钮在位、自己行无，甲/乙双账号互验 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 移除成员弹确认弹窗，确认后调用 API 并刷新列表与 Overview，409 冲突清单由服务端消息透出 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 重设计页：确认弹窗（含409说明）→POST remove→**409 冲突 toast 透出实测**（「membership_conflict：该用户有未完成任务（任务-调研）…」，批次W2R2 遗留「409 实际触发未测」就此闭环）；成功移除路径因该服务端冲突保护不可复现，批次W2R2 的 2xx+DB removed+列表刷新证据沿用 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 改角色弹 ActionSheet 三选（Owner/成员/访客），选择后成功刷新列表 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：ActionSheet 三选在位；乙 Member↔Guest 双向切换徽标变色+API 2xx；Guest 态转移按钮按规则消失/回 Member 复现 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 仅非 Guest 且非本人成员展示转移 Owner 按钮，确认弹窗后转移并刷新（最后 Owner 保护由服务端兜底） | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：确认弹窗语义完整→转移→甲降Member乙升Owner 角色互换 UI 刷新；并登录乙经 UI 转回（双向均在新布局真机实测，DB 复原） |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | Owner 底部治理区展示 Branding 入口，点击进入 /workspace/:wsId/branding 编辑页 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：治理区卡片 Branding 入口进编辑页；WS1(FF0000)/WS2(FF6600) 名称回填+主色预览正常 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 治理区归档/恢复入口弹确认弹窗，成功后壳状态同步且归档横幅显隐立即生效 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：归档弹窗→POST archive 2xx→橙横幅即现+邀请灰禁+入口切「恢复」红字；恢复→横幅消失邀请复蓝（API log 双证） |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 已归档工作区顶部展示归档横幅，邀请/移除/改角色等写操作按钮禁用（服务端 980 兜底） | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：新布局归档态橙横幅在位、邀请按钮 disabled、成员卡操作入口随 archived 切换（单成员工作区实测；批次W2R3 多成员移除/改角色按钮整体隐藏对照沿用） |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 非 Owner（Member/Guest）不显示邀请按钮与治理区，成员行无操作按钮（只读视图） | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4：转移期间甲=Member 实证邀请按钮/治理区/行操作按钮全部消失（新布局复现批次W2R2 只读视图结论） |
