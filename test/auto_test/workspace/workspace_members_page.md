# `page/workspace/workspace_members_page.dart`

> 功能点 13 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 壳内必有工作区上下文，该页无工作区场景入口不可达 | `page/workspace/workspace_members_page.dart` | 无当前工作区时整页空态提示先加入或创建工作区 | 未测 | 批次W2R2 | 0 | 0 | 0 | 缺无工作区上下文的进入路径 |
| 阻塞 | 成员页无下拉刷新且切Tab不失效，列表错误态不可触达 | `page/workspace/workspace_members_page.dart` | 成员列表先显示加载态，加载失败展示错误消息与重试按钮重新拉取 | 未测 | 批次W2R2 | 0 | 0 | 0 | 断网实测：仅 init 层错误视图+重试可用（恢复后重试成功）；观察项：列表级刷新入口缺失 |
| 待修复 | 2026-08-31 | `page/workspace/workspace_members_page.dart` | 成员行渲染头像/昵称（空则账号）/@账号/角色徽标（Owner/Member/Guest 三色） | 有BUG待修 | 批次W2R2 | 1 | 0 | 1 | 含操作按钮的行昵称不可见（Owner自己行/只读视图正常，语义树有文本）；头像/@账号/徽标三色 Owner蓝Member绿Guest灰 已实证 |
| 阻塞 | 成员列表恒含Owner，空态不可达 | `page/workspace/workspace_members_page.dart` | 成员列表为空时空态展示标题与副标题提示 | 未测 | 批次W2R2 | 0 | 0 | 0 | 缺空列表场景 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | Owner 顶部展示邀请按钮，点击进入邀请向导页 /workspace/:wsId/members/invite | 已通过 | 批次W2R2 | 0 | 0 | 0 | 邀请按钮进向导页已验（见邀请向导页行1） |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | Owner 视角其他成员行展示移除/改角色/转移按钮，自己所在行不展示 | 已通过 | 批次W2R2 | 0 | 0 | 0 | Owner视角乙/戊行有移除/改角色/转移三按钮；甲自己行无 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 移除成员弹确认弹窗，确认后调用 API 并刷新列表与 Overview，409 冲突清单由服务端消息透出 | 已通过 | 批次W2R2 | 0 | 0 | 0 | 弹窗文案含409冲突说明；取消零请求；确认移除 API 2xx+DB removed+列表刷新；409实际触发未测 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 改角色弹 ActionSheet 三选（Owner/成员/访客），选择后成功刷新列表 | 已通过 | 批次W2R2 | 0 | 0 | 0 | ActionSheet Owner/Member/Guest 三选；乙 Guest↔Member 双向切换成功徽标变色 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 仅非 Guest 且非本人成员展示转移 Owner 按钮，确认弹窗后转移并刷新（最后 Owner 保护由服务端兜底） | 已通过 | 批次W2R2 | 0 | 0 | 0 | 转移确认弹窗语义完整；转移后甲降Member乙升Owner（角色互换UI刷新）；已API转回核验DB |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | Owner 底部治理区展示 Branding 入口，点击进入 /workspace/:wsId/branding 编辑页 | 已通过 | 批次W2R2 | 0 | 0 | 0 | Branding 入口进编辑页（名称回填20/200+Logo+主色预览+保存） |
| 阻塞 | 弹窗+取消已验；成功流转待临时工作区（种子区归档影响后续批次） | `page/workspace/workspace_members_page.dart` | 治理区归档/恢复入口弹确认弹窗，成功后壳状态同步且归档横幅显隐立即生效 | 未测 | 批次W2R2 | 0 | 0 | 0 | 归档弹窗文案完整（归档后全员只读可随时恢复），取消零写操作 |
| 阻塞 | 依赖真实归档流转 | `page/workspace/workspace_members_page.dart` | 已归档工作区顶部展示归档横幅，邀请/移除/改角色等写操作按钮禁用（服务端 980 兜底） | 未测 | 批次W2R2 | 0 | 0 | 0 | 同上 |
| 无待办 | - | `page/workspace/workspace_members_page.dart` | 非 Owner（Member/Guest）不显示邀请按钮与治理区，成员行无操作按钮（只读视图） | 已通过 | 批次W2R2 | 0 | 0 | 0 | 转移期间甲=Member实证：邀请按钮/治理区/行操作按钮全部消失（只读视图） |
