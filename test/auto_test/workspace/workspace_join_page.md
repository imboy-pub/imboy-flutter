# `page/workspace/workspace_join_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/workspace_join_page.dart` | 账户 Sheet「加入工作区」常驻入口进入 /workspace/join，页头标题与说明文案正常渲染 | 已通过 | 批次W2R5 | 0 | 0 | 0 | UID_F 双工作区态 Sheet「加入工作区」进入；标题「加入工作区」+说明「输入团队码即可加入工作区」+码框+按钮齐全 |
| 无待办 | - | `page/workspace/workspace_join_page.dart` | 输码自动转大写且限长 8 位（WorkspaceCodeInputFormatter） | 已通过 | 批次W2R5 | 0 | 0 | 0 | 输 ab12cd34ef56（12 位小写）→ 框内 AB12CD34（大写+截 8，dump 实证） |
| 无待办 | - | `page/workspace/workspace_join_page.dart` | 输满 8 位自动提交（face_to_face 同款体验） | 已通过 | 批次W2R5 | 0 | 0 | 0 | 第 8 位输入即 POST /workspaces/join（logcat 20:54:19），未点按钮 |
| 无待办 | - | `page/workspace/workspace_join_page.dart` | 提交按钮在码不足 8 位时禁用，输满后可点击显式提交 | 已通过 | 批次W2R5 | 0 | 0 | 0 | 空码/不足 8 位按钮灰禁；满 8 位变蓝可点 |
| 无待办 | - | `page/workspace/workspace_join_page.dart` | 提交中展示加载指示且输入框与按钮同时禁用 | 已通过 | 批次W2R5 | 0 | 0 | 0 | SIGSTOP 挂起后端注入：按钮灰禁+转圈、码框灰禁，截图实证；CONT 恢复后完成 |
| 无待办 | - | `page/workspace/workspace_join_page.dart` | joined 成功：提示含工作区名，applyJoined 置顶+切当前，回壳 Overview | 已通过 | 批次W2R5 | 0 | 0 | 0 | UID_F 输 WS2 码回壳 Overview 顶栏切 WS2；Sheet 列表 WS2 置顶+勾选、角色徽章 Member；DB workspace_member 新增 member 行 |
| 无待办 | - | `page/workspace/workspace_join_page.dart` | 重复加入（unchanged/已是成员）幂等：joinAlreadyMember 提示且仍切进该工作区 | 已通过 | 批次W2R5 | 0 | 0 | 0 | 同码重入：POST join 20:57:00 响应成功、DB 无重复行、仍切进 WS2；joinAlreadyMember toast 因本地响应<100ms 未捕获（submit→alreadyMember 分支有单测），以 DB 幂等+回壳行为判定 |
| 无待办 | - | `page/workspace/workspace_join_page.dart` | 981 无效团队码：joinInvalidCode 文案页内展示，留在本页 | 已通过 | 批次W2R5 | 0 | 0 | 0 | 假码 AB12CD34/已撤销码 39F8V2Y2 均红字「团队码无效或已失效」留页 |
| 无待办 | - | `page/workspace/workspace_join_page.dart` | 982 过期团队码：joinExpiredCode 文案页内展示，留在本页 | 已通过 | 批次W2R5 | 0 | 0 | 0 | DB 把 active 码 expires_at 改过去→红字「团队码已过期」（与 981 文案区分）留页；测后还原 |
| 无待办 | - | `page/workspace/workspace_join_page.dart` | 其余失败（网络/服务端错误）透传服务端消息页内展示 | 已通过 | 批次W2R5 | 0 | 0 | 0 | DB 临时归档 WS2→非成员输有效码红字「工作区已归档，写操作被拒绝」（980 服务端消息原文透传）留页；测后还原 member/status |
| 无待办 | - | `page/workspace/workspace_join_page.dart` | AppBar 自带返回键可返回，页面骨架完整不露路由栈黑底 | 已通过 | 批次W2R5 | 0 | 0 | 0 | AppBar 返回键回壳 Overview，骨架完整无黑底 |
