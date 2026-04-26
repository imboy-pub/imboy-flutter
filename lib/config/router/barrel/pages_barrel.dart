/// 页面导入 Barrel
///
/// 集中管理所有页面导入，便于路由配置使用
library;

// ============================================================================
// 认证和启动页面
// ============================================================================
export 'package:imboy/page/splash/splash_page.dart';
export 'package:imboy/page/welcome/welcome_page.dart';
export 'package:imboy/modules/identity/public.dart';

// ============================================================================
// 主框架
// ============================================================================
export 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
// Web Shell 三栏壳（Phase 1.1.h.1+i）— 桌面 IM 入口
export 'package:imboy/page/web_shell/web_shell.dart';

// ============================================================================
// 会话和聊天
// ============================================================================
export 'package:imboy/page/conversation/conversation_page.dart';
export 'package:imboy/page/conversation/web_conversation_page.dart'; // Web 会话列表
export 'package:imboy/page/chat/chat/chat_page.dart';
export 'package:imboy/page/chat/send_to/send_to_page.dart';
export 'package:imboy/page/chat/chat_setting/chat_setting_page.dart';
export 'package:imboy/page/chat/widget/select_friend.dart';

// ============================================================================
// 联系人模块
// ============================================================================
export 'package:imboy/modules/social_graph/public.dart';

// ============================================================================
// 群组模块
// ============================================================================
export 'package:imboy/modules/group_collab/public.dart';

// ============================================================================
// 朋友圈模块
// ============================================================================
export 'package:imboy/modules/moment_social/public.dart';

// ============================================================================
// 频道模块
// ============================================================================
export 'package:imboy/modules/channel_content/public.dart';

// ============================================================================
// 个人中心模块
// ============================================================================
export 'package:imboy/page/mine/mine/mine_page.dart';
export 'package:imboy/page/mine/setting/setting_page.dart';
export 'package:imboy/page/mine/account_security/account_security_page.dart';
export 'package:imboy/page/mine/change_password/change_password_page.dart';
export 'package:imboy/page/mine/change_password/set_password_page.dart';
export 'package:imboy/page/mine/denylist/denylist_page.dart';
export 'package:imboy/page/mine/storage_space/storage_space_page.dart';
export 'package:imboy/page/mine/user_device/user_device_page.dart';
export 'package:imboy/modules/ops_governance/public.dart';
export 'package:imboy/page/mine/select_region/select_region_page.dart';
export 'package:imboy/page/mine/language/language_page.dart';
export 'package:imboy/page/mine/dark_model/dark_model_page.dart';
export 'package:imboy/page/mine/font_size/font_size_page.dart';
export 'package:imboy/page/mine/logout_account/logout_account_page.dart';

// ============================================================================
// 个人信息模块
// ============================================================================
export 'package:imboy/page/personal_info/personal_info/personal_info_page.dart';
export 'package:imboy/page/personal_info/set_nickname/set_nickname_page.dart';
export 'package:imboy/page/personal_info/set_gender/set_gender_page.dart';
export 'package:imboy/page/personal_info/set_region/set_region_page.dart';
export 'package:imboy/page/personal_info/update/update_page.dart';
export 'package:imboy/page/personal_info/widget/more_page.dart';
export 'package:imboy/page/personal_info/profile/profile_page.dart';
export 'package:imboy/page/personal_info/profile/widgets/privacy_settings_page.dart';

// ============================================================================
// 安全与隐私模块
// ============================================================================
export 'package:imboy/modules/security_privacy/public.dart';

// ============================================================================
// 其他功能
// ============================================================================
export 'package:imboy/page/wallet/wallet_page.dart';
export 'package:imboy/page/live_room/live_room_list/live_room_list_page.dart';
export 'package:imboy/page/live_room/publisher/publisher_page.dart';
export 'package:imboy/page/live_room/subscriber/subscriber_page.dart';
export 'package:imboy/page/search/search_chat_page.dart';
export 'package:imboy/page/search/message_search_page.dart'; // 消息搜索页面
export 'package:imboy/page/search/web_search_page.dart'; // Web 端全局搜索
export 'package:imboy/page/scanner/scanner_page.dart';
export 'package:imboy/page/scanner/scanner_result_page.dart';
export 'package:imboy/page/qrcode/qrcode_page.dart';
export 'package:imboy/page/single/markdown.dart';
export 'package:imboy/page/single/video_viewer.dart';
export 'package:imboy/page/single/network_failure_guidance.dart';
export 'package:imboy/page/single/privacy_policy_page.dart';
export 'package:imboy/page/single/terms_of_service_page.dart';
