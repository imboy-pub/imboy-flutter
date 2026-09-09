# `page/workspace/workspace_invite_page.dart`

> 功能点 17 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 从成员管理页 Owner 邀请按钮进入 /workspace/:wsId/members/invite 邀请向导页 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 批次W2R2 实测：成员页邀请按钮进入向导页，说明文案+搜索框+三条结果区渲染完整 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 进入时后台定位模板资源（General 群与 Announcements 频道）供可选项使用 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 进入即 GET /workspaces/:id/groups+channels 定位模板资源（logcat），可选项显示 General/Announcements 名称 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 输入关键词后键盘提交或点搜索按钮搜索已注册用户，搜索中按钮转圈，失败时红字提示错误 | 已通过 | 批次W2R2FIX | 1 | 1 | 0 | 后端新增全数字→find_by_id 分支（imboy f019e2c6）；HTTP 实证 ID 搜索命中+account 回归+allow_search=2 拒绝；失败红字分支未触发（需故障注入） |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 搜索结果列出候选用户（昵称+@账号）并自动排除自己 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 搜 at20260831e 命中候选（昵称+@账号），结果仅 E 无自己；注：@形态账号被 email 分支劫持不可搜（allow_search=2 也不可搜） |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 点击候选行选中显示对勾并展开角色选择与可选项区（未选中时不显示提交区） | 已通过 | 批次W2R2 | 0 | 0 | 0 | 点候选行出对勾+展开角色分段+可选项+发送邀请按钮；未选中时无提交区 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 角色分段按钮在成员/访客间切换（默认成员） | 已通过 | 批次W2R2 | 0 | 0 | 0 | Member 默认选中；Guest↔Member 双向切换正常 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 可选项「加入 General 群」「订阅 Announcements 频道」默认勾选可取消 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 两项默认勾选；取消 General 勾选再勾回正常 |
| 阻塞 | 待环境恢复执行（批次145 解锁负向构造：本地 PG 对某工作区 DELETE 其 General 群行（如 AT-WS-空区-115 本就 0 channel 可用）→ 本页定位失败勾选项禁用路径可实测） | `page/workspace/workspace_invite_page.dart` | 模板资源定位失败时对应勾选项禁用并提示不可用 | 未测 | 批次W2R2 | 0 | 0 | 0 | 缺负向场景构造手段；批次145:DB 直改/空区工作区即负向 fixture |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 提交后结果区三条独立展示状态（加入工作区/加群/订阅频道各一行 running→success/failed） | 已通过 | 批次W2R2 | 0 | 0 | 0 | 发送后三行独立流转至「成功」绿勾；logcat 三个独立请求 members/invite→group_member/join→channel/subscribe；DB ws_member=1 |
| 阻塞 | 待环境恢复执行（批次145 解锁：adapterForTest 同 WIV1 配方拦 /api/v1/workspaces/:id/members/invite 注入失败，整单失败断言不改测试目标） | `page/workspace/workspace_invite_page.dart` | 工作区邀请失败时整单失败，两条可选关系不再发起（保持待处理） | 未测 | 批次W2R2 | 0 | 0 | 0 | UI 无失败注入手段；批次145:adapterForTest 即注入手段（WIV1 已证可行） |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 可选关系单条失败互不影响，失败行支持单独重试 | 已通过 | 批次153 | 2 | 2 | 0 | 注入手段=adapterForTest 拦 /api/v1/group_member/join（批次152 修正端点）；批次153 转绿：①join null 静默成功 bug 已修（GroupMemberApiException 透传服务端 msg，imboyapp 375ce7b2；另两调用方 catch 保 false 语义）②fixture=BobWS-T27 Announcements join_policy 0→1（模板默认 0 与 invitation 流不匹配——**模板策略是否改邀请制待用户拍板**）③前置清理遗留 channel_invitation ④FTS 仅命中精确账号 smoke_alice；测试代码批次152 收口（f1cfb0ef） |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 提交后返回成员管理页可见新成员（成员列表与 Overview 已失效刷新） | 已通过 | 批次W2R2 | 0 | 0 | 0 | 返回成员页第三张卡显示走查AT戊(Member)；成员列表已失效刷新 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | Owner 顶部展示团队码卡片（生成/复制/撤销），非 Owner 不显示该卡片 | 已通过 | 批次W2R5 | 0 | 0 | 0 | ACC_A(Owner) 见「团队码邀请」卡片+生成/复制/撤销；UID_F(Member) 成员页无邀请按钮、邀请页不可达（代码 _isOwner 守卫+服务端 403 兜底） |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 生成/重新生成团队码：展示 8 位码，重生成即撤旧码（一工作区恒一个 active 码） | 已通过 | 批次W2R5 | 0 | 0 | 0 | 生成 T4EEWZHR→重生成 39F8V2Y2：UI 码更新，DB 旧码 status=revoked、新码 active（uk_ws_active 唯一约束）；单次点击仅 1 个 POST |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 复制团队码到剪贴板并轻提示 | 已通过 | 批次W2R5 | 0 | 0 | 0 | 点复制 0.8s 内截图 toast「已复制到剪贴板」 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 撤销团队码后码清空，持旧码者输码加入即 981 无效 | 已通过 | 批次W2R5 | 0 | 0 | 0 | 撤销后卡片回 idle（码/有效期/复制/撤销消失）+DB revoked；UID_F 输被撤销码红字「团队码无效或已失效」留页 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 团队码过期时间以可读格式展示（expiresAtLabel → yyyy-MM-dd HH:mm） | 已通过 | 批次W2R5 | 0 | 0 | 0 | 卡片显示「有效期至 2026-09-07 21:02」可读格式 |
