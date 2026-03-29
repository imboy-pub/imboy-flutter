/// Stable module entry for ops governance flows.
/// Keep feedback, version, upgrade, notification, settings, feature flags,
/// and user device internals in place and import this file from upper layers.
library;

export '../../page/mine/feedback/feedback_detail_page.dart';
export '../../page/mine/feedback/feedback_page.dart';
export '../../page/mine/feedback/feedback_provider.dart'
    show FeedbackPageNotifier, FeedbackPageState, feedbackPageProvider;
export '../../page/mine/setting/setting_page.dart';
export '../../page/mine/dark_model/dark_model_page.dart';
export '../../page/mine/font_size/font_size_page.dart';
export '../../page/mine/language/language_page.dart';
export '../../page/mine/storage_space/storage_space_page.dart';
export '../../page/mine/help/help_page.dart';
export '../../page/mine/logout_account/logout_account_page.dart';
export '../../page/mine/user_device/user_device_page.dart';
export '../../page/mine/user_device/user_device_detail_page.dart';
export '../../page/single/upgrade.dart';
export '../../service/feature_registry.dart';
export '../../service/notification.dart' show NotificationService;
export '../../service/notification_provider.dart'
    show notificationServiceProvider;
export '../../store/api/app_version_api.dart' show AppVersionApi;
export '../../store/api/feedback_api.dart' show FeedbackApi;
