/// 选择器处理器 Mixin
///
/// 处理文件、收藏、名片、位置等选择功能
library;

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 类型定义
typedef StateSetter = void Function(VoidCallback fn);

/// 选择器处理器 Mixin
///
/// 提供文件、收藏、名片、位置等选择功能的简化接口
mixin SelectionHandler {
  // 获取 BuildContext
  BuildContext get context;

  // 获取 WidgetRef
  WidgetRef get ref;

  // 获取 conversationUk3
  String get conversationUk3;

  // 获取 peer 对象（用于转发等）
  Map<String, dynamic> get peer;

  // 获取 chatInputKey
  GlobalKey get chatInputKey;

  // 获取 burnEnabled 和 burnAfterMs
  bool get burnEnabled;
  int get burnAfterMs;

  // 添加消息的回调
  Future<bool> Function(Message message)? get onMessageCreated;

  // 获取 AttachmentHandler 实例
  dynamic get attachmentHandler;

  /// 处理文件选择
  Future<void> handleFileSelection() async {
    await attachmentHandler.handleFileSelection(context);
  }

  /// 处理图片/视频选择
  Future<void> handlePickerSelection(BuildContext context) async {
    await attachmentHandler.handlePickerSelection(context);
  }

  /// 处理语音选择
  Future<void> handleVoiceSelection(dynamic obj) async {
    await attachmentHandler.handleVoiceSelection(obj);
  }

  /// 处理位置选择
  Future<void> handleLocationSelection(
    String id,
    Uint8List? imageBytes,
    String address,
    String title,
    String latitude,
    String longitude,
  ) async {
    await attachmentHandler.handleLocationSelection(
      context,
      id,
      imageBytes,
      address,
      title,
      latitude,
      longitude,
    );
  }
}
