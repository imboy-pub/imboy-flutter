import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/helper/permission.dart';
import 'package:imboy/component/helper/picker_method.dart';
import 'package:imboy/component/voice_record/voice_widget.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/chat/widget/extra_item.dart';
import 'package:imboy/store/provider/attachment_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:xid/xid.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';

/// 文件和媒体处理相关的Mixin
/// 负责处理文件选择、上传、图片处理等媒体相关功能
mixin MediaHandlingMixin<T extends StatefulWidget> on State<T> {
  // 获取当前聊天页面逻辑对象
  ChatLogic get logic => getx.Get.find<ChatLogic>();
  
  // 获取当前用户ID
  String get currentUserId => UserRepoLocal.to.currentUid;
  
  // 获取聊天类型
  String get chatType => widget is MediaHandlingMixinState 
      ? (widget as MediaHandlingMixinState).type 
      : throw UnimplementedError('chatType must be provided');
  
  // 获取对方ID
  String get peerId => widget is MediaHandlingMixinState 
      ? (widget as MediaHandlingMixinState).peerId 
      : throw UnimplementedError('peerId must be provided');

  /// 选择图片
  Future<void> pickImage(BuildContext context) async {
    try {
      // 请求相册权限
      bool hasPermission = await requestPhotoPermission();
      if (!hasPermission) {
        return;
      }
      
      // 选择图片
      final List<AssetEntity>? result = await PickMethod.cameraAndStay(maxAssetsCount: 9).method(context, []);
      if (result != null) {
        for (var entity in result) {
          await AttachmentProvider.uploadVideo(
            "img",
            entity,
                (Map<String, dynamic> resp, String imgUrl) async {
              if (entity.type == AssetType.image) {
                await _handleSelectedImageUpload(resp, imgUrl, entity);
              } else if (entity.type == AssetType.video) {
                await _handleSelectedVideoUpload(resp);
              }
            },
                (Error error) => debugPrint("Asset upload error: ${error.toString()}"),
            uploadOriginalImage: true,
          );
        }
      }
    } catch (e) {
      iPrint('pickImage error: $e');
      EasyLoading.showToast('选择图片失败');
    }
  }

  /// 拍照
  Future<void> takePhoto(BuildContext context) async {
    try {
      // 请求相机权限
      bool hasPermission = await requestCameraPermission();
      if (!hasPermission || !context.mounted) {
        return;
      }
      
      final AssetEntity? entity = await CameraPicker.pickFromCamera(
        context,
        pickerConfig: const CameraPickerConfig(
          enableRecording: true,
          onlyEnableRecording: false,
          enableTapRecording: true,
          maximumRecordingDuration: Duration(seconds: 24),
        ),
      );
      
      if (!context.mounted || entity == null) return;
      await _uploadCameraAsset(entity);
    } catch (e) {
      iPrint('takePhoto error: $e');
      EasyLoading.showToast('拍照失败');
    }
  }

  /// 选择视频
  Future<void> pickVideo(BuildContext context) async {
    try {
      // 请求相册权限
      bool hasPermission = await requestPhotoPermission();
      if (!hasPermission) {
        return;
      }
      
      // 选择视频
      final List<AssetEntity>? result = await PickMethod.cameraAndStay(maxAssetsCount: 9).method(context, []);
      if (result != null) {
        for (var entity in result) {
          await AttachmentProvider.uploadVideo(
            "img",
            entity,
                (Map<String, dynamic> resp, String imgUrl) async {
              if (entity.type == AssetType.image) {
                await _handleSelectedImageUpload(resp, imgUrl, entity);
              } else if (entity.type == AssetType.video) {
                await _handleSelectedVideoUpload(resp);
              }
            },
                (Error error) => debugPrint("Asset upload error: ${error.toString()}"),
            uploadOriginalImage: true,
          );
        }
      }
    } catch (e) {
      iPrint('pickVideo error: $e');
      EasyLoading.showToast('选择视频失败');
    }
  }

  /// 录制视频
  Future<void> recordVideo(BuildContext context) async {
    try {
      // 请求相机权限
      bool hasPermission = await requestCameraPermission();
      if (!hasPermission || !context.mounted) {
        return;
      }
      
      final AssetEntity? entity = await CameraPicker.pickFromCamera(
        context,
        pickerConfig: const CameraPickerConfig(
          enableRecording: true,
          onlyEnableRecording: true,
          maximumRecordingDuration: Duration(seconds: 24),
        ),
      );
      
      if (!context.mounted || entity == null) return;
      await _uploadCameraAsset(entity);
    } catch (e) {
      iPrint('recordVideo error: $e');
      EasyLoading.showToast('录制视频失败');
    }
  }

  /// 选择文件
  Future<void> pickFile(BuildContext context) async {
    try {
      // 检查存储权限
      final hasPermission = await requestPhotoPermission();
      if (!hasPermission) {
        return;
      }

      // 选择文件
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;
      await _uploadFile(result.files.single);
    } catch (e) {
      iPrint('pickFile error: $e');
      EasyLoading.showToast('选择文件失败');
    }
  }

  /// 选择位置
  Future<void> pickLocation(BuildContext context) async {
    try {
      // 检查位置权限
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return;
      }
      
      // 打开位置选择页面
      // 这里需要实现位置选择功能
      EasyLoading.showToast('位置选择功能暂未实现');
    } catch (e) {
      iPrint('pickLocation error: $e');
      EasyLoading.showToast('选择位置失败');
    }
  }

  /// 发送名片
  Future<void> sendVisitCard(BuildContext context) async {
    try {
      // 打开联系人选择页面
      // final user = await Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => const ContactPickerPage(),
      //   ),
      // );

      // if (user != null) {
      //   // 发送名片消息
      //   _sendVisitCardMessage(user);
      // }
      
      // 暂时显示提示
      EasyLoading.showToast('名片发送功能暂未实现');
    } catch (e) {
      iPrint('sendVisitCard error: $e');
      EasyLoading.showToast('发送名片失败');
    }
  }

  /// 上传文件
  Future<void> _uploadFile(PlatformFile file) async {
    await AttachmentProvider.uploadFile(
      "files",
      file,
          (Map<String, dynamic> resp, String uri) async {
        final message = FileMessage(
          id: Xid().toString(),
          authorId: currentUserId,
          createdAt: DateTimeHelper.now(),
          mimeType: lookupMimeType(file.path!),
          name: file.name,
          size: file.size,
          source: uri,
          status: MessageStatus.sending,
          metadata: {
            'peer_id': peerId,
            'md5': resp['data']['md5'].toString(),
          },
        );
        _addMessage(message);
      },
          (Error error) => debugPrint("File upload error: ${error.toString()}"),
    );
  }
  
  /// 上传拍摄的资源
  Future<void> _uploadCameraAsset(AssetEntity entity) async {
    await AttachmentProvider.uploadVideo(
      "camera",
      entity,
          (Map<String, dynamic> resp, String imgUrl) async {
        imgUrl += "&width=${getx.Get.width.toInt()}";
        if (entity.type == AssetType.image) {
          await _handleImageUpload(resp, imgUrl, entity);
        } else if (entity.type == AssetType.video) {
          await _handleVideoUpload(resp);
        }
      },
          (Error error) => debugPrint("Camera upload error: ${error.toString()}"),
      uploadOriginalImage: true,
    );
    // 上传后删除临时文件
    (await entity.file)?.deleteSync();
  }
  
  /// 处理图片上传
  Future<void> _handleImageUpload(
      Map<String, dynamic> resp,
      String imgUrl,
      AssetEntity entity,
      ) async {
    final message = ImageMessage(
      authorId: currentUserId,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      text: await entity.titleAsync,
      height: entity.height * 1.0,
      width: entity.width * 1.0,
      size: resp["data"]["size"],
      source: imgUrl,
      metadata: {
        'peer_id': peerId,
        'md5': resp['data']['md5'].toString(),
      },
    );
    _addMessage(message);
  }
  
  /// 处理视频上传
  Future<void> _handleVideoUpload(Map<String, dynamic> resp) async {
    final message = CustomMessage(
      authorId: currentUserId,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      metadata: {
        'custom_type': 'video',
        'peer_id': peerId,
        'thumb': (resp['thumb'] as EntityImage).toJson(),
        'video': (resp['video'] as EntityVideo).toJson(),
      },
    );
    _addMessage(message);
  }
  
  /// 处理选择的图片上传
  Future<void> _handleSelectedImageUpload(
      Map<String, dynamic> resp,
      String imgUrl,
      AssetEntity entity,
      ) async {
    double w = getx.Get.width;
    imgUrl += "&width=${w.toInt()}";
    final message = ImageMessage(
      authorId: currentUserId,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      text: await entity.titleAsync,
      height: entity.height * 1.0,
      width: entity.width * 1.0,
      size: resp["data"]["size"],
      source: imgUrl,
      metadata: {
        'peer_id': peerId,
        'md5': resp['data']['md5'].toString(),
      },
    );
    _addMessage(message);
  }
  
  /// 处理选择的视频上传
  Future<void> _handleSelectedVideoUpload(Map<String, dynamic> resp) async {
    final message = CustomMessage(
      authorId: currentUserId,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      metadata: {
        'custom_type': 'video',
        'peer_id': peerId,
        'thumb': (resp['thumb'] as EntityImage).toJson(),
        'video': (resp['video'] as EntityVideo).toJson(),
      },
    );
    _addMessage(message);
  }
  
  /// 发送语音消息（修复版本）
  Future<void> handleVoiceSelection(AudioFile? obj) async {
    try {
      if (obj == null) {
        iPrint('语音录制结果为空');
        EasyLoading.showToast('语音录制失败，请重试');
        return;
      }

      // 更可靠的文件验证：先检查文件是否存在，再检查文件大小
      if (!await obj.file.exists()) {
        iPrint('语音文件不存在: ${obj.file.path}');
        EasyLoading.showToast('语音文件不存在，请重试');
        return;
      }

      final fileSize = await obj.file.length();
      if (fileSize <= 0) {
        iPrint('语音文件大小为0: ${obj.file.path}');
        EasyLoading.showToast('语音文件为空，请重试');
        return;
      }

      // 检查文件是否可读
      try {
        // 只读取文件的前几个字节来验证文件是否可读，而不是整个文件
        final bytes = await obj.file.openRead(0, 1).first;
        if (bytes.isEmpty) {
          iPrint('语音文件无法读取: ${obj.file.path}');
          EasyLoading.showToast('语音文件无法读取，请重试');
          return;
        }
      } catch (e) {
        iPrint('语音文件读取失败: ${e.toString()}');
        EasyLoading.showToast('语音文件读取失败，请重试');
        return;
      }

      EasyLoading.show(status: '正在发送语音...');

      await AttachmentProvider.uploadFile(
        'audio',
        obj.file,
        (Map<String, dynamic> resp, String uri) async {
          try {
            // 验证响应数据
            if (resp['data'] == null || resp['data']['md5'] == null) {
              throw Exception('上传响应数据无效');
            }

            final durationMs = obj.duration.inMilliseconds;
            if (durationMs < 500) {
              throw Exception('语音时长过短，至少需要0.5秒');
            }

            // 构建语音消息
            final message = CustomMessage(
              authorId: currentUserId,
              createdAt: DateTimeHelper.now(),
              id: Xid().toString(),
              metadata: {
                'custom_type': 'audio',
                'peer_id': peerId,
                'uri': uri,
                'size': fileSize,
                'duration_ms': durationMs,
                'waveform': obj.waveform.isNotEmpty ? obj.waveform : List.generate(20, (index) => 0.3 + (index % 3) * 0.2),
                'mime_type': obj.mimeType,
                'md5': resp['data']['md5'].toString(),
              },
            );

            // 添加消息到聊天
            final addResult = await _addMessage(message);
            if (addResult) {
              EasyLoading.showSuccess('语音发送成功');
            } else {
              EasyLoading.showError('语音发送失败');
            }
          } catch (e) {
            iPrint('语音消息处理异常: $e');
            EasyLoading.showError('语音处理异常: ${e.toString()}');
          }
        },
        (Error error) async {
          iPrint('语音上传失败: ${error.toString()}');
          EasyLoading.showError('语音上传失败，请检查网络连接');
        },
        process: false,
      );

      // 清理临时文件
      try {
        if (await obj.file.exists()) {
          await obj.file.delete(recursive: true);
        }
      } catch (e) {
        iPrint('清理临时语音文件失败: $e');
      }
    } catch (e) {
      iPrint('发送语音消息异常: $e');
      EasyLoading.showError('语音发送异常: ${e.toString()}');
    } finally {
      EasyLoading.dismiss();
    }
  }
  
  /// 添加消息
  Future<bool> _addMessage(Message message) async {
    try {
      await logic.addMessage(
        UserRepoLocal.to.currentUid,
        peerId,
        widget is MediaHandlingMixinState ? (widget as MediaHandlingMixinState).peerAvatar : '',
        widget is MediaHandlingMixinState ? (widget as MediaHandlingMixinState).peerTitle : '',
        chatType == 'null' ? 'C2C' : chatType,
        message,
      );
      logic.chatController?.insertMessage(
        message,
        index: logic.chatController?.messages.length ?? 0,
      );
      return true;
    } catch (e, stack) {
      debugPrint("_addMessage error: $e : $stack");
      return false;
    }
  }

  /// 发送位置消息
  void _sendLocationMessage(Map<String, dynamic> location) {
    try {
      // 创建位置消息（自定义消息）
      final message = CustomMessage(
        id: '',
        authorId: currentUserId,
        createdAt: DateTime.now(),
        metadata: {
          'custom_type': 'location',
          'latitude': location['latitude'],
          'longitude': location['longitude'],
          'address': location['address'] ?? '',
          'name': location['name'] ?? '',
        },
        status: MessageStatus.sending,
      );
      
      // 添加消息到聊天
      logic.addMessage(
        UserRepoLocal.to.currentUid,
        peerId,
        widget is MediaHandlingMixinState ? (widget as MediaHandlingMixinState).peerAvatar : '',
        widget is MediaHandlingMixinState ? (widget as MediaHandlingMixinState).peerTitle : '',
        chatType == 'null' ? 'C2C' : chatType,
        message,
      );
    } catch (e) {
      iPrint('_sendLocationMessage error: $e');
      EasyLoading.showToast('发送位置失败');
    }
  }

  /// 发送名片消息
  void _sendVisitCardMessage(Map<String, dynamic> user) {
    try {
      // 创建名片消息（自定义消息）
      final message = CustomMessage(
        id: '',
        authorId: currentUserId,
        createdAt: DateTime.now(),
        metadata: {
          'custom_type': 'visit_card',
          'uid': user['id'],
          'nickname': user['nickname'] ?? '',
          'avatar': user['avatar'] ?? '',
        },
        status: MessageStatus.sending,
      );
      
      // 添加消息到聊天
      logic.addMessage(
        UserRepoLocal.to.currentUid,
        peerId,
        widget is MediaHandlingMixinState ? (widget as MediaHandlingMixinState).peerAvatar : '',
        widget is MediaHandlingMixinState ? (widget as MediaHandlingMixinState).peerTitle : '',
        chatType == 'null' ? 'C2C' : chatType,
        message,
      );
    } catch (e) {
      iPrint('_sendVisitCardMessage error: $e');
      EasyLoading.showToast('发送名片失败');
    }
  }

  /// 保存文件到本地
  Future<void> saveFile(String fileName, String url) async {
    try {
      EasyLoading.show(status: '保存中...');
      
      // 调用逻辑层保存文件
      await logic.saveFile(fileName, url);
      EasyLoading.showToast('保存成功');
    } catch (e) {
      iPrint('saveFile error: $e');
      EasyLoading.showToast('保存失败');
    } finally {
      EasyLoading.dismiss();
    }
  }
  
  /// 处理额外功能项点击
  void handleExtraItemClick(BuildContext context, ExtraItem item) {
    // 根据item的类型处理不同的功能
    // 这里需要根据实际ExtraItem的实现来调整
    EasyLoading.showToast('功能暂未实现');
  }
  
  /// 处理图片选择
  void handleImageSelection() {
    pickImage(context);
  }
  
  /// 处理文件选择
  void handleFileSelection() {
    pickFile(context);
  }
  
  /// 处理选择器选择
  void handlePickerSelection(BuildContext context) {
    takePhoto(context);
  }
  
  /// 处理位置选择
  void handleLocationSelection(String id, Uint8List image, String address, String title, String latitude, String longitude) {
    // 创建位置消息
    final message = CustomMessage(
      id: id,
      authorId: currentUserId,
      createdAt: DateTimeHelper.now(),
      metadata: {
        'custom_type': 'location',
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'name': title,
        'image': image,
      },
    );
    
    // 添加消息到聊天
    _addMessage(message);
  }
  
  /// 处理名片选择
  void handleVisitCardSelection() {
    sendVisitCard(context);
  }
  
  /// 处理收藏选择
  void handleCollectSelection() {
    // 打开收藏页面
    // final collect = await Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => const UserCollectPage(),
    //   ),
    // );

    // if (collect != null) {
    //   // 发送收藏消息
    //   _sendCollectMessage(collect);
    // }
    
    // 暂时显示提示
    EasyLoading.showToast('收藏发送功能暂未实现');
  }
}

/// 媒体处理Mixin状态接口
/// 用于提供必要的状态信息给MediaHandlingMixin
abstract class MediaHandlingMixinState {
  String get type;
  String get peerId;
  String get peerAvatar;
  String get peerTitle;
}