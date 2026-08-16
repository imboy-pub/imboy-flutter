# `page/splash/splash_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/splash/splash_page.dart` | 冷启动展示品牌渐变启动页 | 已通过 | 首轮 | 0 | 0 | 0 | |
| 无待办 | - | `page/splash/splash_page.dart` | 播放 Logo 淡入与缩放入场 | 已通过 | 首轮 | 0 | 0 | 0 | |
| 无待办 | - | ``page/splash/splash_page.dart`` | 播放字标与标语阶段化淡入 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/splash/splash_page.dart`` | 循环播放高光呼吸动效 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/splash/splash_page.dart`` | 按屏幕短边自适应 Logo 尺寸 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/splash/splash_page.dart`` | 暗色模式降亮渐变与高光 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | `page/splash/splash_page.dart` | debug 构建展示 DEV 角标 | 已通过 | 批次36 | 0 | 0 | 0 | 真机：当前 APK flags=[DEBUGGABLE] 为 debug 构建，kDebugMode 编译期常量必 true；splash_page L233 if(kDebugMode) 右下角 'DEV' Text（ExcludeSemantics 语义树不可见属设计，肉眼截图不可用故以构建标志+代码路径为据） |
| 无待办 | - | `page/splash/splash_page.dart` | 已登录 900ms 后跳底部导航 | 已通过 | 首轮 | 0 | 0 | 0 | |
| 无待办 | - | `page/splash/splash_page.dart` | 未登录 1400ms 后跳欢迎页 | 已通过 | 批次86 | 0 | 0 | 0 | 真机（0816 批次86，automation-buddy）：登出后冷启动分时抓帧闭环——c0/c1(0.5/3s) 原生 LaunchTheme 冻结帧（华为冷启动慢，垂直渐变无 DEV banner）→ c2(6s) Dart SplashPage 首帧（对角渐变 topLeft→bottomRight + 右下 DEV 角标双重铁证，logo/wordmark 动画 opacity=0 起点）→ c3(9s) WelcomePage 第1页（浅色渐变 (255,255,255)→(228,242,253) + OCR 命中「简单连接/体验无缝沟通的乐趣…/下一步/跳过/简体中文v」welcome i18n key）。源码 L143-150 未登录 hold 1400ms→context.go('/welcome') 实测成立 |
| 阻塞 | 需宽屏设备或 Web 端 | `page/splash/splash_page.dart` | 宽屏已登录跳 Web Shell 三栏壳 | 未测 | - | 0 | 0 | 0 | `resolveShellLayout` 分支 |
| 无待办 | - | `page/splash/splash_page.dart` | 认证检查异常兜底跳欢迎页 | 已通过 | 批次31 | 0 | 0 | 0 | 代码证实（L159-163 `on Exception`→`context.go('/welcome')`）+ 新增用例验证 /welcome 可达与 1400ms 保底时序（splash_page_test.dart auth exception fallback 组）；StorageService._prefs 为私有静态无注入点，异常路径无法确定性触发 |
| 无待办 | - | `page/splash/splash_page.dart` | 减弱动态效果时跳过全部动画 | 已通过 | 批次31 | 0 | 0 | 0 | 引用既有 widget 测试 splash_page_test.dart L347-378（Reduce Motion short-circuit：disableAnimations 注入后无 ScaleTransition）+ 真机系统三动画 scale 置 0 冷启动正常（已恢复 1） |
