# `page/group/face_to_face/face_to_face_confirm_page.dart`

> 功能点 10 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/face_to_face/face_to_face_confirm_page.dart` | 进群后标题空串兜底为未命名 | 已通过 | 批次20 | 1 | 1 | 0 | |
| 无待办 | - | ``page/group/face_to_face/face_to_face_confirm_page.dart`` | 展示四位暗号数字与锁标签 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_confirm_page.dart`` | 提交中按钮禁用并显示转圈 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_confirm_page.dart`` | 呼吸绿点动画持续闪烁 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_confirm_page.dart`` | 点返回退出建群确认页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 阻塞 | 需测试环境（触发失败=真实提交建群，不可逆写生产数据） | `page/group/face_to_face/face_to_face_confirm_page.dart` | 建群失败弹出错误提示 | 未测 | 批次29 | 0 | 0 | 0 | 确认页结构已验证：暗号/1人即将进入/头像/进入该群 |
| 阻塞 | 需第二台设备配合 | `page/group/face_to_face/face_to_face_confirm_page.dart` | 实时显示即将进群的人数 | 未测 | - | 0 | 0 | 0 | 单机人数恒为 1 看不出变化 |
| 阻塞 | 需第二台设备配合 | `page/group/face_to_face/face_to_face_confirm_page.dart` | 收到入群事件实时追加头像 | 未测 | - | 0 | 0 | 0 | 依赖对端输入同一暗号 |
| 阻塞 | 需第二台设备配合 | `page/group/face_to_face/face_to_face_confirm_page.dart` | 断网恢复后补拉服务端成员 | 未测 | - | 0 | 0 | 0 | 需两端加断网切换 |
| 阻塞 | 需授权写生产数据 | `page/group/face_to_face/face_to_face_confirm_page.dart` | 点进入该群提交建群并跳转 | 未测 | - | 0 | 0 | 0 | 真实建群不可逆 |
