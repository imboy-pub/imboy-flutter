import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class LifecycleEventHandler extends WidgetsBindingObserver {
  // static const String TAG = '==lifecycle_event_handler==';
  final AsyncCallback resumeCallBack;
  final AsyncCallback suspendingCallBack;
  final AsyncCallback pausedCallBack;

  LifecycleEventHandler({
    required this.resumeCallBack,
    required this.suspendingCallBack,
    required this.pausedCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed: // 恢复
          await resumeCallBack();
        break;
      case AppLifecycleState.inactive: // 不活跃的
        break;
      case AppLifecycleState.paused: // 已暂停的
        await pausedCallBack();
        break;
      case AppLifecycleState.detached: // 分离的
          await suspendingCallBack();
        break;
    }
  }
}
