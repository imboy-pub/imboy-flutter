import 'dart:async';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/helper/permission.dart';
import 'package:imboy/page/chat/widget/chat_input_height_listener.dart';
import 'package:imboy/page/chat/widget/message_action_menu.dart';
import 'package:imboy/page/chat/widget/chat_background_manager.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide CustomMessageBuilder;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flyer_chat_file_message/flyer_chat_file_message.dart';
import 'package:flyer_chat_system_message/flyer_chat_system_message.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/config/chat_theme_config.dart';
import 'package:image/image.dart' as img;
import 'package:map_launcher/map_launcher.dart';
import 'package:mime/mime.dart';
import 'package:photo_view/photo_view.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:xid/xid.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/chat_extend_model.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/picker_method.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/chat/message.dart';
import 'package:imboy/component/chat/message_image_builder.dart';
import 'package:imboy/component/chat/performance_monitor.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/voice_record/voice_widget.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_view.dart';
import 'package:imboy/page/chat/send_to/send_to_view.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/group/group_detail/group_detail_view.dart';
import 'package:imboy/page/mine/user_collect/user_collect_logic.dart';
import 'package:imboy/page/mine/user_collect/user_collect_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/provider/attachment_provider.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../widget/chat_input.dart';
import '../widget/extra_item.dart';
import '../widget/quote_tips.dart';
import '../widget/select_friend.dart';
import 'chat_logic.dart';
import 'sqlite_chat_controller.dart';

