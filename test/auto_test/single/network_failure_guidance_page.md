# `page/single/network_failure_guidance_page.dart`

> 功能点 8 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/single/network_failure_guidance_page.dart` | 断网时进入网络异常引导页 | 已通过 | 批次87 | 0 | 0 | 0 | 真机（0816 批次87，automation-buddy）：飞行模式（settings put global airplane_mode_on 1 + 广播）→ WS 断开→ conversation_page L276-277 connectDesc 非空→ NetworkFailureTips 红条（「当前网络不可用。请检查你的网络设置。」）→ 点击 context.push('/network_failure_guidance') 进引导页；旧阻塞理由「关 WiFi 触发防误触锁屏」被飞行模式方案绕过 |
| 无待办 | - | `page/single/network_failure_guidance_page.dart` | 标题栏展示网络异常标题 | 已通过 | 批次87 | 0 | 0 | 0 | 真机：中文「网络连接异常」；切 English 后「Network connection error」（t.common.networkException） |
| 无待办 | - | `page/single/network_failure_guidance_page.dart` | 点击返回按钮回到来源页 | 已通过 | 批次87 | 0 | 0 | 0 | 真机：引导页 Back→返回 Messages 页（红条仍在，页面栈正常 pop） |
| 无待办 | - | `page/single/network_failure_guidance_page.dart` | 展示检查网络的建议标题行 | 已通过 | 批次87 | 0 | 0 | 0 | 真机：中文「建议检查网络设置。」/ 英文「Please check your network settings.」（ListTile suggestCheckNetwork w600） |
| 无待办 | - | `page/single/network_failure_guidance_page.dart` | 展示三步排障指引文案 | 已通过 | 批次87 | 0 | 0 | 0 | 真机+Opus Vision OCR（0816）：中文三步（1.Wi-Fi开关 2.蜂窝移动数据 3.咨询运营商）与英文三步（Settings→Wi-Fi / Cellular Data / network operator）完整渲染；英文换行 2/2/3 行正常换行非截断 |
| 无待办 | - | `page/single/network_failure_guidance_page.dart` | 切换语言后引导文案同步刷新 | 已通过 | 批次87 | 0 | 0 | 0 | 真机：设置→Language→English 即时生效——标题 Network connection error + 红条 No internet connection 全 app 英文（语言设置页切语言无重启） |
| 无待办 | - | `page/single/network_failure_guidance_page.dart` | 暗色模式下卡片背景与文本适配 | 已通过 | 批次87 | 0 | 0 | 0 | 真机+Opus 亮度分析：Dark mode Enabled 后进页，Card/背景均值 33-39 vs 浅色 226-240（暗 6-7 倍），深底浅字对比可读（Card 色=Theme.of(context).colorScheme.surface） |
| 无待办 | - | `page/single/network_failure_guidance_page.dart` | 一百四十字号下文案不溢出 | 已通过 | 批次87 | 0 | 0 | 0 | 真机+Opus 像素校验：Font Size Setting SeekBar 拖至 100%=Huge 140%（Current 预览实证），引导页文本 5→10 行随字号增长；最宽行右余量 47px（≈6.5%）、最后一行距底导航条 30% 屏高，无横向/垂直溢出（标题像素级 x[147,588] 完整居中，OCR 省略号为低置信缩写非裁切） |
