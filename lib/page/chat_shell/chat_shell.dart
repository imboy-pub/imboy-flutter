/// T2 (WP1) — Chat Shell 模块统一对外入口（barrel export）
///
/// 将 `lib/page/chat_shell/` 下公共文件的 API 统一聚合，调用方只需一个 import：
///
/// ```dart
/// import 'package:imboy/page/chat_shell/chat_shell.dart';
///
/// // 直接使用：
/// final experience = ref.watch(productExperienceProvider);
/// final layout = resolveChatShellLayout(width);
/// final items = buildChatShellNavItems(...);
/// // ChatShellPage / ChatShellBootstrap ...
/// ```
///
/// 设计意图（镜像 `web_shell.dart`）：
/// - **单一 import 入口**：路由挂载点 / 测试只 import 此 barrel
/// - **API 边界清晰**：通过 barrel 列表明确暴露的公共 API（隐式契约）
/// - **重构兼容**：未来重命名内部文件，调用方不需改动 import 路径
/// - **零运行时开销**：纯 export 语句，无任何 runtime 行为
library;

// 响应式断点决策（< 900 mobile / >= 900 desktop）
export 'chat_shell_breakpoint.dart';

// 导航项声明层（chat 体验导航目的地 + 工厂，T8 对称镜像点）
export 'chat_shell_nav_items.dart';

// Product Experience 消费层（枚举 + 解析 + 缓存读取 + provider）
export 'experience_provider.dart';

// ⭐ 壳页面（纯包装：断点分发到现有入口 widget）
export 'chat_shell_page.dart';

// ⭐ 业务接线层（experience 消费 + BottomNavigationPage/WebShellBootstrap 注入）
export 'chat_shell_bootstrap.dart';
