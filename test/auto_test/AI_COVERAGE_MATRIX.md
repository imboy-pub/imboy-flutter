# AI 真机规格覆盖矩阵

> 本矩阵从既有 `test/auto_test/<模块>/<页面>.md` 自动生成。
> “已有样板”仅表示至少一个可执行规格关联到该页；**不等于该页全部功能点或全部 UI 状态已覆盖**。

## 汇总

| 指标 | 数量 |
|---|---:|
| 页面台账总数 | 155 |
| 已有关联规格的样板页 | 19 |
| 待分级并补规格的页面 | 136 |
| 源码映射缺失 | 0 |

## 页面队列

| 模块 | 页面台账 | 源码 | 功能点 | AI 规格状态 | 关联 case |
|---|---|---|---:|---|---|
| bottom_navigation | [bottom_navigation_page](bottom_navigation/bottom_navigation_page.md) | `lib/page/bottom_navigation/bottom_navigation_page.dart` | 12 | 待分级并补规格 | — |
| channel | [channel_admin_page](channel/channel_admin_page.md) | `lib/page/channel/channel_admin_page.dart` | 11 | 待分级并补规格 | — |
| channel | [channel_article_page](channel/channel_article_page.md) | `lib/page/channel/channel_article_page.dart` | 12 | 待分级并补规格 | — |
| channel | [channel_comment_page](channel/channel_comment_page.md) | `lib/page/channel/channel_comment_page.dart` | 12 | 待分级并补规格 | — |
| channel | [channel_compose_page](channel/channel_compose_page.md) | `lib/page/channel/channel_compose_page.dart` | 12 | 已有样板（需继续细化） | `CHANNEL-DETAIL-PUBLISH-001` |
| channel | [channel_create_page](channel/channel_create_page.md) | `lib/page/channel/channel_create_page.dart` | 11 | 已有样板（需继续细化） | `CHANNEL-CREATE-001` |
| channel | [channel_detail_page](channel/channel_detail_page.md) | `lib/page/channel/channel_detail_page.dart` | 13 | 已有样板（需继续细化） | `CHANNEL-DETAIL-PUBLISH-001`<br>`CHANNEL-PUBLISH-SMOKE-001`<br>`CHANNEL-SUBSCRIBED-CONSISTENCY-001` |
| channel | [channel_discover_page](channel/channel_discover_page.md) | `lib/page/channel/channel_discover_page.dart` | 10 | 待分级并补规格 | — |
| channel | [channel_edit_page](channel/channel_edit_page.md) | `lib/page/channel/channel_edit_page.dart` | 11 | 已有样板（需继续细化） | `CHANNEL-EDIT-001` |
| channel | [channel_invitation_page](channel/channel_invitation_page.md) | `lib/page/channel/channel_invitation_page.dart` | 11 | 待分级并补规格 | — |
| channel | [channel_list_page](channel/channel_list_page.md) | `lib/page/channel/channel_list_page.dart` | 12 | 待分级并补规格 | — |
| channel | [channel_order_detail_page](channel/channel_order_detail_page.md) | `lib/page/channel/channel_order_detail_page.dart` | 10 | 待分级并补规格 | — |
| channel | [channel_order_list_page](channel/channel_order_list_page.md) | `lib/page/channel/channel_order_list_page.dart` | 9 | 待分级并补规格 | — |
| channel | [channel_subscriber_page](channel/channel_subscriber_page.md) | `lib/page/channel/channel_subscriber_page.dart` | 12 | 待分级并补规格 | — |
| chat | [chat_page](chat/chat_page.md) | `lib/page/chat/chat/chat_page.dart` | 21 | 已有样板（需继续细化） | `C2C-E2EE-SEND-RENDER-001`<br>`CHAT-GROUP-001`<br>`CHAT-SINGLE-READONLY-001`<br>`CHAT-VOICE-RENDER-001`<br>`TWO-CLIENT-MAC-C2C-PING-001`<br>`CHAT-PAGE-001` |
| chat | [chat_setting_page](chat/chat_setting_page.md) | `lib/page/chat/chat_setting/chat_setting_page.dart` | 10 | 待分级并补规格 | — |
| chat | [p2p_call_screen_page](chat/p2p_call_screen_page.md) | `lib/page/chat/p2p_call_screen/p2p_call_screen_page.dart` | 12 | 待分级并补规格 | — |
| chat | [quick_reply_manage_page](chat/quick_reply_manage_page.md) | `lib/page/chat/widget/quick_reply_manage_page.dart` | 11 | 已有样板（需继续细化） | `CHAT-QUICK-REPLY-MANAGE-001` |
| chat | [rtc_room_page](chat/rtc_room_page.md) | `lib/page/chat/rtc_room/rtc_room_page.dart` | 12 | 待分级并补规格 | — |
| chat | [send_to_page](chat/send_to_page.md) | `lib/page/chat/send_to/send_to_page.dart` | 10 | 待分级并补规格 | — |
| contact | [add_friend_page](contact/add_friend_page.md) | `lib/page/contact/new_friend/add_friend_page.dart` | 9 | 已有样板（需继续细化） | `CONTACT-ADD-FRIEND-001`<br>`TWO-CLIENT-MAC-FRIEND-APPLY-001` |
| contact | [apply_friend_page](contact/apply_friend_page.md) | `lib/page/contact/apply_friend/apply_friend_page.dart` | 9 | 已有样板（需继续细化） | `CONTACT-CONFIRM-FRIEND-001` |
| contact | [assistant_plaza_page](contact/assistant_plaza_page.md) | `lib/page/contact/assistant_plaza/assistant_plaza_page.dart` | 10 | 待分级并补规格 | — |
| contact | [confirm_new_friend_page](contact/confirm_new_friend_page.md) | `lib/page/contact/confirm_new_friend/confirm_new_friend_page.dart` | 9 | 待分级并补规格 | — |
| contact | [contact_page](contact/contact_page.md) | `lib/page/contact/contact/contact_page.dart` | 12 | 待分级并补规格 | — |
| contact | [contact_setting_page](contact/contact_setting_page.md) | `lib/page/contact/contact_setting/contact_setting_page.dart` | 10 | 待分级并补规格 | — |
| contact | [contact_setting_tag_page](contact/contact_setting_tag_page.md) | `lib/page/contact/contact_setting_tag/contact_setting_tag_page.dart` | 9 | 待分级并补规格 | — |
| contact | [new_friend_page](contact/new_friend_page.md) | `lib/page/contact/new_friend/new_friend_page.dart` | 11 | 已有样板（需继续细化） | `CONTACT-ADD-FRIEND-001`<br>`CONTACT-CONFIRM-FRIEND-001`<br>`TWO-CLIENT-MAC-FRIEND-APPLY-001` |
| contact | [people_info_more_page](contact/people_info_more_page.md) | `lib/page/contact/people_info_more/people_info_more_page.dart` | 9 | 待分级并补规格 | — |
| contact | [people_info_page](contact/people_info_page.md) | `lib/page/contact/people_info/people_info_page.dart` | 11 | 已有样板（需继续细化） | `CONTACT-FRIEND-MANAGE-001` |
| contact | [people_info_same_group_page](contact/people_info_same_group_page.md) | `lib/page/contact/people_info_more/people_info_same_group_page.dart` | 8 | 待分级并补规格 | — |
| contact | [people_nearby_page](contact/people_nearby_page.md) | `lib/page/contact/people_nearby/people_nearby_page.dart` | 11 | 待分级并补规格 | — |
| contact | [recently_registered_user_page](contact/recently_registered_user_page.md) | `lib/page/contact/recently_registered_user/recently_registered_user_page.dart` | 8 | 待分级并补规格 | — |
| conversation | [conversation_page](conversation/conversation_page.md) | `lib/page/conversation/conversation_page.dart` | 12 | 已有样板（需继续细化） | `C2C-PLAINTEXT-REJECT-001`<br>`TWO-CLIENT-MAC-C2C-PING-001`<br>`CONVERSATION-LIST-001` |
| group | [add_member_page](group/add_member_page.md) | `lib/page/group/group_detail/add_member_page.dart` | 11 | 待分级并补规格 | — |
| group | [change_info_page](group/change_info_page.md) | `lib/page/group/group_detail/change_info_page.dart` | 10 | 待分级并补规格 | — |
| group | [face_to_face_confirm_page](group/face_to_face_confirm_page.md) | `lib/page/group/face_to_face/face_to_face_confirm_page.dart` | 10 | 待分级并补规格 | — |
| group | [face_to_face_page](group/face_to_face_page.md) | `lib/page/group/face_to_face/face_to_face_page.dart` | 11 | 待分级并补规格 | — |
| group | [group_album_page](group/group_album_page.md) | `lib/page/group/album/group_album_page.dart` | 10 | 待分级并补规格 | — |
| group | [group_album_photo_detail_page](group/group_album_photo_detail_page.md) | `lib/page/group/album/group_album_photo_detail_page.dart` | 11 | 待分级并补规格 | — |
| group | [group_album_photo_page](group/group_album_photo_page.md) | `lib/page/group/album/group_album_photo_page.dart` | 12 | 待分级并补规格 | — |
| group | [group_announcement_page](group/group_announcement_page.md) | `lib/page/group/announcement/group_announcement_page.dart` | 12 | 待分级并补规格 | — |
| group | [group_category_detail_page](group/group_category_detail_page.md) | `lib/page/group/category/group_category_detail_page.dart` | 10 | 待分级并补规格 | — |
| group | [group_category_page](group/group_category_page.md) | `lib/page/group/category/group_category_page.dart` | 10 | 待分级并补规格 | — |
| group | [group_detail_page](group/group_detail_page.md) | `lib/page/group/group_detail/group_detail_page.dart` | 17 | 待分级并补规格 | — |
| group | [group_file_audio_preview_page](group/group_file_audio_preview_page.md) | `lib/page/group/file/group_file_audio_preview_page.dart` | 9 | 待分级并补规格 | — |
| group | [group_file_page](group/group_file_page.md) | `lib/page/group/file/group_file_page.dart` | 12 | 待分级并补规格 | — |
| group | [group_list_page](group/group_list_page.md) | `lib/page/group/group_list/group_list_page.dart` | 14 | 已有样板（需继续细化） | `GROUP-MANAGEMENT-READONLY-001` |
| group | [group_member_detail_page](group/group_member_detail_page.md) | `lib/page/group/group_member/group_member_detail_page.dart` | 11 | 待分级并补规格 | — |
| group | [group_member_page](group/group_member_page.md) | `lib/page/group/group_member/group_member_page.dart` | 12 | 待分级并补规格 | — |
| group | [group_schedule_detail_page](group/group_schedule_detail_page.md) | `lib/page/group/schedule/group_schedule_detail_page.dart` | 12 | 待分级并补规格 | — |
| group | [group_schedule_page](group/group_schedule_page.md) | `lib/page/group/schedule/group_schedule_page.dart` | 11 | 已有样板（需继续细化） | `GROUP-SCHEDULE-001` |
| group | [group_select_page](group/group_select_page.md) | `lib/page/group/group_select/group_select_page.dart` | 9 | 待分级并补规格 | — |
| group | [group_tag_page](group/group_tag_page.md) | `lib/page/group/tag/group_tag_page.dart` | 10 | 待分级并补规格 | — |
| group | [group_task_detail_page](group/group_task_detail_page.md) | `lib/page/group/task/group_task_detail_page.dart` | 12 | 待分级并补规格 | — |
| group | [group_task_page](group/group_task_page.md) | `lib/page/group/task/group_task_page.dart` | 12 | 待分级并补规格 | — |
| group | [group_vote_detail_page](group/group_vote_detail_page.md) | `lib/page/group/vote/group_vote_detail_page.dart` | 12 | 待分级并补规格 | — |
| group | [group_vote_page](group/group_vote_page.md) | `lib/page/group/vote/group_vote_page.dart` | 11 | 待分级并补规格 | — |
| group | [launch_chat_page](group/launch_chat_page.md) | `lib/page/group/launch_chat/launch_chat_page.dart` | 12 | 待分级并补规格 | — |
| group | [remove_member_page](group/remove_member_page.md) | `lib/page/group/group_detail/remove_member_page.dart` | 10 | 待分级并补规格 | — |
| live_room | [live_room_list_page](live_room/live_room_list_page.md) | `lib/page/live_room/live_room_list/live_room_list_page.dart` | 12 | 待分级并补规格 | — |
| live_room | [publisher_page](live_room/publisher_page.md) | `lib/page/live_room/publisher/publisher_page.dart` | 11 | 待分级并补规格 | — |
| live_room | [subscriber_page](live_room/subscriber_page.md) | `lib/page/live_room/subscriber/subscriber_page.dart` | 10 | 待分级并补规格 | — |
| mention | [mention_list_page](mention/mention_list_page.md) | `lib/page/mention/mention_list_page.dart` | 12 | 待分级并补规格 | — |
| mine | [account_security_page](mine/account_security_page.md) | `lib/page/mine/account_security/account_security_page.dart` | 9 | 待分级并补规格 | — |
| mine | [bind_email_page](mine/bind_email_page.md) | `lib/page/mine/account_security/bind_email_page.dart` | 12 | 待分级并补规格 | — |
| mine | [bind_mobile_page](mine/bind_mobile_page.md) | `lib/page/mine/account_security/bind_mobile_page.dart` | 12 | 待分级并补规格 | — |
| mine | [change_name_page](mine/change_name_page.md) | `lib/page/mine/user_device/change_name_page.dart` | 11 | 待分级并补规格 | — |
| mine | [change_password_page](mine/change_password_page.md) | `lib/page/mine/change_password/change_password_page.dart` | 12 | 已有样板（需继续细化） | `AUTH-PASSWORD-CHANGE-001` |
| mine | [dark_model_page](mine/dark_model_page.md) | `lib/page/mine/dark_model/dark_model_page.dart` | 9 | 待分级并补规格 | — |
| mine | [denylist_page](mine/denylist_page.md) | `lib/page/mine/denylist/denylist_page.dart` | 12 | 待分级并补规格 | — |
| mine | [feedback_detail_page](mine/feedback_detail_page.md) | `lib/page/mine/feedback/feedback_detail_page.dart` | 12 | 待分级并补规格 | — |
| mine | [feedback_page](mine/feedback_page.md) | `lib/page/mine/feedback/feedback_page.dart` | 13 | 待分级并补规格 | — |
| mine | [font_size_page](mine/font_size_page.md) | `lib/page/mine/font_size/font_size_page.dart` | 10 | 待分级并补规格 | — |
| mine | [language_page](mine/language_page.md) | `lib/page/mine/language/language_page.dart` | 9 | 待分级并补规格 | — |
| mine | [logout_account_page](mine/logout_account_page.md) | `lib/page/mine/logout_account/logout_account_page.dart` | 12 | 待分级并补规格 | — |
| mine | [mine_page](mine/mine_page.md) | `lib/page/mine/mine/mine_page.dart` | 12 | 待分级并补规格 | — |
| mine | [select_region_page](mine/select_region_page.md) | `lib/page/mine/select_region/select_region_page.dart` | 10 | 待分级并补规格 | — |
| mine | [set_password_page](mine/set_password_page.md) | `lib/page/mine/change_password/set_password_page.dart` | 11 | 待分级并补规格 | — |
| mine | [setting_page](mine/setting_page.md) | `lib/page/mine/setting/setting_page.dart` | 17 | 待分级并补规格 | — |
| mine | [storage_space_page](mine/storage_space_page.md) | `lib/page/mine/storage_space/storage_space_page.dart` | 10 | 待分级并补规格 | — |
| mine | [user_collect_detail_page](mine/user_collect_detail_page.md) | `lib/page/mine/user_collect/user_collect_detail_page.dart` | 12 | 待分级并补规格 | — |
| mine | [user_collect_page](mine/user_collect_page.md) | `lib/page/mine/user_collect/user_collect_page.dart` | 17 | 待分级并补规格 | — |
| mine | [user_device_detail_page](mine/user_device_detail_page.md) | `lib/page/mine/user_device/user_device_detail_page.dart` | 14 | 待分级并补规格 | — |
| mine | [user_device_page](mine/user_device_page.md) | `lib/page/mine/user_device/user_device_page.dart` | 14 | 待分级并补规格 | — |
| moment | [moment_at_picker_page](moment/moment_at_picker_page.md) | `lib/page/moment/moment_friend_picker/moment_at_picker_page.dart` | 10 | 待分级并补规格 | — |
| moment | [moment_create_page](moment/moment_create_page.md) | `lib/page/moment/moment_create_page.dart` | 14 | 待分级并补规格 | — |
| moment | [moment_detail_page](moment/moment_detail_page.md) | `lib/page/moment/moment_detail_page.dart` | 13 | 待分级并补规格 | — |
| moment | [moment_feed_page](moment/moment_feed_page.md) | `lib/page/moment/moment_feed_page.dart` | 13 | 待分级并补规格 | — |
| moment | [moment_friend_picker_page](moment/moment_friend_picker_page.md) | `lib/page/moment/moment_friend_picker/moment_friend_picker_page.dart` | 12 | 待分级并补规格 | — |
| moment | [moment_notify_page](moment/moment_notify_page.md) | `lib/page/moment/moment_notify/moment_notify_page.dart` | 12 | 待分级并补规格 | — |
| passport | [forgot_password_page](passport/forgot_password_page.md) | `lib/page/passport/forgot_password_page.dart` | 12 | 待分级并补规格 | — |
| passport | [forgot_password_pin_code_page](passport/forgot_password_pin_code_page.md) | `lib/page/passport/forgot_password_pin_code_page.dart` | 12 | 待分级并补规格 | — |
| passport | [login_page](passport/login_page.md) | `lib/page/passport/login_page.dart` | 12 | 已有样板（需继续细化） | `PASSPORT-LOGIN-001` |
| passport | [manage_account_page](passport/manage_account_page.md) | `lib/page/passport/manage_account_page.dart` | 10 | 待分级并补规格 | — |
| passport | [signup_continue_page](passport/signup_continue_page.md) | `lib/page/passport/signup_continue_page.dart` | 12 | 待分级并补规格 | — |
| passport | [signup_page](passport/signup_page.md) | `lib/page/passport/signup_page.dart` | 12 | 已有样板（需继续细化） | `PASSPORT-SIGNUP-001` |
| passport | [web_login_page](passport/web_login_page.md) | `lib/page/passport/web_login_page.dart` | 12 | 待分级并补规格 | — |
| personal_info | [more_page](personal_info/more_page.md) | `lib/page/personal_info/widget/more_page.dart` | 10 | 待分级并补规格 | — |
| personal_info | [personal_info_page](personal_info/personal_info_page.md) | `lib/page/personal_info/personal_info/personal_info_page.dart` | 12 | 待分级并补规格 | — |
| personal_info | [privacy_settings_page](personal_info/privacy_settings_page.md) | `lib/page/personal_info/profile/widgets/privacy_settings_page.dart` | 10 | 待分级并补规格 | — |
| personal_info | [profile_page](personal_info/profile_page.md) | `lib/page/personal_info/profile/profile_page.dart` | 12 | 待分级并补规格 | — |
| personal_info | [set_gender_page](personal_info/set_gender_page.md) | `lib/page/personal_info/set_gender/set_gender_page.dart` | 10 | 待分级并补规格 | — |
| personal_info | [set_nickname_page](personal_info/set_nickname_page.md) | `lib/page/personal_info/set_nickname/set_nickname_page.dart` | 12 | 待分级并补规格 | — |
| personal_info | [set_region_page](personal_info/set_region_page.md) | `lib/page/personal_info/set_region/set_region_page.dart` | 11 | 待分级并补规格 | — |
| personal_info | [update_page](personal_info/update_page.md) | `lib/page/personal_info/update/update_page.dart` | 11 | 待分级并补规格 | — |
| qrcode | [channel_qrcode_page](qrcode/channel_qrcode_page.md) | `lib/page/qrcode/channel_qrcode_page.dart` | 10 | 待分级并补规格 | — |
| qrcode | [group_qrcode_page](qrcode/group_qrcode_page.md) | `lib/page/qrcode/group_qrcode_page.dart` | 11 | 待分级并补规格 | — |
| qrcode | [qrcode_page](qrcode/qrcode_page.md) | `lib/page/qrcode/qrcode_page.dart` | 11 | 待分级并补规格 | — |
| qrcode | [user_qrcode_page](qrcode/user_qrcode_page.md) | `lib/page/qrcode/user_qrcode_page.dart` | 10 | 待分级并补规格 | — |
| scanner | [qr_login_confirm_page](scanner/qr_login_confirm_page.md) | `lib/page/scanner/qr_login_confirm_page.dart` | 9 | 待分级并补规格 | — |
| scanner | [scanner_page](scanner/scanner_page.md) | `lib/page/scanner/scanner_page.dart` | 12 | 待分级并补规格 | — |
| scanner | [scanner_result_page](scanner/scanner_result_page.md) | `lib/page/scanner/scanner_result_page.dart` | 9 | 待分级并补规格 | — |
| search | [message_search_page](search/message_search_page.md) | `lib/page/search/message_search_page.dart` | 12 | 待分级并补规格 | — |
| search | [search_chat_page](search/search_chat_page.md) | `lib/page/search/search_chat_page.dart` | 11 | 待分级并补规格 | — |
| search | [web_search_page](search/web_search_page.md) | `lib/page/search/web_search_page.dart` | 12 | 待分级并补规格 | — |
| settings | [e2ee_backup_export_page](settings/e2ee_backup_export_page.md) | `lib/page/settings/e2ee_backup_export_page.dart` | 12 | 待分级并补规格 | — |
| settings | [e2ee_backup_import_page](settings/e2ee_backup_import_page.md) | `lib/page/settings/e2ee_backup_import_page.dart` | 12 | 已有样板（需继续细化） | `E2EE-BACKUP-IMPORT-001` |
| settings | [e2ee_key_recovery_page](settings/e2ee_key_recovery_page.md) | `lib/page/settings/e2ee_key_recovery_page.dart` | 12 | 待分级并补规格 | — |
| single | [markdown_page](single/markdown_page.md) | `lib/page/single/markdown_page.dart` | 9 | 待分级并补规格 | — |
| single | [network_failure_guidance_page](single/network_failure_guidance_page.md) | `lib/page/single/network_failure_guidance_page.dart` | 8 | 待分级并补规格 | — |
| single | [terms_of_service_page](single/terms_of_service_page.md) | `lib/page/single/terms_of_service_page.dart` | 8 | 待分级并补规格 | — |
| single | [upgrade_page](single/upgrade_page.md) | `lib/page/single/upgrade_page.dart` | 12 | 待分级并补规格 | — |
| single | [video_viewer_page](single/video_viewer_page.md) | `lib/page/single/video_viewer_page.dart` | 11 | 待分级并补规格 | — |
| splash | [splash_page](splash/splash_page.md) | `lib/page/splash/splash_page.dart` | 12 | 待分级并补规格 | — |
| user_tag | [contact_tag_detail_page](user_tag/contact_tag_detail_page.md) | `lib/page/user_tag/contact_tag_detail/contact_tag_detail_page.dart` | 11 | 待分级并补规格 | — |
| user_tag | [contact_tag_list_page](user_tag/contact_tag_list_page.md) | `lib/page/user_tag/contact_tag_list/contact_tag_list_page.dart` | 12 | 待分级并补规格 | — |
| user_tag | [select_tag_friend_page](user_tag/select_tag_friend_page.md) | `lib/page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 12 | 待分级并补规格 | — |
| user_tag | [tag_relation_page](user_tag/tag_relation_page.md) | `lib/page/user_tag/user_tag_relation/tag_relation_page.dart` | 12 | 待分级并补规格 | — |
| user_tag | [user_tag_save_page](user_tag/user_tag_save_page.md) | `lib/page/user_tag/user_tag_save/user_tag_save_page.dart` | 11 | 待分级并补规格 | — |
| wallet | [red_packet_detail_page](wallet/red_packet_detail_page.md) | `lib/page/wallet/red_packet_detail_page.dart` | 12 | 待分级并补规格 | — |
| wallet | [red_packet_send_page](wallet/red_packet_send_page.md) | `lib/page/wallet/red_packet_send_page.dart` | 12 | 待分级并补规格 | — |
| wallet | [transfer_send_page](wallet/transfer_send_page.md) | `lib/page/wallet/transfer_send_page.dart` | 12 | 已有样板（需继续细化） | `WALLET-TRANSFER-001` |
| wallet | [wallet_page](wallet/wallet_page.md) | `lib/page/wallet/wallet_page.dart` | 12 | 已有样板（需继续细化） | `WALLET-TRANSFER-001` |
| wallet | [withdraw_page](wallet/withdraw_page.md) | `lib/page/wallet/withdraw_page.dart` | 13 | 待分级并补规格 | — |
| web_shell | [web_shell_page](web_shell/web_shell_page.md) | `lib/page/web_shell/web_shell_page.dart` | 11 | 待分级并补规格 | — |
| welcome | [welcome_page](welcome/welcome_page.md) | `lib/page/welcome/welcome_page.dart` | 12 | 待分级并补规格 | — |
| workspace | [project_channels_page](workspace/project_channels_page.md) | `lib/page/workspace/project/w2/project_channels_page.dart` | 11 | 待分级并补规格 | — |
| workspace | [project_create_page](workspace/project_create_page.md) | `lib/page/workspace/project/home/project_create_page.dart` | 9 | 待分级并补规格 | — |
| workspace | [project_detail_page](workspace/project_detail_page.md) | `lib/page/workspace/project/home/project_detail_page.dart` | 11 | 待分级并补规格 | — |
| workspace | [project_insights_page](workspace/project_insights_page.md) | `lib/page/workspace/project/w2/project_insights_page.dart` | 10 | 待分级并补规格 | — |
| workspace | [project_members_page](workspace/project_members_page.md) | `lib/page/workspace/project/w2/project_members_page.dart` | 13 | 待分级并补规格 | — |
| workspace | [project_milestones_page](workspace/project_milestones_page.md) | `lib/page/workspace/project/w2/project_milestones_page.dart` | 13 | 待分级并补规格 | — |
| workspace | [task_form_page](workspace/task_form_page.md) | `lib/page/workspace/project/tasks/task_form_page.dart` | 13 | 待分级并补规格 | — |
| workspace | [workspace_branding_page](workspace/workspace_branding_page.md) | `lib/page/workspace/workspace_branding_page.dart` | 11 | 待分级并补规格 | — |
| workspace | [workspace_channel_detail_page](workspace/workspace_channel_detail_page.md) | `lib/page/workspace/workspace_channel_detail_page.dart` | 9 | 待分级并补规格 | — |
| workspace | [workspace_channels_page](workspace/workspace_channels_page.md) | `lib/page/workspace/workspace_channels_page.dart` | 8 | 待分级并补规格 | — |
| workspace | [workspace_create_page](workspace/workspace_create_page.md) | `lib/page/workspace/workspace_create_page.dart` | 10 | 待分级并补规格 | — |
| workspace | [workspace_groups_page](workspace/workspace_groups_page.md) | `lib/page/workspace/workspace_groups_page.dart` | 8 | 待分级并补规格 | — |
| workspace | [workspace_invite_page](workspace/workspace_invite_page.md) | `lib/page/workspace/workspace_invite_page.dart` | 17 | 待分级并补规格 | — |
| workspace | [workspace_join_page](workspace/workspace_join_page.md) | `lib/page/workspace/workspace_join_page.dart` | 11 | 待分级并补规格 | — |
| workspace | [workspace_members_page](workspace/workspace_members_page.md) | `lib/page/workspace/workspace_members_page.dart` | 13 | 待分级并补规格 | — |
| workspace | [workspace_overview_page](workspace/workspace_overview_page.md) | `lib/page/workspace/workspace_overview_page.dart` | 11 | 待分级并补规格 | — |
| workspace | [workspace_picker_page](workspace/workspace_picker_page.md) | `lib/page/workspace/workspace_picker_page.dart` | 11 | 待分级并补规格 | — |
| workspace | [workspace_projects_page](workspace/workspace_projects_page.md) | `lib/page/workspace/workspace_projects_page.dart` | 10 | 待分级并补规格 | — |
