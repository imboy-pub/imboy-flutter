# `page/scanner/scanner_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/scanner/scanner_page.dart` | 进页延迟启动相机并渲染取景框 | 待重验 | - | 0 | 0 | 0 | |
| 阻塞 | 手动拒绝相机权限后 | `page/scanner/scanner_page.dart` | 权限被拒时显示去设置引导 | 未测 | - | 0 | 0 | 0 | 需构造权限拒绝场景 |
| 阻塞 | 可构造相机启动失败场景后 | `page/scanner/scanner_page.dart` | 启动失败时显示重试按钮 | 未测 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/scanner/scanner_page.dart` | 闪光灯按钮开关并切换图标 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/scanner/scanner_page.dart` | 暂停与继续扫描切换 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/scanner/scanner_page.dart` | 前后摄像头切换 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/scanner/scanner_page.dart` | 相册识图成功提示用二维码口径 | 已通过 | §三十六 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/scanner/scanner_page.dart` | 相册图片未识别出码时红色提示 | 待重验 | - | 0 | 0 | 0 | |
| 待修复 | 2026-08-13 | `page/scanner/scanner_page.dart` | 扫到登录码跳转登录确认页 | 有BUG待修 | 批次78 | 1 | 0 | 1 | 真机（相册 qr_login_fake.png 替代第二台设备）：detectQrLoginIntent 识别 imboy://qr_login/FAKE_TOKEN 成功，push QrLoginConfirmPage，scan 调 /api/v1/passport/qr_login/scan；但**后端 scan 在 router.open 白名单 → auth_middleware_api_v1 跳过 token 解析 → handler Uid=0 → 必返回 401「未登录」**；前端 _checkAuthExpired 把 401 误判为会话失效，**触发 quitLogin 删本地 pro_4.db**。BUG#批次78-1，后端已修（移出 open 白名单），待新 APK+发布后复验 |
| 阻塞 | 第二台设备出示个人二维码后 | `page/scanner/scanner_page.dart` | 扫到用户名片跳转个人资料页 | 未测 | - | 0 | 0 | 0 | 无第二设备，从未实扫 |
| 无待办 | - | `page/scanner/scanner_page.dart` | 扫到群码入群并进入群聊页 | 已通过 | 批次78 | 0 | 0 | 0 | 真机（相册 qr_group_real.png 替代第二台设备）：用 imboy_api.py 拿到当前用户已加入的真实群 gid=99746135830431744（member_count=2），按 buildGroupQrcodeUrl 规则（exp=毫秒时间戳+7d，tk=md5(exp_key)）生成有效群码；后端 GET /api/v1/group/qrcode 直连验证返回 code=0/payload.type=group/member_count=2（服务端成功证据）；前端扫码→识别群码 URL→GET→ChatPage 跳转，UI 进入标题"未命名"群聊页（C2G），含输入框/@提及/表情/附加项/聊天设置按钮，结构正确 |
| 无待办 | - | `page/scanner/scanner_page.dart` | 扫到非站内内容跳扫描结果页 | 已通过 | 批次75 | 0 | 0 | 0 | 真机：相册选 qr_url.png（https://imboy.pub/scanner_test_75，非站内码）→识别成功→正确跳转 scanner_result_page（相册二维码替代第二台设备） |
