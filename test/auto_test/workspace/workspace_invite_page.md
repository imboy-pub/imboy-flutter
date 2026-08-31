# `page/workspace/workspace_invite_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 从成员管理页 Owner 邀请按钮进入 /workspace/:wsId/members/invite 邀请向导页 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 批次W2R2 实测：成员页邀请按钮进入向导页，说明文案+搜索框+三条结果区渲染完整 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 进入时后台定位模板资源（General 群与 Announcements 频道）供可选项使用 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 进入即 GET /workspaces/:id/groups+channels 定位模板资源（logcat），可选项显示 General/Announcements 名称 |
| 待修复 | 2026-08-31 | `page/workspace/workspace_invite_page.dart` | 输入关键词后键盘提交或点搜索按钮搜索已注册用户，搜索中按钮转圈，失败时红字提示错误 | 有BUG待修 | 批次W2R2 | 1 | 0 | 1 | 搜索成功路径可用（请求+转圈+结果）；失败红字未触发；用户ID搜索不可用：后端仅精确匹配 email/mobile/account，无 id 分支 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 搜索结果列出候选用户（昵称+@账号）并自动排除自己 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 搜 at20260831e 命中候选（昵称+@账号），结果仅 E 无自己；注：@形态账号被 email 分支劫持不可搜（allow_search=2 也不可搜） |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 点击候选行选中显示对勾并展开角色选择与可选项区（未选中时不显示提交区） | 已通过 | 批次W2R2 | 0 | 0 | 0 | 点候选行出对勾+展开角色分段+可选项+发送邀请按钮；未选中时无提交区 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 角色分段按钮在成员/访客间切换（默认成员） | 已通过 | 批次W2R2 | 0 | 0 | 0 | Member 默认选中；Guest↔Member 双向切换正常 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 可选项「加入 General 群」「订阅 Announcements 频道」默认勾选可取消 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 两项默认勾选；取消 General 勾选再勾回正常 |
| 阻塞 | 需模板资源缺失的工作区（常规创建必带 General/Announcements，无法触发定位失败） | `page/workspace/workspace_invite_page.dart` | 模板资源定位失败时对应勾选项禁用并提示不可用 | 未测 | 批次W2R2 | 0 | 0 | 0 | 缺负向场景构造手段 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 提交后结果区三条独立展示状态（加入工作区/加群/订阅频道各一行 running→success/failed） | 已通过 | 批次W2R2 | 0 | 0 | 0 | 发送后三行独立流转至「成功」绿勾；logcat 三个独立请求 members/invite→group_member/join→channel/subscribe；DB ws_member=1 |
| 阻塞 | 需故障注入使工作区邀请失败（后端拒 members/invite） | `page/workspace/workspace_invite_page.dart` | 工作区邀请失败时整单失败，两条可选关系不再发起（保持待处理） | 未测 | 批次W2R2 | 0 | 0 | 0 | UI 无失败注入手段 |
| 阻塞 | 需故障注入使可选关系失败（join/subscribe 被拒） | `page/workspace/workspace_invite_page.dart` | 可选关系单条失败互不影响，失败行支持单独重试 | 未测 | 批次W2R2 | 0 | 0 | 0 | UI 无失败注入手段 |
| 无待办 | - | `page/workspace/workspace_invite_page.dart` | 提交后返回成员管理页可见新成员（成员列表与 Overview 已失效刷新） | 已通过 | 批次W2R2 | 0 | 0 | 0 | 返回成员页第三张卡显示走查AT戊(Member)；成员列表已失效刷新 |
