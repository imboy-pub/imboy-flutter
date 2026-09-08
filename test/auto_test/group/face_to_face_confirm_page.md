# `page/group/face_to_face/face_to_face_confirm_page.dart`

> 功能点 10 个 | bug 发现 5 / 解决 5 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/face_to_face/face_to_face_confirm_page.dart` | 进群后标题空串兜底为未命名 | 已通过 | 批次20 | 1 | 1 | 0 | |
| 无待办 | - | ``page/group/face_to_face/face_to_face_confirm_page.dart`` | 展示四位暗号数字与锁标签 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_confirm_page.dart`` | 提交中按钮禁用并显示转圈 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_confirm_page.dart`` | 呼吸绿点动画持续闪烁 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_confirm_page.dart`` | 点返回退出建群确认页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | 本地 9801+TEST_ALLOW_GROUP_WRITES | `page/group/face_to_face/face_to_face_confirm_page.dart` | 建群失败弹出错误提示 | 已通过 | 批次123 | 2 | 2 | 0 | GF8 码行删除后 save 失败 DB 断言不落 group 行。修复 2 bug：①groupFace2faceSave 吞错返回空 map 时原样跳聊天页并插 id=0 脏行→confirm 页空 group 防跳转；②dispose() 无条件 AppLoading.dismiss() 清掉失败 toast 且 deactivated 状态抛未捕获异常崩测试绑定→failed flag 跳过 finally/dispose dismiss。toast 文本断言受「确认页 3 秒消失」缺陷阻塞降级 DB 断言 |
| 无待办 | - | `page/group/face_to_face/face_to_face_confirm_page.dart` | 实时显示即将进群的人数 | 已通过 | 批次127 | 1 | 1 | 0 | 批次123「确认页被移出路由树」定性被探针推翻（f2f_diag_probe_test：页面全程存活）。真根因=监听器去重 `e.id(int)==payload['userId'](String)` 恒 false，服务端一次 join 连推 3 条重复消息全插入→人数 1→4。修复=parseModelInt 类型对齐（confirm page），复验 AT-GF5 全绿 2 人+DB 成员行 ✓ |
| 无待办 | - | `page/group/face_to_face/face_to_face_confirm_page.dart` | 收到入群事件实时追加头像 | 已通过 | 批次127 | 1 | 1 | 0 | 头像追加与人数同源（memberList insert→setState→AvatarList），GF5 复验同链覆盖；次级定性修正：memberJoin 拉群详情 404（通知先于建群）实为正确 fail-safe——save 前本地无群行，B 成员行由 faceToFaceSave 全量 memberList 兜底，无需客户端防御；服务端 3 条重复推送另记账（客户端幂等已修可防御） |
| 阻塞 | 需真机飞行模式切换（connectivity 插件真实网络事件无测试注入通道） | `page/group/face_to_face/face_to_face_confirm_page.dart` | 断网恢复后补拉服务端成员 | 未测 | 批次123 | 0 | 0 | 0 | GF6 markTestSkipped 保留：_syncMembersFromServer 代码审计+GF5 服务端成员数据正确已证；解阻塞需真机断网/复网切换 |
| 无待办 | 本地 9801+TEST_ALLOW_GROUP_WRITES | `page/group/face_to_face/face_to_face_confirm_page.dart` | 点进入该群提交建群并跳转 | 已通过 | 批次123 | 0 | 0 | 0 | GF7 提交后 pushReplacement 聊天页（ChatPage 挂载断言）+DB 断言 group 行落库、成员仅本人 1 行 |
