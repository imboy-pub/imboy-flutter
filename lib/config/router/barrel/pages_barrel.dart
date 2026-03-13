/// 页面导入 Barrel
///
/// 集中管理所有页面导入，便于路由配置使用
library;

// ============================================================================
// 认证和启动页面
// ============================================================================
export 'package:imboy/page/splash/splash_page.dart';
export 'package:imboy/page/welcome/welcome_page.dart';
export 'package:imboy/page/passport/login_page.dart';
export 'package:imboy/page/passport/web_login_page.dart'; // Web 专用登录页面
export 'package:imboy/page/passport/signup_page.dart';
export 'package:imboy/page/passport/signup_continue_page.dart';
export 'package:imboy/page/passport/forgot_password_page.dart';
export 'package:imboy/page/passport/manage_account_page.dart';

// ============================================================================
// 主框架
// ============================================================================
export 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';

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
export 'package:imboy/page/contact/contact/contact_page.dart';
export 'package:imboy/page/contact/people_info/people_info_page.dart';
export 'package:imboy/page/contact/new_friend/new_friend_page.dart';
export 'package:imboy/page/contact/new_friend/add_friend_page.dart';
export 'package:imboy/page/contact/people_nearby/people_nearby_page.dart';
export 'package:imboy/page/contact/recently_registered_user/recently_registered_user_page.dart';
export 'package:imboy/page/contact/people_info_more/people_info_more_page.dart';
export 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_page.dart';

// ============================================================================
// 群组模块
// ============================================================================
export 'package:imboy/page/group/group_list/group_list_page.dart';
export 'package:imboy/page/group/group_detail/group_detail_page.dart';
export 'package:imboy/page/group/group_detail/add_member_page.dart';
export 'package:imboy/page/group/group_detail/remove_member_page.dart';
export 'package:imboy/page/group/group_member/group_member_page.dart';
export 'package:imboy/page/group/announcement/group_announcement_page.dart';
export 'package:imboy/page/group/launch_chat/launch_chat_page.dart';
export 'package:imboy/page/group/group_select/group_select_page.dart';
export 'package:imboy/page/group/face_to_face/face_to_face_page.dart';
export 'package:imboy/page/group/face_to_face/face_to_face_confirm_page.dart';
// 群功能增强
export 'package:imboy/page/group/category/group_category_page.dart';
export 'package:imboy/page/group/tag/group_tag_page.dart';
export 'package:imboy/page/group/vote/group_vote_page.dart';
export 'package:imboy/page/group/vote/group_vote_detail_page.dart';
export 'package:imboy/page/group/schedule/group_schedule_page.dart';
export 'package:imboy/page/group/schedule/group_schedule_detail_page.dart';
export 'package:imboy/page/group/task/group_task_page.dart';
export 'package:imboy/page/group/task/group_task_detail_page.dart';
export 'package:imboy/page/group/file/group_file_page.dart';
export 'package:imboy/page/group/album/group_album_page.dart';
export 'package:imboy/page/group/album/group_album_photo_page.dart';
export 'package:imboy/page/group/album/group_album_photo_detail_page.dart';

// ============================================================================
// @提及模块
// ============================================================================
export 'package:imboy/page/mention/mention_list_page.dart';

// ============================================================================
// 朋友圈模块
// ============================================================================
export 'package:imboy/page/moment/moment_feed_page.dart';
export 'package:imboy/page/moment/moment_create_page.dart';
export 'package:imboy/page/moment/moment_detail_page.dart';

// ============================================================================
// 频道模块
// ============================================================================
export 'package:imboy/page/channel/channel_list_page.dart';
export 'package:imboy/page/channel/channel_detail_page.dart';
export 'package:imboy/page/channel/channel_discover_page.dart';
export 'package:imboy/page/channel/channel_create_page.dart';
export 'package:imboy/page/channel/channel_edit_page.dart';
export 'package:imboy/page/channel/channel_admin_page.dart';
export 'package:imboy/page/channel/channel_subscriber_page.dart';
export 'package:imboy/page/channel/channel_invitation_page.dart';

// ============================================================================
// 个人中心模块
// ============================================================================
export 'package:imboy/page/mine/mine/mine_page.dart';
export 'package:imboy/page/mine/setting/setting_page.dart';
export 'package:imboy/page/mine/account_security/account_security_page.dart';
export 'package:imboy/page/mine/change_password/change_password_page.dart';
export 'package:imboy/page/mine/change_password/set_password_page.dart';
export 'package:imboy/page/mine/user_collect/user_collect_page.dart';
export 'package:imboy/page/mine/denylist/denylist_page.dart';
export 'package:imboy/page/mine/storage_space/storage_space_page.dart';
export 'package:imboy/page/mine/user_device/user_device_page.dart';
export 'package:imboy/page/mine/feedback/feedback_page.dart';
export 'package:imboy/page/mine/feedback/feedback_detail_page.dart';
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
// E2EE 密钥恢复模块
// ============================================================================
export 'package:imboy/page/settings/e2ee_key_recovery_page.dart';
export 'package:imboy/page/settings/e2ee_backup_export_page.dart';
export 'package:imboy/page/settings/e2ee_backup_import_page.dart';
export 'package:imboy/page/settings/e2ee_backup_manage_page.dart';
export 'package:imboy/page/settings/e2ee_transfer_page.dart';
export 'package:imboy/page/settings/e2ee_transfer_send_page.dart';
export 'package:imboy/page/settings/e2ee_transfer_receive_page.dart';
export 'package:imboy/page/settings/e2ee_social_page.dart';
export 'package:imboy/page/settings/e2ee_social_create_page.dart';
export 'package:imboy/page/settings/e2ee_social_recover_page.dart';
export 'package:imboy/page/settings/e2ee_social_manage_page.dart';
export 'package:imboy/page/settings/e2ee_proxy_selector_page.dart';

// 开发者测试（仅开发环境）
export 'package:imboy/page/settings/e2ee_dev_test_page.dart';

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
export 'package:imboy/page/single/upgrade.dart';
export 'package:imboy/page/single/network_failure_guidance.dart';
