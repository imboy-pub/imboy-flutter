# `page/workspace/workspace_members_page.dart`

> 功能点 13 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待首测 | - | `page/workspace/workspace_members_page.dart` | 无当前工作区时整页空态提示先加入或创建工作区 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | 成员列表先显示加载态，加载失败展示错误消息与重试按钮重新拉取 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | 成员行渲染头像/昵称（空则账号）/@账号/角色徽标（Owner/Member/Guest 三色） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | 成员列表为空时空态展示标题与副标题提示 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | Owner 顶部展示邀请按钮，点击进入邀请向导页 /workspace/:wsId/members/invite | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | Owner 视角其他成员行展示移除/改角色/转移按钮，自己所在行不展示 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | 移除成员弹确认弹窗，确认后调用 API 并刷新列表与 Overview，409 冲突清单由服务端消息透出 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | 改角色弹 ActionSheet 三选（Owner/成员/访客），选择后成功刷新列表 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | 仅非 Guest 且非本人成员展示转移 Owner 按钮，确认弹窗后转移并刷新（最后 Owner 保护由服务端兜底） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | Owner 底部治理区展示 Branding 入口，点击进入 /workspace/:wsId/branding 编辑页 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | 治理区归档/恢复入口弹确认弹窗，成功后壳状态同步且归档横幅显隐立即生效 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | 已归档工作区顶部展示归档横幅，邀请/移除/改角色等写操作按钮禁用（服务端 980 兜底） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/workspace_members_page.dart` | 非 Owner（Member/Guest）不显示邀请按钮与治理区，成员行无操作按钮（只读视图） | 未测 | - | 0 | 0 | 0 | |
