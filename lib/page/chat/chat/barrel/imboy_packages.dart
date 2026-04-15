/// ImBoy 组件和服务 Barrel
library;

// 组件 (hide CustomMessageBuilder 避免与 flutter_chat_core 冲突)
export 'package:imboy/component/chat/message.dart' hide CustomMessageBuilder;
export 'package:imboy/component/chat/performance_monitor.dart';
export 'package:imboy/component/chat/message_scroll_provider.dart';
export 'package:imboy/component/helper/datetime.dart';
export 'package:imboy/component/helper/func.dart';
export 'package:imboy/component/helper/picker_method.dart';
export 'package:imboy/component/image_gallery/image_gallery.dart';
export 'package:imboy/component/ui/common_bar.dart';
export 'package:imboy/component/voice_record/voice_widget.dart';

// 页面组件
export 'package:imboy/page/chat/widget/chat_input_height_listener.dart';
export 'package:imboy/page/chat/widget/message_action_menu.dart';
export 'package:imboy/page/chat/widget/chat_background_manager.dart';
export 'package:imboy/page/chat/widget/chat_message_list.dart';
export 'package:imboy/page/chat/mention_all_rules.dart';
export 'package:imboy/page/chat/chat/utils/typing_indicator_rules.dart';
export 'package:imboy/page/chat/chat/utils/send_mode_rules.dart';
export 'package:imboy/page/chat/chat/utils/event_filter_rules.dart';

// 服务
export 'package:imboy/config/init.dart';
export 'package:imboy/service/event_bus.dart';
export 'package:imboy/modules/security_privacy/public.dart';
export 'package:imboy/modules/messaging/public.dart';
export 'package:imboy/service/active_conversation_notifier.dart';
export 'package:imboy/service/voice_playback_service.dart';
export 'package:imboy/service/events/common_events.dart';

// 主题
export 'package:imboy/theme/default/font_types.dart';
export 'package:imboy/theme/default/config/chat_theme_config.dart';
export 'package:imboy/theme/default/app_radius.dart';

// 国际化
export 'package:imboy/i18n/strings.g.dart';