// 聊天页面主Widget
// ignore: must_be_immutable
class ChatPage extends StatefulWidget {
  final String type; // 聊天类型 [C2C | C2G | C2S]
  final String peerId; // 对方ID (用户ID/群组ID/服务ID)
  final String peerAvatar; // 对方头像
  final String peerTitle; // 对方标题/名称
  final String peerSign; // 对方签名
  final String msgId; // 消息ID (用于定位特定消息)
  // 可选配置参数
  final Map<String, dynamic>? options;
  /*
    options可能包含的字段:
    {
      'memberCount':1, // 成员数量，C2G 群聊消息用的
      'popTime':1, // 通过设置 popTime 控制回退几次
      'computeTitle':'', // 计算标题
      'showConversation': true // 面对面建群的时候为false
    }
  */
  const ChatPage({
    super.key,
    this.type = 'C2C',
    required this.peerId,
    required this.peerTitle,
    required this.peerAvatar,
    required this.peerSign,
    this.msgId = '',
    this.options,
  });
  @override
  ChatPageState createState() => ChatPageState();
}
class ChatPageState extends State<ChatPage> {
  final galleryLogic = getx.Get.put(IMBoyImageGalleryController());
  final logic = getx.Get.find<ChatLogic>();
  final state = getx.Get.find<ChatLogic>().state;
  final conversationLogic = getx.Get.find<ConversationLogic>();
  static const MethodChannel _secureChannel = MethodChannel('imboy/secure');
  static final Stream<int> _burnTicker = Stream<int>.periodic(const Duration(seconds: 1), (i) => i)
      .asBroadcastStream();
  bool _showAppBar = true; // 控制顶部导航栏显示/隐藏
  String newGroupName = ""; // 新群组名称
  int get maxAssetsCount => 9; // 最大可选资源数量
  List<AssetEntity> assets = <AssetEntity>[]; // 选择的资源列表
  Message? quoteMessage; // 引用的消息
  final GlobalKey<ChatInputState> chatInputKey = GlobalKey<ChatInputState>();
  final performanceMonitor = ChatPerformanceMonitor();
  Timer? _cleanupTimer;
  // 可视阈值已读：延迟计时与去重集合
  final Map<String, Timer> _readDelayTimers = {};
  final Set<String> _readCommitted = {};
  // 消息ID集合，用于防止 eventBus 重复渲染消息
  final Set<String> msgIds = {};
  final User currentUser = User(
    id: UserRepoLocal.to.currentUid,
    name: UserRepoLocal.to.current.nickname,
    imageSource: UserRepoLocal.to.current.avatar,
  );
  late ConversationModel conversation; // 当前会话
  late User peer; // 对方用户信息
  String? _editingMessageId; // 当前正在编辑的消息ID
  bool _burnEnabled = false;
  int _burnAfterMs = 30000;
  // StreamSubscription<ConnectivityResult>? _connectivitySubscription; // 网络状态监听
  // 页面初始化
  @override
  void initState() {
    super.initState();
    try {
      logic.resetDisposedState();
      msgIds.clear();
      state.nextAutoId.value = 0;
      state.hasMoreMessage.value = true;
      state.isLoading.value = false;
      _initChat();
      _initData();
      
      // 启动内存清理定时器
      _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        performanceMonitor.cleanupInvisibleMessages();
        if (kDebugMode) {
          final stats = performanceMonitor.getMemoryStats();
          debugPrint('内存使用统计: $stats');
        }
      });
    } catch (e, stack) {
      debugPrint('Error in initState: $e\n$stack');
    }
  }
  /// 初始化聊天相关数据
  Future<void> _initChat() async {
    try {
      logic.initChatController(widget.type);
      // 创建或获取会话
      await _setupConversation();
      await _reloadConversationSettings();
      await logic.cleanupExpiredBurnMessagesForConversation(conversation);
      await logic.loadMoreMessages(conversation, isInitial: true);
      _setupEventListeners();
    } catch (e, stack) {
      debugPrint('_initChat error: $e\n$stack');
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('聊天初始化失败: $e')),
        );
      }
    }
  }
  // 初始化数据
  Future<void> _initData() async {
    peer = User(
      id: widget.peerId,
      name: widget.peerTitle,
      imageSource: widget.peerAvatar,
    );
    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      if (r.contains(ConnectivityResult.none)) {
        // ignore: prefer_interpolation_to_compose_strings
        // state.connected.value = '(${'tipConnectDesc'.tr})';
        state.connected.value = false;
      } else {
        state.connected.value = true;
      }
    });
    if (availableMaps.isEmpty) {
      try {
        availableMaps = await MapLauncher.installedMaps;
      } catch (e) {
        //
      }
    }
    // 初始化群组信息
    await _initGroupInfo();
    // 加载消息
    if (widget.msgId.isNotEmpty) {
      logic.scrollToMessage(widget.type, widget.msgId);
    }
    // 设置消息监听
    _setupEventListeners();
  }
  /// 设置会话
  Future<void> _setupConversation() async {
    bool showConversation = widget.options?['showConversation'] ?? true;
    conversation = await conversationLogic.createConversation(
      type: widget.type,
      peerId: widget.peerId,
      avatar: widget.peerAvatar,
      title: widget.peerTitle,
      subtitle: "",
      lastTime: showConversation ? DateTimeHelper.millisecond() : 0,
    );
    if (showConversation) {
      eventBus.fire(conversation);
    }
    state.nextAutoId.value = 0;
  }

  Future<void> _reloadConversationSettings() async {
    try {
      final c = await ConversationRepo().findByPeerId(widget.type, widget.peerId);
      if (c != null) {
        conversation = c;
      }
      final payload = conversation.payload;
      _burnEnabled = payload?['burn_enabled'] == true;
      final raw = payload?['burn_after_ms'];
      if (raw is int && raw > 0) {
        _burnAfterMs = raw;
      } else if (raw is String) {
        final v = int.tryParse(raw);
        if (v != null && v > 0) _burnAfterMs = v;
      }
      await _applySecureFlag();
    } catch (_) {}
  }

  Future<void> _applySecureFlag() async {
    try {
      await _secureChannel.invokeMethod(_burnEnabled ? 'enable' : 'disable');
    } catch (_) {}
  }

  bool _isBurnMessage(Message message) {
    final m = message.metadata;
    return m?['burn'] == true || m?['is_burn'] == true;
  }

  int _burnAfterMsFromMessage(Message message) {
    final m = message.metadata;
    final raw = m?['burn_after_ms'] ?? m?['expiry_time'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  Map<String, dynamic> _withBurnMetadata(Map<String, dynamic> base) {
    if (!_burnEnabled) return base;
    return <String, dynamic>{
      ...base,
      'burn': true,
      'burn_after_ms': _burnAfterMs,
    };
  }
  // 初始化群组信息
  Future<void> _initGroupInfo() async {
    if (widget.type == 'C2G') {
      state.memberCount.value = widget.options?['memberCount'] ?? 0;
      newGroupName = await logic.groupTitle(
        widget.peerId,
        widget.peerTitle,
        state.memberCount.value,
      );
    }
  }
  void _setupEventListeners() {
    try {
      // 一些异步操作事件的监听
      state.ssMsgExt = eventBus.on<ChatExtendModel>().listen((
          ChatExtendModel obj,
          ) async {
        try {
          // 监听新成员加入
          if (obj.type == 'join_group' &&
              obj.payload['groupId'] == widget.peerId &&
              (obj.payload['isFirst'] ?? false)) {
            state.memberCount.value += 1;
            newGroupName = await logic.groupTitle(
              widget.peerId,
              widget.peerTitle,
              state.memberCount.value,
            );
            if (mounted) setState(() {});
          } else if (obj.type == 'clean_msg' &&
              ((obj.payload['uk3'] ?? '') == conversation.uk3)) {
            state.nextAutoId.value = 0;
            await logic.loadMoreMessages(conversation, isInitial: true);
          } else if (obj.type == 'delete_msg' &&
              obj.payload['conversation'] != null && 
              obj.payload['conversation'].id == conversation.id) {
            logic.chatController?.removeMessageById(obj.payload['msg']?.id ?? '');
          }
        } catch (e) {
          debugPrint('_setupEventListeners ssMsgExt error: $e');
        }
      }, onError: (error) {
        debugPrint('ssMsgExt stream error: $error');
      });
      
      // 接收到新的消息订阅 for c2c c2g
      state.ssMsg = eventBus.on<Message>().listen((Message msg) async {
        try {
          final String conversationUk3 = msg.metadata?['conversation_uk3'] ?? '';
          if (conversationUk3 != conversation.uk3 || msgIds.contains(msg.id)) {
            return;
          }
          msgIds.add(msg.id);
          final i = logic.chatController?.messages.indexWhere((e) => e.id == msg.id) ?? -1;
          if (i == -1) {
            // 不再强制立即置为已读，交由“可视阈值已读”推进水位
            logic.chatController?.insertMessage(
              msg,
              index: logic.chatController?.messages.length ?? 0,
            );
            if (msg is ImageMessage) {
              galleryLogic.pushToLast(msg.id, msg.source);
            }
          }
          // 为节省内存，5秒后从 msgIds 移出 msg.id
          Future.delayed(const Duration(seconds: 5), () => msgIds.remove(msg.id));
        } catch (e) {
          debugPrint('_setupEventListeners ssMsg error: $e');
        }
      }, onError: (error) {
        debugPrint('ssMsg stream error: $error');
      });
      
      // 消息状态更新订阅, 这里无需用锁 for c2g
      state.ssMsgState = eventBus.on<List<Message>>().listen((e) {
        try {
          if (e.isEmpty) return;
          Message msg = e.first;
          iPrint('收到消息状态更新事件: msgId=${msg.id}, type=${msg.runtimeType}');
          final i = logic.chatController?.messages.indexWhere((e) => e.id == msg.id) ?? -1;
          final messageCount = logic.chatController?.messages.length ?? 0;
          iPrint('在消息列表中查找消息: index=$i, 总消息数=$messageCount');
          if (i > -1 && mounted && logic.chatController != null) {
            final old = logic.chatController!.messages[i];
            iPrint('更新消息UI: ${msg.id}');
            logic.chatController!.updateMessage(logic.chatController!.messages[i], msg);
            final didBecomeSeen = old.status != MessageStatus.seen && msg.status == MessageStatus.seen;
            if (didBecomeSeen && _isBurnMessage(msg) && (msg.metadata?['burn_read_at'] ?? 0) == 0) {
              logic.markBurnReadAt(
                conversation,
                msg.id,
                readAtMs: DateTimeHelper.millisecond(),
              );
            }
          } else {
            iPrint('消息未找到或组件未挂载: msgId=${msg.id}, mounted=$mounted');
          }
        } catch (e) {
          debugPrint('_setupEventListeners ssMsgState error: $e');
        }
      }, onError: (error) {
        debugPrint('ssMsgState stream error: $error');
      });
    } catch (e) {
      debugPrint('_setupEventListeners error: $e');
    }
  }
  @override
  void dispose() {
    // 取消所有订阅
    state.ssMsgExt?.cancel();
    state.ssMsg?.cancel();
    state.ssMsgState?.cancel();
    logic.markAsDisposed();
    
    // 清理消息ID集合
    msgIds.clear();
    
    // 停止内存清理定时器
    _cleanupTimer?.cancel();
    // 取消所有“可视阈值已读”的定时
    for (final t in _readDelayTimers.values) {
      t.cancel();
    }
    _readDelayTimers.clear();
    _readCommitted.clear();
    
    // 清理性能监控内存
    performanceMonitor.cleanupInvisibleMessages();
    
    // 安全地清理聊天控制器
    try {
      logic.chatController?.setMessages([]);
      logic.chatController?.dispose();
    } catch (e) {
      debugPrint('Error disposing chat controller: $e');
    }
    
    // 删除图片画廊逻辑
    try {
      getx.Get.delete<IMBoyImageGalleryController>();
    } catch (e) {
      debugPrint('Error deleting ImageGalleryLogic: $e');
    }
    try {
      _secureChannel.invokeMethod('disable');
    } catch (_) {}
    
    super.dispose();
  }
  // 标记消息为已读
  // 添加消息
  Future<bool> _addMessage(Message message) async {
    try {
      await logic.addMessage(
        UserRepoLocal.to.currentUid,
        widget.peerId,
        widget.peerAvatar,
        widget.peerTitle,
        widget.type == 'null' ? 'C2C' : widget.type,
        message,
      );
      await logic.chatController?.insertMessage(
        message,
        index: logic.chatController?.messages.length ?? 0,
        animated: true, // 新消息使用动画
      );
      return true;
    } catch (e, stack) {
      debugPrint("_addMessage error: $e : $stack");
      return false;
    }
  }
  
  /// 消息重试回调
  /// Message retry callback.
  Future<void> _onMessageRetry(String messageId) async {
    try {
      debugPrint('开始重试消息: $messageId');
      
      // 显示加载状态
      EasyLoading.show(status: '正在重试发送...');
      
      final success = await logic.retryMessage(messageId, widget.type);
      
      EasyLoading.dismiss();
      
      if (success) {
        EasyLoading.showSuccess('重试成功');
      } else {
        EasyLoading.showError('重试失败，请检查网络连接');
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('重试异常: $e');
      debugPrint('消息重试异常: $e');
    }
  }

  // 选择文件
  Future<void> _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    await _uploadFile(result.files.single);
  }
  // 上传文件
  Future<void> _uploadFile(PlatformFile file) async {
    await AttachmentProvider.uploadFile(
      "files",
      file,
          (Map<String, dynamic> resp, String uri) async {
        final message = FileMessage(
          id: Xid().toString(),
          authorId: currentUser.id,
          createdAt: DateTimeHelper.now(),
          mimeType: lookupMimeType(file.path!),
          name: file.name,
          size: file.size,
          source: uri,
          status: MessageStatus.sending,
          metadata: _withBurnMetadata({
            'peer_id': widget.peerId,
            'md5': resp['data']['md5'].toString(),
          }),
        );
        _addMessage(message);
      },
          (Error error) => debugPrint("File upload error: ${error.toString()}"),
    );
  }
  // 拍摄照片或视频
  Future<void> _handlePickerSelection(BuildContext context) async {
    // 在异步操作前检查 context 是否已挂载
    if (!context.mounted) {
      return;
    }
    try {
      // 请求相机权限
      bool hasPermission = await requestCameraPermission();
      if (!hasPermission || !context.mounted) {  // 添加 mounted 检查
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
      // 检查上下文是否仍然有效
      if (!context.mounted || entity == null) return;
      await _uploadCameraAsset(entity);
    } catch (e) {
      debugPrint("Camera picker error: $e");
      if (context.mounted) {  // 错误处理时检查 mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍摄失败: $e')),
        );
      }
    }
  }
  // 上传拍摄的资源
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
  // 处理图片上传
  Future<void> _handleImageUpload(
      Map<String, dynamic> resp,
      String imgUrl,
      AssetEntity entity,
      ) async {
    final message = ImageMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      text: await entity.titleAsync,
      height: entity.height * 1.0,
      width: entity.width * 1.0,
      size: resp["data"]["size"],
      source: imgUrl,
      metadata: _withBurnMetadata({
        'peer_id': widget.peerId,
        'md5': resp['data']['md5'].toString(),
      }),
    );
    _addMessage(message);
  }
  // 处理视频上传
  Future<void> _handleVideoUpload(Map<String, dynamic> resp) async {
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'custom_type': 'video',
        'peer_id': widget.peerId,
        'thumb': (resp['thumb'] as EntityImage).toJson(),
        'video': (resp['video'] as EntityVideo).toJson(),
      }),
    );
    _addMessage(message);
  }
  // 选择资源(图片/视频)
  Future<void> _selectAssets(PickMethod model) async {
    final List<AssetEntity>? result = await model.method(context, assets);
    if (result != null) {
      assets = List<AssetEntity>.from(result);
      if (mounted) setState(() {});
    }
  }
  // 发送收藏消息
  Future<void> _handleCollectSelection() async {
    final peer = {
      'peer_id': widget.peerId,
      'avatar': widget.peerAvatar,
      'title': widget.peerTitle,
    };
    final collect = await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => UserCollectPage(peer: peer, isSelect: true),
      ),
    );
    if (collect != null) {
      await _sendCollectMessage(collect);
    }
  }
  // 发送收藏消息
  Future<void> _sendCollectMessage(UserCollectModel collect) async {
    final data = collect.info
      ..addAll({
        MessageRepo.id: Xid().toString(),
        MessageRepo.from: UserRepoLocal.to.currentUid,
        MessageRepo.to: widget.peerId,
        MessageRepo.status: 10,
        MessageRepo.conversationUk3: conversation.uk3,
        MessageRepo.createdAt: DateTimeHelper.millisecond(),
      });
    final msg0 = await MessageModel.fromJson(data).toTypeMessage();
    final msg = _burnEnabled
        ? msg0.copyWith(metadata: _withBurnMetadata(Map<String, dynamic>.from(msg0.metadata ?? {})))
        : msg0;
    final res = await _addMessage(msg);
    if (res) {
      getx.Get.find<UserCollectLogic>().change(collect.kindId);
      EasyLoading.showSuccess('tipSuccess'.tr);
    } else {
      EasyLoading.showError('tipFailed'.tr);
    }
  }
  // 发送个人名片
  Future<void> _handleVisitCardSelection() async {
    final peer = {
      'peer_id': widget.peerId,
      'avatar': widget.peerAvatar,
      'title': widget.peerTitle,
    };
    final contact = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => SelectFriendPage(peer: peer)),
    );
    if (contact != null) {
      await _sendVisitCardMessage(contact);
    }
  }
  // 发送个人名片消息
  Future<void> _sendVisitCardMessage(ContactModel contact) async {
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'custom_type': 'visit_card',
        'peer_id': widget.peerId,
        'uid': contact.peerId,
        'title': contact.title,
        'avatar': contact.avatar,
      }),
    );
    final res = await _addMessage(message);
    if (res) {
      EasyLoading.showSuccess('tipSuccess'.tr);
    } else {
      EasyLoading.showError('tipFailed'.tr);
    }
  }
  // 发送位置消息
  Future<void> _handleLocationSelection(
      String id,
      Uint8List? imageBytes,
      String address,
      String title,
      String latitude,
      String longitude,
      ) async {
    if (imageBytes == null) return;
    final image = img.decodeImage(imageBytes)!;
    final result = img.encodeJpg(image, quality: 65);
    await AttachmentProvider.uploadBytes(
      "location",
      result,
          (Map<String, dynamic> resp, String imgUrl) async {
        double w = getx.Get.width;
        imgUrl += "&width=${w.toInt()}";
        final message = CustomMessage(
          authorId: currentUser.id,
          createdAt: DateTimeHelper.now(),
          id: Xid().toString(),
          metadata: _withBurnMetadata({
            'custom_type': 'location',
            'peer_id': widget.peerId,
            'title': title,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
            'thumb': imgUrl,
            'size': resp['data']['size'],
            'md5': resp['data']['md5'].toString(),
          }),
        );
        _addMessage(message);
      },
          (Error error) => debugPrint("Location upload error: ${error.toString()}"),
      process: false,
    );
  }
  // 选择图片/视频
  Future<void> _handleImageSelection() async {
    // Request photo permission before accessing assets
    bool hasPermission = await requestPhotoPermission();
    if (!hasPermission) {
      return; // Permission denied, exit early
    }
    await _selectAssets(
      PickMethod.cameraAndStay(maxAssetsCount: maxAssetsCount),
    );
    await _uploadSelectedAssets();
  }
  // 上传选择的资源
  Future<void> _uploadSelectedAssets() async {
    for (var entity in assets) {
      await AttachmentProvider.uploadVideo(
        "img",
        entity,
            (Map<String, dynamic> resp, String imgUrl) async {
          if (entity.type == AssetType.image) {
            await _handleSelectedImageUpload(resp, imgUrl, entity);
          } else if (entity.type == AssetType.video) {
            await _handleSelectedVideoUpload(resp);
          }
          _removeUploadedAsset(entity);
        },
            (Error error) => debugPrint("Asset upload error: ${error.toString()}"),
        uploadOriginalImage: true,
      );
    }
  }
  // 处理选择的图片上传
  Future<void> _handleSelectedImageUpload(
      Map<String, dynamic> resp,
      String imgUrl,
      AssetEntity entity,
      ) async {
    double w = getx.Get.width;
    imgUrl += "&width=${w.toInt()}";
    final message = ImageMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      text: await entity.titleAsync,
      height: entity.height * 1.0,
      width: entity.width * 1.0,
      size: resp["data"]["size"],
      source: imgUrl,
      metadata: _withBurnMetadata({
        'peer_id': widget.peerId,
        'md5': resp['data']['md5'].toString(),
      }),
    );
    _addMessage(message);
  }
  // 处理选择的视频上传
  Future<void> _handleSelectedVideoUpload(Map<String, dynamic> resp) async {
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'custom_type': 'video',
        'peer_id': widget.peerId,
        'thumb': (resp['thumb'] as EntityImage).toJson(),
        'video': (resp['video'] as EntityVideo).toJson(),
      }),
    );
    _addMessage(message);
  }
  // 移除已上传的资源
  void _removeUploadedAsset(AssetEntity entity) {
    assets.removeWhere((element) => element.id == entity.id);
    if (mounted) setState(() {});
  }
  // 发送语音消息
  Future<void> _handleVoiceSelection(AudioFile? obj) async {
    if (obj == null || (await obj.file.readAsBytes()).isEmpty) return;
    await AttachmentProvider.uploadFile(
      'audio',
      obj.file,
          (Map<String, dynamic> resp, String uri) async {
        final message = CustomMessage(
          authorId: currentUser.id,
          createdAt: DateTimeHelper.now(),
          id: Xid().toString(),
          metadata: _withBurnMetadata({
            'custom_type': 'audio',
            'peer_id': widget.peerId,
            'uri': uri,
            'size': (await obj.file.readAsBytes()).length,
            'duration_ms': obj.duration.inMilliseconds,
            'waveform': obj.waveform,
            'mime_type': obj.mimeType,
            'md5': resp['data']['md5'].toString(),
          }),
        );
        obj.file.delete(recursive: true);
        _addMessage(message);
      },
          (Error error) => debugPrint("Voice upload error: ${error.toString()}"),
      process: false,
    );
  }
  // 消息双击事件
  void _onMessageDoubleTap(BuildContext c1, Message message, {required int index}) {
    // 触发震动反馈
    HapticFeedback.lightImpact();

    if (message is TextMessage) {
      showTextMessage(message.text);
    } else if (message is FileMessage) {
      confirmOpenFile(message.source);
    } else if (message is ImageMessage) {
      // 打开图片查看器
      galleryLogic.onImagePressed(message.id, message.source);
      iPrint('onImagePressed tapped: ${message.id} ${message.source}');
      setState(() {
        _showAppBar = false;
      });
    } else if (message is CustomMessage) {
      String txt = message.metadata?['quote_text'] ?? '';
      if (txt.isNotEmpty) showTextMessage(txt);
    }
  }

  // 新增：消息点击事件
  void _onMessageTap(
    BuildContext context,
    Message message, {
    required int index,
    required TapUpDetails details,
  }) {
    // 取消引用状态
    if (quoteMessage?.id == message.id) {
      updateQuoteMessage(null);
    }

    // 可以在这里添加其他点击逻辑
    iPrint('Message tapped: ${message.id}, type: ${message.runtimeType}');
  }

  // 新增：消息辅助点击事件（右键或长按）
  void _onMessageSecondaryTap(
    BuildContext context,
    Message message, {
    required int index,
    TapUpDetails? details,
  }) {
    // 触发震动反馈
    HapticFeedback.mediumImpact();

    // 显示快捷菜单或执行特定操作
    final isSentByMe = message.authorId == UserRepoLocal.to.currentUid;

    // 如果是自己的消息且是发送失败状态，提供重试选项
    if (isSentByMe && message.status == MessageStatus.error) {
      _showRetryMenu(context, message);
    } else {
      // 显示简化的操作菜单
      _showQuickActionMenu(context, message);
    }
  }

  // 显示重试菜单
  void _showRetryMenu(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.orange),
                title: const Text('重新发送'),
                onTap: () {
                  Navigator.pop(context);
                  _onMessageRetry(message.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除消息'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(context, message, pop: false);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // 显示快捷操作菜单
  void _showQuickActionMenu(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 根据消息类型显示不同的选项
              if (message is TextMessage) ...[
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('复制'),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.text));
                    EasyLoading.showToast('已复制');
                  },
                ),
              ],
              if (message is ImageMessage) ...[
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('保存图片'),
                  onTap: () {
                    Navigator.pop(context);
                    logic.saveFile(message.text ?? message.id, message.source);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('回复'),
                onTap: () {
                  Navigator.pop(context);
                  updateQuoteMessage(message);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
  // 更新引用消息
  Future<void> updateQuoteMessage(Message? msg) async {
    setState(() => quoteMessage = msg);
  }
  // 发送文本消息
  Future<bool> _handleSendPressed(String text) async {
    iPrint('handleSendPressed: $text, editingMessageId: $_editingMessageId');
    
    // 检查是否是编辑消息
    if (_editingMessageId != null) {
      // 发送编辑消息
      bool result = await MessageActions.to.sendEditMessage(
        _editingMessageId!, 
        widget.type, 
        text
      );
      
      // 清除编辑状态
      _editingMessageId = null;
      
      return result;
    } else if (quoteMessage == null) {
      return await _sendTextMessage(text);
    } else {
      return await _sendQuoteMessage(text);
    }
  }
  // 发送普通文本消息
  Future<bool> _sendTextMessage(String text) async {
    final textMessage = TextMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      text: text,
      metadata: _withBurnMetadata({'peer_id': widget.peerId}),
    );
    return await _addMessage(textMessage);
  }
  // 发送引用消息
  Future<bool> _sendQuoteMessage(String text) async {
    String quoteMsgAuthorName = quoteMessage!.authorId == widget.peerId
        ? widget.peerTitle
        : UserRepoLocal.to.current.nickname;
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'custom_type': 'quote',
        'peer_id': widget.peerId,
        'quote_msg': quoteMessage?.toJson(),
        'quote_msg_author_name': quoteMsgAuthorName,
        'quote_text': text,
      }),
    );
    bool res = await _addMessage(message);
    if (res) updateQuoteMessage(null);
    return res;
  }
  // 消息状态点击事件
  void _onMessageStatusTap(BuildContext ctx, Message msg) {
    // 检查是否为发送失败的消息，如果是则触发重试
    if (msg.status == MessageStatus.error && msg.authorId == UserRepoLocal.to.currentUid) {
      _onMessageRetry(msg.id);
      return;
    }
    
    // 原有逻辑：处理已发送和发送中的消息
    if (msg.status != MessageStatus.sent && msg.status != MessageStatus.sending) {
      return;
    }
    int diff =
        DateTimeHelper.millisecond() - msg.createdAt!.millisecondsSinceEpoch;
    if (diff > 1000) {
      logic.sendWsMsg(logic.getMsgFromTMsg(widget.type, conversation.uk3, msg));
      // setState(() => logic.chatController.messages = logic.chatController.messages);
    }
  }
  // 消息长按事件
  void _onMessageLongPress(
      BuildContext c1,
      Message message, {
        required int index,
        required LongPressStartDetails details,
      }) {
    iPrint('_onMessageLongPress');
    final isSentByMe = message.authorId == UserRepoLocal.to.currentUid;
    final canEdit = _canEditMessage(message);
    
    // 检查消息是否可以重试（发送失败的消息）
    final canRetry = isSentByMe && message.status == MessageStatus.error;
    
    // 使用现代化的消息操作菜单，保留所有现有功能
    showMessageActionMenu(
      context: c1,
      message: message,
      isSentByMe: isSentByMe,
      canEdit: canEdit,
      onReply: () => updateQuoteMessage(message),
      onCopy: () {
        if (message is TextMessage) {
          _copyMessageText(message);
        } else if (message is CustomMessage &&
                   message.metadata?['custom_type'] == 'quote') {
          // 引用消息的复制功能
          final quoteText = message.metadata?['quote_text'] ?? '';
          if (quoteText.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: quoteText));
            EasyLoading.showToast('copied'.tr);
          }
        }
      },
      onEdit: () => _editMessage(message),
      onDelete: () => _deleteMessageForMe(context, message, pop: false),
      onDeleteForEveryone: isSentByMe ? () => _deleteMessageForEveryone(context, message) : null,
      onForward: () => _forwardMessage(message),
      onReaction: (emoji) => _addReaction(message, emoji),
      // 新增的操作回调
      onRevoke: isSentByMe ? () => _revokeMessage(message) : null,
      onSave: _canSaveMessage(message) ? () => _saveMessageContent(message) : null,
      onCollect: _canCollectMessage(message) ? () => _collectMessage(message) : null,
      onRetry: canRetry ? () => _onMessageRetry(message.id) : null,
    );
  }
  
  /// 检查消息是否可以编辑
  bool _canEditMessage(Message message) {
    if (message.authorId != UserRepoLocal.to.currentUid) return false;
    if (message is! TextMessage) return false;
    
    // 检查时间限制（2分钟内可编辑）
    final now = DateTime.now();
    final messageTime = message.createdAt ?? now;
    final timeDiff = now.difference(messageTime);
    
    return timeDiff.inMinutes < 2;
  }
  
  /// 检查消息是否可以保存
  bool _canSaveMessage(Message message) {
    if (message is ImageMessage) {
      return true;
    } else if (message is FileMessage) {
      return true;
    } else if (message is CustomMessage) {
      final customType = message.metadata?['custom_type'] ?? '';
      return customType == 'video' || customType == 'audio';
    }
    return false;
  }
  
  /// 检查消息是否可以收藏
  bool _canCollectMessage(Message message) {
    return UserCollectLogic.getCollectKind(message) > 0;
  }
  
  /// 编辑消息
  Future<void> _editMessage(Message message) async {
    if (message is TextMessage) {
      // 显示加载状态
      EasyLoading.show(status: '正在编辑...');
      
      // 记录当前正在编辑的消息ID
      _editingMessageId = message.id;
      
      // 将消息文本填充到输入框
      chatInputKey.currentState?.setText(message.text);
      
      // 关闭加载状态
      EasyLoading.dismiss();
    }
  }
  
  /// 添加消息反应
  void _addReaction(Message message, String emoji) async {
    try {
      HapticFeedback.lightImpact();
      final res = await logic.toggleReaction(
        chatType: widget.type == 'null' ? 'C2C' : widget.type,
        peerId: widget.peerId,
        messageId: message.id,
        emoji: emoji,
      );
      if (!mounted) return;
      if (res == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res ? '已添加反应 $emoji' : '已取消反应 $emoji'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }


  // 删除消息(仅自己)
  Future<void> _deleteMessageForMe(
      BuildContext context,
      Message msg, {
        bool pop = true,
      }) async {
    final nav = Navigator.of(context);
    if (widget.type == 'C2G') {
      await _sendDeleteForMeMessage(msg);
    }
    bool res = await logic.removeMessage(conversation, msg);
    if (res) {
      await logic.chatController?.removeMessageById(msg.id);
    }
    if (pop) {
      nav.pop();
    }
  }
  // 发送删除消息请求(仅自己)
  Future<void> _sendDeleteForMeMessage(Message msg) async {
    final msg2 = {
      'id': Xid().toString(),
      'from': msg.authorId,
      'to': msg.metadata?['peer_id'],
      'type': 'S2C',
      'payload': {
        'old_msg_id': msg.id,
        'to': msg.metadata?['peer_id'],
        'msg_type': '${widget.type}_DEL_FOR_ME',
      },
      'created_at': DateTimeHelper.millisecond(),
    };
    await logic.sendMessage(msg2);
  }
  // 删除消息(所有人)
  Future<void> _deleteMessageForEveryone(
      BuildContext context,
      Message msg,
      ) async {
    final nav = Navigator.of(context);
    final msg2 = {
      'id': Xid().toString(),
      'from': msg.authorId,
      'to': msg.metadata?['peer_id'],
      'type': 'S2C',
      'payload': {
        'old_msg_id': msg.id,
        'to': msg.metadata?['peer_id'],
        'msg_type': '${widget.type}_DEL_EVERYONE',
      },
      'created_at': DateTimeHelper.millisecond(),
    };
    await logic.sendMessage(msg2);
    bool res = await logic.removeMessage(conversation, msg);
    if (res) {
      await logic.chatController?.removeMessageById(msg.id);
    }
    nav.pop();
  }
  // 复制消息文本
  void _copyMessageText(TextMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    EasyLoading.showToast('copied'.tr);
  }
  // 保存消息内容
  Future<void> _saveMessageContent(Message msg) async {
    if (msg is CustomMessage) {
      await logic.saveFile(msg.metadata!['md5'], msg.metadata!['uri']);
    } else if (msg is ImageMessage) {
      await logic.saveFile(msg.text ?? Xid().toString(), msg.source);
    } else if (msg is FileMessage) {
      await logic.saveFile(msg.name, msg.source);
    }
  }
  // 收藏消息
  Future<void> _collectMessage(Message msg) async {
    String tb = MessageRepo.getTableName(widget.type);
    final collectLogic = UserCollectLogic();
    bool res = await collectLogic.add(tb: tb, msg: msg);
    EasyLoading.showToast(
      res ? 'collected'.tr : 'operationFailedAgainLater'.tr,
    );
  }
  // 撤回消息
  Future<void> _revokeMessage(Message msg) async {
    try {
      // 显示加载状态
      EasyLoading.show(status: '正在撤回...');

      iPrint('🔍 使用新的action机制撤回消息: msgId=${msg.id}, type=${widget.type}');

      // 使用新的MessageActions撤回机制
      bool result = await MessageActions.to.sendRevokeMessage(msg.id, widget.type);
      iPrint('🔍 撤回消息发送结果: $result');

      EasyLoading.dismiss();

      if (result) {
        EasyLoading.showSuccess('撤回成功');
        iPrint('🔍 撤回请求发送完成，等待服务端确认');
      } else {
        EasyLoading.showError('撤回失败，请检查网络连接');
      }
    } catch (e, stack) {
      iPrint('撤回消息异常: $e\n$stack');
      EasyLoading.dismiss();
      EasyLoading.showError('撤回操作异常，请重试');
    }
  }
  // 转发消息
  void _forwardMessage(Message msg) {
    getx.Get.bottomSheet(
      backgroundColor: getx.Get.isDarkMode
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      // 替换 n.Padding
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: SendToPage(msg: msg),
      ),
      isScrollControlled: true,
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topRightWidget = [
      IconButton(
        onPressed: _navigateToChatSettings, 
        icon: Icon(
          Icons.more_horiz,
          color: ThemeManager.instance.getThemeColor('textPrimary'),
        ),
      ),
    ];
    return PopScope(
      canPop: !(state.composerHeight.value > 52), // 面板或键盘展开时禁止返回（约定基础高度≈52）
      onPopInvokedWithResult: (didPop, result) async {
        // 如果已经执行了返回操作，不需要处理
        if (didPop) return;
        
        // 优先收起面板/键盘，避免"返回上一页"
        if (state.composerHeight.value > 52) {
          chatInputKey.currentState?.hideAllPanel();
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true, // 启用系统键盘避让，获得更丝滑的交互体验
        appBar: _showAppBar
          ?  AppBar(
        title: Text(
          newGroupName.isEmpty ? widget.peerTitle : newGroupName,
          style: TextStyle(
            color: ThemeManager.instance.getThemeColor('textPrimary'),
            fontSize: ThemeManager.instance.getFontSize(FontSizeType.title),
          ),
        ),
        backgroundColor: ThemeManager.instance.getThemeColor('surface'),
        foregroundColor: ThemeManager.instance.getThemeColor('textPrimary'),
        actions: topRightWidget,
        automaticallyImplyLeading: true,
        // popTime: widget.options?['popTime'] ?? 1,
      )
          : null,
      body: Column( // 替换 n.Column
        children: [
          getx.Obx(
                () => state.connected.isTrue
                ? const SizedBox.shrink()
                : NetworkFailureTips(),
          ),
          Expanded(
            child: Stack( // 替换 n.Stack
              children: [
                // 优化2：Provider 注入你的 onMessageLongPress 回调
                GestureDetector(
                  onTapDown: (details) {
                    // 检查点击位置是否在输入区域外部
                    final screenHeight = MediaQuery.of(context).size.height;
                    final composerHeight = state.composerHeight.value;
                    final clickY = details.globalPosition.dy;
                    final inputAreaTop = screenHeight - composerHeight;
                    if (clickY < inputAreaTop) {
                      chatInputKey.currentState?.hideAllPanel();
                    }
                  },
                  // 只响应点击手势，不响应滑动手势，避免在输入框中滑动时误触收起面板
                  behavior: HitTestBehavior.translucent,
                  child: MultiProvider(
                    providers: [
                      Provider<OnMessageDoubleTapCallback>.value(
                        value: _onMessageDoubleTap,
                      ),
                    ],
                    // 以下回调与参数已由 Chat 通过 props 注入 Provider（见 _buildChatWidget 的 Chat(...)），无需在此重复注入：
                    // Provider<OnMessageLongPressCallback>.value(
                    //   value: _onMessageLongPress,
                    // ),
                    // Provider<OnMessageSendCallback>.value(
                    //   value: _handleSendPressed,
                    // ),
                    // Provider<UserID>.value(value: currentUser.id),
                    // Provider<OnMessageTapCallback>.value(
                    //   value: ,
                    // ),
                    // Provider<OnAttachmentTapCallback>.value(
                    //   value: _onAttachmentTap,
                    // ),
                    // 你还可以注入 OnMessageTapCallback、UserID 等 Provider
                    child: _buildChatWidget(context, theme),
                  ),
                ),
                if (galleryLogic.isImageViewVisible.isTrue)
                  IMBoyImageGallery(
                    images: galleryLogic.gallery.value,
                    pageController: galleryLogic.galleryPageController!,
                    onClosePressed: () {            
                      // 关闭图片画廊
                      galleryLogic.onCloseGalleryPressed();
                      setState(() => _showAppBar = true);
                    },
                    options: const IMBoyImageGalleryOptions(
                      maxScale: PhotoViewComputedScale.covered,
                      minScale: PhotoViewComputedScale.contained,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
  /// 导航到聊天设置页面
  Widget _buildChatInput(BuildContext context) {
    return ChatInput(
      key: chatInputKey,
      composerHeight: state.composerHeight, // 使用可动画的高度
      type: widget.type,
      peerId: widget.peerId,
      onSendPressed: _handleSendPressed,
      // sendButtonVisibilityMode: SendButtonVisibilityMode.editing,
      voiceWidget: VoiceWidget(
        startRecord: () {},
        stopRecord: _handleVoiceSelection,
        height: 46,
        margin: EdgeInsets.zero,
      ),
      extraWidget: ExtraItems(
        type: widget.type,
        handleImageSelection: _handleImageSelection,
        handleFileSelection: _handleFileSelection,
        handlePickerSelection: _handlePickerSelection,
        handleLocationSelection: _handleLocationSelection,
        handleVisitCardSelection: _handleVisitCardSelection,
        handleCollectSelection: _handleCollectSelection,
        options: {
          "to": widget.peerId,
          "title": widget.peerTitle,
          "avatar": widget.peerAvatar,
          "sign": widget.peerSign,
        },
      ),
      quoteTipsWidget: QuoteTipsWidget(
        title:
        (quoteMessage != null &&
            quoteMessage?.authorId == UserRepoLocal.to.currentUid)
            ? UserRepoLocal.to.current.nickname
            : widget.peerTitle,
        message: quoteMessage,
        close: () => updateQuoteMessage(null),
      ),
    );
  }
  /// 构建聊天主界面
  Widget _buildChatWidget(BuildContext context, ThemeData theme) {
    // 初始化聊天背景管理器
    final backgroundManager = getx.Get.put(ChatBackgroundManager());
    
    return getx.Obx(() => Chat(
      currentUserId: currentUser.id,
      backgroundColor: Colors.transparent,
      chatController: logic.chatController ?? SqliteChatController(),
      onMessageSend: _handleSendPressed,
      onMessageLongPress: _onMessageLongPress,
      onMessageTap: _onMessageTap,
      onMessageSecondaryTap: _onMessageSecondaryTap,
      // onMessageStatusTap: _onMessageStatusTap,
      decoration: backgroundManager.getCurrentBackgroundDecoration(),
      resolveUser: (id) => Future.value(switch (id) {
        'me' => currentUser,
        'recipient' => peer,
        _ => null,
      }),
      // timeFormat: DateFormat("y-MM-dd HH:mm"),
      timeFormat: RelativeDateFormat(),
      theme: ChatThemeConfig.chatTheme,
      builders: Builders(
        chatAnimatedListBuilder: (context, itemBuilder) {
          return getx.Obx(
            () {
              final bottomGap = state.composerHeight.value;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  logic.chatController?.scrollToBottom();
                } catch (_) {}
              });
              return Padding(
                padding: EdgeInsets.only(bottom: bottomGap),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (sn) {
                    if (sn is UserScrollNotification) {
                      chatInputKey.currentState?.hideAllPanel();
                    }
                    return false;
                  },
                  child: ChatAnimatedList(
                    reversed: true,
                    itemBuilder: itemBuilder,
                    onEndReached: () async {
                      if (conversation.uk3.isNotEmpty &&
                          !state.isLoading.value &&
                          state.hasMoreMessage.value) {
                        await logic.loadMoreMessages(conversation);
                      }
                    },
                    onStartReached: () async {
                      if (conversation.uk3.isNotEmpty &&
                          !state.isLoadingNewer.value &&
                          state.hasMoreMessage.value) {
                        await logic.loadNewerMessages(conversation);
                      }
                    },
                    messageGroupingTimeoutInSeconds: 60,
                  ),
                ),
              );
            },
          );
        },
        // composerBuilder: (context) => SizedBox.shrink(),
        composerBuilder: (context) => Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ChatInputHeightListener(
            composerHeight: state.composerHeight,
            animationDuration: Duration.zero,
            animationCurve: Curves.linear,
            child: _buildChatInput(context),
          ),
        ),
        // 自定义回到底部按钮（自动避让 Composer）
        scrollToBottomBuilder: (ctx, animation, onPressed) => ScrollToBottom(
          animation: animation,
          onPressed: onPressed,
          right: 16,
          bottom: 20,
          useComposerHeightForBottomOffset: true,
          mini: true,
        ),
        // 自定义空态文案
        emptyChatListBuilder: (ctx) => getx.Obx(() {
          if (state.isLoading.value && state.hasMoreMessage.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!state.hasMoreMessage.value && (logic.chatController?.messages.isEmpty ?? true)) {
            return EmptyChatList(text: '暂无消息'.tr);
          }
          return const SizedBox.shrink();
        }),
        customMessageBuilder:
            (
            context,
            message,
            index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) {
          return CustomMessageBuilder(type: widget.type, message: message);
        },
        imageMessageBuilder: (
          context,
          message,
          index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) {
          final width = MediaQuery.of(context).size.width.toInt();
          return IMBoyImageMessageBuilder(
            message: message,
            messageWidth: width,
            user: isSentByMe ? currentUser : peer,
          );
        },
        systemMessageBuilder:
            (
            context,
            message,
            index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) {
          return FlyerChatSystemMessage(message: message, index: index);
        },
        textMessageBuilder:
            (
            context,
            message,
            index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) {
          return FlyerChatTextMessage(
            message: message,
            index: index,
            showStatus: false,
            showTime: true,
          );
        },
        fileMessageBuilder:
            (
            context,
            message,
            index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) {
          return FlyerChatFileMessage(
            message: message,
            index: index,
            showStatus: false,
            showTime: true,
          );
        },
        chatMessageBuilder:
            (
            context,
            message,
            index,
            animation,
            child, {
          bool? isRemoved,
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) {
          final isSystemMessage = message.authorId == 'system';
          final isFirstInGroup = groupStatus?.isFirst ?? true;
          final isLastInGroup = groupStatus?.isLast ?? true;
          final shouldShowAvatar =
              !isSystemMessage && isLastInGroup && isRemoved != true;
          final isCurrentUser = message.authorId == currentUser.id;
          final shouldShowUsername =
              !isSystemMessage && isFirstInGroup && isRemoved != true;

          Widget? statusIcon;
          switch (message.status) {
            case MessageStatus.sending:
              statusIcon = Icon(
                Icons.access_time,
                size: 16,
                color: ThemeManager.instance.getThemeColor('textSecondary'),
              );
              break;
            case MessageStatus.sent:
            case MessageStatus.delivered:
              statusIcon = Icon(
                Icons.done_all,
                size: 16,
                color: ThemeManager.instance.getThemeColor('primary'),
              );
              break;
            case MessageStatus.seen:
              statusIcon = Icon(
                Icons.done_all,
                size: 16,
                color: ThemeManager.instance.getChatColor('sendMessageBg'),
              );
              break;
            case MessageStatus.error:
              statusIcon = Icon(
                Icons.error_outline,
                size: 16,
                color: ThemeManager.instance.getThemeColor('error'),
              );
              break;
            default:
              statusIcon = null;
          }
          Widget? avatar;
          if (shouldShowAvatar) {
            avatar = Padding(
              padding: EdgeInsets.only(
                left: isCurrentUser ? 8 : 0,
                right: isCurrentUser ? 0 : 8,
              ),
              child: Avatar(userId: message.authorId),
            );
          } else if (!isSystemMessage) {
            avatar = const SizedBox(width: 40);
          }

          // 在消息末尾添加状态图标
          final burnBadge = _isBurnMessage(message)
              ? _BurnBadge(
                  isSentByMe: isCurrentUser,
                  burnAfterMs: _burnAfterMsFromMessage(message),
                  burnReadAtMs: (message.metadata?['burn_read_at'] is int)
                      ? message.metadata!['burn_read_at'] as int
                      : int.tryParse('${message.metadata?['burn_read_at'] ?? 0}') ?? 0,
                )
              : null;

          Widget messageBody = burnBadge == null
              ? child
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    child,
                    const SizedBox(height: 2),
                    Padding(
                      padding: EdgeInsets.only(
                        right: isCurrentUser ? 2 : 0,
                        left: isCurrentUser ? 0 : 2,
                      ),
                      child: burnBadge,
                    ),
                  ],
                );

          if (isCurrentUser && statusIcon != null) {
            statusIcon = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onMessageStatusTap(context, message),
              child: statusIcon,
            );
            child = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: messageBody),
                const SizedBox(width: 4),
                statusIcon,
              ],
            );
          } else {
            child = messageBody;
          }
          final chatMsg = ChatMessage(
            message: message,
            index: index,
            animation: animation,
            isRemoved: isRemoved,
            groupStatus: groupStatus,
            topWidget: shouldShowUsername
                ? Padding(
              padding: EdgeInsets.only(
                bottom: 4,
                left: isCurrentUser ? 0 : 48,
                right: isCurrentUser ? 48 : 0,
              ),
              child: Username(userId: message.authorId),
            )
                : null,
            leadingWidget: !isCurrentUser
                ? avatar
                : isSystemMessage
                ? null
                : const SizedBox(width: 40),
            trailingWidget: isCurrentUser
                ? avatar
                : isSystemMessage
                ? null
                : const SizedBox(width: 40),
            receivedMessageScaleAnimationAlignment:
            (message is SystemMessage)
                ? Alignment.center
                : Alignment.centerLeft,
            receivedMessageAlignment: (message is SystemMessage)
                ? AlignmentDirectional.center
                : AlignmentDirectional.centerStart,
            horizontalPadding: (message is SystemMessage) ? 0 : 8,
            child: child,
          );
          // 可视阈值已读（受隐私设置控制）
          final s = UserRepoLocal.to.setting;
          if (!s.enableVisibilityRead) {
            return chatMsg;
          }
          final double fractionThreshold = (() {
            final v = s.visibilityReadFraction;
            if (v.isNaN) return 0.6;
            if (v < 0.1) return 0.1;
            if (v > 1.0) return 1.0;
            return v;
          })();
          final int delayMs = s.visibilityReadDelayMs <= 0 ? 400 : s.visibilityReadDelayMs;
          // 当来自对方的消息可视比例达到阈值并持续 delayMs 后推进水位
          return VisibilityDetector(
            key: Key('msg_vis_${message.id}'),
            onVisibilityChanged: (info) {
              final fraction = info.visibleFraction;
              // 标记当前消息是否可见（用于后续检查）
              if (fraction > 0.1) {
                performanceMonitor.markMessageVisible(message.id);
              } else {
                performanceMonitor.markMessageInvisible(message.id);
              }

              // 仅处理来自对方的消息
              final isIncoming = message.authorId != currentUser.id;
              if (!isIncoming) return;
              // 已处理过的消息无需重复
              if (_readCommitted.contains(message.id)) return;

              // 达到可视阈值，启动延时判定
              if (fraction >= fractionThreshold) {
                _readDelayTimers[message.id]?.cancel();
                _readDelayTimers[message.id] = Timer(Duration(milliseconds: delayMs), () async {
                  if (!mounted) return;
                  // 仍处于可见状态才推进水位
                  if (performanceMonitor.isMessageVisible(message.id)) {
                    try {
                      final ok = await logic.markAsRead(
                        widget.type == 'null' ? 'C2C' : widget.type,
                        widget.peerId,
                        [message.id],
                        syncToServer: true,
                      );
                      if (ok) {
                        _readCommitted.add(message.id);
                        if (_isBurnMessage(message) && (message.metadata?['burn_read_at'] ?? 0) == 0) {
                          logic.markBurnReadAt(
                            conversation,
                            message.id,
                            readAtMs: DateTimeHelper.millisecond(),
                          );
                        }
                      }
                    } catch (_) {}
                  }
                });
              } else {
                // 可见比例下降，取消未完成的判定
                _readDelayTimers[message.id]?.cancel();
                _readDelayTimers.remove(message.id);
              }
            },
            child: chatMsg,
          );
        },
      ),
    ));
  }
  // 导航到聊天设置
  void _navigateToChatSettings() {
    final options = {
      "peer_id": widget.peerId,
      "peerAvatar": widget.peerAvatar,
      "peerTitle": widget.peerTitle,
      "peerSign": widget.peerSign,
      "conversationUk3": conversation.uk3,
    };
    getx.Get.to(
          () => widget.type == 'C2G'
          ? GroupDetailPage(
        groupId: widget.peerId,
        memberCount: state.memberCount.value,
        title: widget.peerTitle,
        options: options,
        callBack: (v) {},
      )
          : ChatSettingPage(widget.peerId, type: widget.type, options: options),
      transition: getx.Transition.rightToLeft,
      popGesture: true,
    )?.then((value) => _handleChatSettingsResult(value));
  }
  // 处理聊天设置返回结果
  Future<void> _handleChatSettingsResult(dynamic value) async {
    if (value == false) {
      state.nextAutoId.value = 0;
      await logic.loadMoreMessages(conversation, isInitial: true);
    }
    if (value == true) {
      await _reloadConversationSettings();
    }
    if (value is Map<String, dynamic>) {
      int num = value['memberCount'] ?? 0;
      if (num > 0) {
        state.memberCount.value = num;
        newGroupName = await logic.groupTitle(
          widget.peerId,
          widget.peerTitle,
          state.memberCount.value,
        );
        if (mounted) setState(() {});
      }
    }
  }
}

class _BurnBadge extends StatelessWidget {
  final bool isSentByMe;
  final int burnAfterMs;
  final int burnReadAtMs;

  const _BurnBadge({
    required this.isSentByMe,
    required this.burnAfterMs,
    required this.burnReadAtMs,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    final bg = Theme.of(context).colorScheme.surface;

    if (burnReadAtMs <= 0 || burnAfterMs <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              '阅后',
              style: TextStyle(
                fontSize: 10,
                color: color,
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<int>(
      stream: ChatPageState._burnTicker,
      builder: (context, snapshot) {
        final now = DateTimeHelper.millisecond();
        final expireAt = burnReadAtMs + burnAfterMs;
        final remainMs = expireAt - now;
        final remainSec = (remainMs / 1000).ceil();
        final text = remainSec <= 0 ? '0s' : '${remainSec}s';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, size: 12, color: color),
              const SizedBox(width: 2),
              Text(
                text,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  height: 1.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
