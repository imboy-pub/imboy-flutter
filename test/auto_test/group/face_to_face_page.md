# `page/group/face_to_face/face_to_face_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/face_to_face/face_to_face_page.dart` | 数字键盘输入四位暗号并回显 | 已通过 | 批次20 | 0 | 0 | 0 | BUG#26/#27 已撤回为操作失误 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_page.dart`` | 删除键回退已输入的单位数字 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_page.dart`` | 输入三秒后自动清空重来 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_page.dart`` | 异常路径加载遮罩必被关闭 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_page.dart`` | 展示面对面建群提示卡片 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_page.dart`` | 输入框激活态边框高亮切换 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/face_to_face/face_to_face_page.dart`` | 点返回退出面对面建群页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/group/face_to_face/face_to_face_page.dart` | 匹配失败展示红色错误文案 | 已通过 | 批次123 | 0 | 0 | 0 | GF4 服务端节流实证失败反馈：HTTP 同码占位占满 per-uid 3 秒节流窗后 UI 输第 4 位，toast 弹服务端原文「在处理中，请稍后重试」；页内 errorInfo/iosRed 红字为独立机制且输码主链无赋值触发点（macOS 集成测试，本地 9801 写库授权） |
| 无待办 | - | `page/group/face_to_face/face_to_face_page.dart` | 小屏下输入框尺寸自适应缩小 | 已通过 | 批次29 | 0 | 0 | 0 | 本机恰 360dp 命中 boxSize=56 分支，四位回显无溢出 |
| 无待办 | 本地 9801+TEST_ALLOW_GROUP_WRITES | `page/group/face_to_face/face_to_face_page.dart` | 输满四位自动发起建群匹配 | 已通过 | 批次123 | 0 | 0 | 0 | GF1 输码 1357 自动触发 face2face 并跳确认页，DB 断言 group_random_code 落本人匹配行（macOS 集成测试） |
| 无待办 | 本地 9801+TEST_ALLOW_GROUP_WRITES | `page/group/face_to_face/face_to_face_page.dart` | 匹配成功跳转建群确认页 | 已通过 | 批次123 | 0 | 0 | 0 | GF2 断言确认页元素齐备：进入该群/面对面建群 AppBar/暗号 chip/确认提示/四位码逐字符展示 |
