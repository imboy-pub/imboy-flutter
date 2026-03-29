/// Stable module entry for ops and governance flows.
/// Keep feedback, version, upgrade, and notification internals in place and
/// import this file from upper layers.
library;

export '../../page/mine/feedback/feedback_detail_page.dart';
export '../../page/mine/feedback/feedback_page.dart';
export '../../page/mine/feedback/feedback_provider.dart'
    show FeedbackPageNotifier, FeedbackPageState, feedbackPageProvider;
export '../../page/single/upgrade.dart';
export '../../service/notification.dart' show NotificationService;
export '../../service/notification_provider.dart'
    show notificationServiceProvider;
export '../../store/api/app_version_api.dart' show AppVersionApi;
export '../../store/api/feedback_api.dart' show FeedbackApi;
