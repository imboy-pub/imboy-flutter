/// 聊天页面本地组件 Barrel
library;

// 本地 widget (在 lib/page/chat/widget/ 目录)
export '../../widget/chat_input.dart';
export '../../widget/extra_item.dart';
export '../../widget/quote_tips.dart';
export '../../widget/select_friend.dart';

// Provider 和 Controller (在 lib/page/chat/chat/ 目录)
export '../chat_provider.dart';
export '../sqlite_chat_controller.dart';

// 工具类
export '../utils/chat_page_utils.dart';
