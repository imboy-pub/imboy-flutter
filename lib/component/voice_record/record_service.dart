import 'package:flutter/material.dart';

// import 'package:flutter_plugin_record/flutter_plugin_record.dart';

import './wechat_voice_animation.dart';

class RecordService {
  static final RecordService _singleton = RecordService._internal();

  factory RecordService() {
    return _singleton;
  }

  RecordService._internal() {
    _init();
  }

  // final FlutterPluginRecord _recordPlugin = new FlutterPluginRecord();
  //
  // FlutterPluginRecord get recordPlugin => _recordPlugin;

  GlobalKey<WeChatVoiceWidgetState>? _currentVoiceKey;

  GlobalKey<WeChatVoiceWidgetState>? get currentVoiceKey => _currentVoiceKey;

  void setCurrentVoiceKey(GlobalKey<WeChatVoiceWidgetState> key) {
    _currentVoiceKey = key;
  }

  void clearCurrentVoiceKey() {
    _currentVoiceKey = null;
  }

  void _init() {
    ///初始化方法的监听
    // _recordPlugin.responseFromInit.listen((data) {
    //   if (data) {
    //     print("初始化成功");
    //   } else {
    //     print("初始化失败");
    //   }
    // });

    // _recordPlugin.responsePlayStateController.listen((data) {
    //   print("播放路径   " + data.playPath);
    //   print("播放状态   " + data.playState);
    //   print(_currentVoiceKey == null);
    //   print(data.playState == "complete");
    //   if (data.playState == "complete" && _currentVoiceKey != null) {
    //     _currentVoiceKey!.currentState!.stop();
    //     _currentVoiceKey = null;
    //   }
    // });
  }
}
