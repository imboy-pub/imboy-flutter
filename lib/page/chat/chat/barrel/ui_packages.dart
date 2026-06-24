/// Flutter UI 相关导入 Barrel
library;

// 核心 Flutter UI (hide RefreshCallback 避免冲突)
export 'package:flutter/cupertino.dart' hide RefreshCallback;
export 'package:flutter/material.dart';
export 'package:flutter/foundation.dart';
export 'package:flutter/services.dart';

// 状态管理
export 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:imboy/component/ui/app_loading.dart';

// Flutter Chat UI (hide TimeAndStatus 和 CustomMessageBuilder 避免冲突)
export 'package:flutter_chat_core/flutter_chat_core.dart'
    hide CustomMessageBuilder;
export 'package:flutter_chat_ui/flutter_chat_ui.dart';

// flyer_chat_* 组件 (hide TimeAndStatus 避免冲突)
export 'package:flyer_chat_audio_message/flyer_chat_audio_message.dart';
export 'package:flyer_chat_file_message/flyer_chat_file_message.dart'
    hide TimeAndStatus;
export 'package:flyer_chat_image_message/flyer_chat_image_message.dart'
    hide TimeAndStatus;
export 'package:flyer_chat_location_message/flyer_chat_location_message.dart';
export 'package:flyer_chat_system_message/flyer_chat_system_message.dart';
export 'package:flyer_chat_text_message/flyer_chat_text_message.dart'
    hide TimeAndStatus;
export 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart'
    hide TimeAndStatus;
export 'package:flyer_chat_video_message/flyer_chat_video_message.dart';

// 其他 UI 库 (image 包单独导入避免 Color 冲突)
export 'package:xid/xid.dart';
export 'package:visibility_detector/visibility_detector.dart';
export 'package:connectivity_plus/connectivity_plus.dart';
export 'package:file_picker/file_picker.dart';
export 'package:map_launcher/map_launcher.dart';
export 'package:mime/mime.dart';
export 'package:photo_view/photo_view.dart';
export 'package:wechat_assets_picker/wechat_assets_picker.dart';
