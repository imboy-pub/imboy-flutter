import 'dart:async';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/helper/permission.dart';
import 'package:imboy/page/chat/widget/chat_input_height_listener.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide CustomMessageBuilder;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flyer_chat_file_message/flyer_chat_file_message.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_system_message/flyer_chat_system_message.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:get/get.dart' as getx;
import 'package:image/image.dart' as img;
import 'package:imboy/component/ui/line.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:mime/mime.dart';
import 'package:photo_view/photo_view.dart';
import 'package:popup_menu/popup_menu.dart' as popupmenu;
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:xid/xid.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/chat_extend_model.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/picker_method.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/image_gallery/image_gallery_logic.dart';
import 'package:imboy/component/chat/message.dart';
import 'package:imboy/component/ui/common_bar.dart';
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
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import '../widget/chat_input.dart';
import '../widget/extra_item.dart';
import '../widget/quote_tips.dart';
import '../widget/select_friend.dart';
import 'chat_logic.dart';
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
  final galleryLogic = getx.Get.put(ImageGalleryLogic());
  final logic = getx.Get.find<ChatLogic>();
  final state = getx.Get.find<ChatLogic>().state;
  final conversationLogic = getx.Get.find<ConversationLogic>();
  bool _showAppBar = true; // 控制顶部导航栏显示/隐藏
  String newGroupName = ""; // 新群组名称
  int get maxAssetsCount => 9; // 最大可选资源数量
  List<AssetEntity> assets = <AssetEntity>[]; // 选择的资源列表
  Message? quoteMessage; // 引用的消息
  final GlobalKey<ChatInputState> chatInputKey = GlobalKey<ChatInputState>();
  // 消息ID集合，用于防止 eventBus 重复渲染消息
  final Set<String> msgIds = {};
  final User currentUser = User(
    id: UserRepoLocal.to.currentUid,
    name: UserRepoLocal.to.current.nickname,
    imageSource: UserRepoLocal.to.current.avatar,
  );
  late ConversationModel conversation; // 当前会话
  late User peer; // 对方用户信息
  // StreamSubscription<ConnectivityResult>? _connectivitySubscription; // 网络状态监听
  // 页面初始化
  @override
  void initState() {
    super.initState();
    msgIds.clear();
    state.nextAutoId.value = 0;
    state.hasMoreMessage.value = true;
    state.isLoading.value = false;
    _initChat();
    _initData();
  }
  /// 初始化聊天相关数据
  Future<void> _initChat() async {
    logic.initChatController(widget.type);
    // 创建或获取会话
    await _setupConversation();
    await logic.loadMoreMessages(conversation, isInitial: true);
    _setupEventListeners();
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
        // state.connected.value = '(${'tip_connect_desc'.tr})';
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
    // 一些异步操作事件的监听
    state.ssMsgExt = eventBus.on<ChatExtendModel>().listen((
        ChatExtendModel obj,
        ) async {
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
          obj.payload['conversation'].id == conversation.id) {
        logic.chatController.removeMessageById(obj.payload['msg'].id);
      }
    });
    // 接收到新的消息订阅 for c2c c2g
    state.ssMsg = eventBus.on<Message>().listen((Message msg) async {
      final String conversationUk3 = msg.metadata?['conversation_uk3'] ?? '';
      if (conversationUk3 != conversation.uk3 || msgIds.contains(msg.id)) {
        return;
      }
      msgIds.add(msg.id);
      final i = logic.chatController.messages.indexWhere((e) => e.id == msg.id);
      if (i == -1) {
        String tb = MessageRepo.getTableName(widget.type);
        MessageModel? m = await MessageService.to.changeStatus(
          tb,
          msg.id,
          IMBoyMessageStatus.seen,
        );
        conversationLogic.decreaseConversationRemind(conversation, 1);
        if (m != null) {
          msg = await m.toTypeMessage();
          logic.chatController.insertMessage(
            msg,
            index: logic.chatController.messages.length,
          );
          _markMessagesAsRead([msg]);
          if (msg is ImageMessage) {
            galleryLogic.pushToLast(msg.id, msg.source);
          }
        }
      }
      // 为节省内存，5秒后从 msgIds 移出 msg.id
      Future.delayed(const Duration(seconds: 5), () => msgIds.remove(msg.id));
    });
    // 消息状态更新订阅, 这里无需用锁 for c2g
    state.ssMsgState = eventBus.on<List<Message>>().listen((e) {
      if (e.isEmpty) return;
      Message msg = e.first;
      final i = logic.chatController.messages.indexWhere((e) => e.id == msg.id);
      if (i > -1 && mounted) {
        logic.chatController.updateMessage(logic.chatController.messages[i], msg);
      }
    });
  }
  @override
  void dispose() {
    state.ssMsgExt?.cancel();
    state.ssMsg?.cancel();
    state.ssMsgState?.cancel();
    msgIds.clear();
    logic.chatController.setMessages([]);
    logic.chatController.dispose();
    getx.Get.delete<ImageGalleryLogic>();
    super.dispose();
  }
  // 标记消息为已读
  Future<void> _markMessagesAsRead(List<Message> items) async {
    final unreadMsgIds = items
        .where(
          (msg) =>
      msg.authorId != UserRepoLocal.to.currentUid &&
          msg.status != MessageStatus.seen,
    )
        .map((msg) => msg.id)
        .toList();
    if (unreadMsgIds.isEmpty) {
      conversationLogic.recalculateConversationRemind(conversation);
    } else {
      await logic.markAsRead(widget.type, widget.peerId, unreadMsgIds);
    }
  }
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
      await logic.chatController.insertMessage(
        message,
        index: logic.chatController.messages.length,
      );
      return true;
    } catch (e, stack) {
      debugPrint("_addMessage error: $e : $stack");
      return false;
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
          metadata: {
            'peer_id': widget.peerId,
            'md5': resp['data']['md5'].toString(),
          },
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
      metadata: {
        'peer_id': widget.peerId,
        'md5': resp['data']['md5'].toString(),
      },
    );
    _addMessage(message);
  }
  // 处理视频上传
  Future<void> _handleVideoUpload(Map<String, dynamic> resp) async {
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      metadata: {
        'custom_type': 'video',
        'peer_id': widget.peerId,
        'thumb': (resp['thumb'] as EntityImage).toJson(),
        'video': (resp['video'] as EntityVideo).toJson(),
      },
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
    final msg = await MessageModel.fromJson(data).toTypeMessage();
    final res = await _addMessage(msg);
    if (res) {
      getx.Get.find<UserCollectLogic>().change(collect.kindId);
      EasyLoading.showSuccess('tip_success'.tr);
    } else {
      EasyLoading.showError('tip_failed'.tr);
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
      metadata: {
        'custom_type': 'visit_card',
        'peer_id': widget.peerId,
        'uid': contact.peerId,
        'title': contact.title,
        'avatar': contact.avatar,
      },
    );
    final res = await _addMessage(message);
    if (res) {
      EasyLoading.showSuccess('tip_success'.tr);
    } else {
      EasyLoading.showError('tip_failed'.tr);
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
          metadata: {
            'custom_type': 'location',
            'peer_id': widget.peerId,
            'title': title,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
            'thumb': imgUrl,
            'size': resp['data']['size'],
            'md5': resp['data']['md5'].toString(),
          },
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
      metadata: {
        'peer_id': widget.peerId,
        'md5': resp['data']['md5'].toString(),
      },
    );
    _addMessage(message);
  }
  // 处理选择的视频上传
  Future<void> _handleSelectedVideoUpload(Map<String, dynamic> resp) async {
    final message = CustomMessage(
      authorId: currentUser.id,
      createdAt: DateTimeHelper.now(),
      id: Xid().toString(),
      metadata: {
        'custom_type': 'video',
        'peer_id': widget.peerId,
        'thumb': (resp['thumb'] as EntityImage).toJson(),
        'video': (resp['video'] as EntityVideo).toJson(),
      },
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
          metadata: {
            'custom_type': 'audio',
            'peer_id': widget.peerId,
            'uri': uri,
            'size': (await obj.file.readAsBytes()).length,
            'duration_ms': obj.duration.inMilliseconds,
            'waveform': obj.waveform,
            'mime_type': obj.mimeType,
            'md5': resp['data']['md5'].toString(),
          },
        );
        obj.file.delete(recursive: true);
        _addMessage(message);
      },
          (Error error) => debugPrint("Voice upload error: ${error.toString()}"),
      process: false,
    );
  }
  // 消息双击事件
  void _onMessageDoubleTap(BuildContext c1, Message message, {int? index}) {
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
  // 更新引用消息
  Future<void> updateQuoteMessage(Message? msg) async {
    setState(() => quoteMessage = msg);
  }
  // 发送文本消息
  Future<bool> _handleSendPressed(String text) async {
    iPrint('handleSendPressed: $text');
    if (quoteMessage == null) {
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
      metadata: {'peer_id': widget.peerId},
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
      metadata: {
        'custom_type': 'quote',
        'peer_id': widget.peerId,
        'quote_msg': quoteMessage?.toJson(),
        'quote_msg_author_name': quoteMsgAuthorName,
        'quote_text': text,
      },
    );
    bool res = await _addMessage(message);
    if (res) updateQuoteMessage(null);
    return res;
  }
  // 消息状态点击事件
  void _onMessageStatusTap(BuildContext ctx, Message msg) {
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
        int? index,
        LongPressStartDetails? details,
      }) {
    iPrint('_onMessageLongPress');
    // BuildContext c1 = getx.Get.context!;
    final menu = popupmenu.PopupMenu(
      context: c1,
      items: logic.getPopupMenuItems(message),
      onClickMenu: onClickMenu,
    );
    final renderBox = c1.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    double l = offset.dx / 2 - renderBox.size.width / 2 + 75.0;
    double r = renderBox.size.width / 2 - 75.0;
    double dx = message.authorId == UserRepoLocal.to.currentUid ? r : l;
    double dy = offset.dy.clamp(0, getx.Get.height);
    double h = renderBox.size.height > getx.Get.height
        ? getx.Get.height
        : renderBox.size.height;
    menu.show(rect: Rect.fromLTWH(dx, dy, renderBox.size.width, h));
  }
  // 菜单项点击事件
  void onClickMenu(popupmenu.MenuItemProvider item) async {
    final it = item as popupmenu.MenuItem;
    final msg = it.userInfo['msg'] as Message;
    final itemId = it.userInfo['id'] ?? '';
    switch (itemId) {
      case "delete":
        if (msg.authorId == UserRepoLocal.to.currentUid) {
          _showDeleteMessageDialog(msg);
        } else {
          // 仅删除自己看到的消息
          _deleteMessageForMe(context, msg, pop: false);
        }
        break;
      case "copy":
        _copyMessageText(msg as TextMessage);
        break;
      case "save":
        _saveMessageContent(msg);
        break;
      case "collect":
        _collectMessage(msg);
        break;
      case "revoke":
        _revokeMessage(msg);
        break;
      case "quote":
        updateQuoteMessage(msg);
        break;
      case "transpond":
        _forwardMessage(msg);
        break;
    }
  }
  // 显示删除消息对话框
  void _showDeleteMessageDialog(Message msg) {
    // 替换 n.showDialog
    showDialog(
      context: getx.Get.context!,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero, // 替换 EdgeInsets.all(0)
        backgroundColor: const Color(0xff232323),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'delete_for_me'.tr,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => _deleteMessageForMe(context, msg),
            ),
            // 替换 n.Padding
            if (msg.authorId == UserRepoLocal.to.currentUid)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: HorizontalLine(height: getx.Get.isDarkMode ? 0.5 : 1.0),
              ),
            if (msg.authorId == UserRepoLocal.to.currentUid)
              ListTile(
                title: Text(
                  'delete_for_everyone'.tr,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => _deleteMessageForEveryone(context, msg),
              ),
          ],
        ),
      ),
      barrierDismissible: true,
    );
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
      await logic.chatController.removeMessageById(msg.id);
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
      await logic.chatController.removeMessageById(msg.id);
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
    bool res = await UserCollectLogic().add(tb: tb, msg: msg);
    EasyLoading.showToast(
      res ? 'collected'.tr : 'operation_failed_again_later'.tr,
    );
  }
  // 撤回消息
  Future<void> _revokeMessage(Message msg) async {
    final msg2 = {
      'ts': DateTimeHelper.millisecond(),
      'id': msg.id,
      'type': '${widget.type.toUpperCase()}_REVOKE',
      'from': msg.authorId,
      'to': msg.metadata?['peer_id'],
    };
    await logic.sendMessage(msg2);
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
      InkWell(
        onTap: _navigateToChatSettings,
        // 替换 n.Padding
        child: Padding(
          padding: const EdgeInsets.all(10), // left: 10, right: 10, bottom: 10, top: 10
          child: Icon(
            Icons.more_horiz,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    ];
    return Scaffold(
      appBar: _showAppBar
          ? NavAppBar(
        title: newGroupName.isEmpty ? widget.peerTitle : newGroupName,
        rightDMActions: topRightWidget,
        automaticallyImplyLeading: true,
        popTime: widget.options?['popTime'] ?? 1,
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
                  onTap: () => chatInputKey.currentState?.hideAllPanel(),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (sn) {
                      if (sn is UserScrollNotification) {
                        chatInputKey.currentState?.hideAllPanel();
                      }
                      return false;
                    },
                    child: MultiProvider(
                      providers: [
                        Provider<OnMessageLongPressCallback>.value(
                          value: _onMessageLongPress,
                        ),
                        Provider<OnMessageDoubleTapCallback>.value(
                          value: _onMessageDoubleTap,
                        ),
                        // Provider<OnMessageTapCallback>.value(
                        //   value: ,
                        // ),
                        Provider<OnMessageSendCallback>.value(
                          value: _handleSendPressed,
                        ),
                        // Provider<OnAttachmentTapCallback>.value(
                        //   value: _onAttachmentTap,
                        // ),
                        // 你还可以注入 OnMessageTapCallback、UserID 等 Provider
                        Provider<UserID>.value(value: currentUser.id),
                      ],
                      child: _buildChatWidget(context, theme), // 保持原有 _buildChatWidget 不变
                    ),
                  ),
                ),
                // _buildChatInput(),
                if (galleryLogic.isImageViewVisible.isTrue)
                  IMBoyImageGallery(
                    images: galleryLogic.gallery.value,
                    pageController: galleryLogic.galleryPageController!,
                    onClosePressed: _closeImageGallery,
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
    );
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
        height: state.composerHeight.value,
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
    return Chat(
      currentUserId: currentUser.id,
      backgroundColor: Colors.transparent,
      chatController: logic.chatController,
      onMessageSend: _handleSendPressed,
      onMessageLongPress: _onMessageLongPress,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? ChatColors.dark().surface
            : ChatColors.light().surface,
        image: DecorationImage(
          image: AssetImage('assets/images/pattern.png'),
          repeat: ImageRepeat.repeat,
          colorFilter: ColorFilter.mode(
            theme.brightness == Brightness.dark
                ? ChatColors.dark().surfaceContainerLow
                : ChatColors.light().surfaceContainerLow,
            BlendMode.srcIn,
          ),
        ),
      ),
      resolveUser: (id) => Future.value(switch (id) {
        'me' => currentUser,
        'recipient' => peer,
        _ => null,
      }),
      timeFormat: DateFormat("y-MM-dd HH:mm"),
      theme: ChatTheme.fromThemeData(theme),
      builders: Builders(
        chatAnimatedListBuilder: (context, itemBuilder) {
          return getx.Obx(
                () => AnimatedPadding(
              // 用动画包裹消息列表
              padding: EdgeInsets.only(bottom: state.composerHeight.value),
              duration: const Duration(milliseconds: 0),
              curve: Curves.easeInOut,
              child: ChatAnimatedList(
                scrollController: logic.scrollController,
                bottomPadding: state.composerHeight.value, // 让消息列表底部有输入区空间
                scrollToEndAnimationDuration: Duration(
                  milliseconds: 0,
                ), // <--- 动画时长
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                itemBuilder: itemBuilder,
                onEndReached: () => logic.loadMoreMessages(conversation),
                insertAnimationDurationResolver: (message) {
                  if (message is SystemMessage) return Duration.zero;
                  return null;
                },
              ),
            ),
          );
        },
        // composerBuilder: (context) => SizedBox.shrink(),
        composerBuilder: (context) => Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ChatInputHeightListener(
            composerHeight: state.composerHeight,
            child: _buildChatInput(context),
          ),
        ),
        customMessageBuilder:
            (
            context,
            message,
            index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) => CustomMessageBuilder(type: widget.type, message: message),
        imageMessageBuilder:
            (
            context,
            message,
            index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) => FlyerChatImageMessage(
          message: message,
          index: index,
          showStatus: true,
          showTime: true,
          // timeStyle: const TextStyle(
          //   fontSize: 12,
          //   color: Colors.green,
          // ),
        ),
        systemMessageBuilder:
            (
            context,
            message,
            index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) => FlyerChatSystemMessage(message: message, index: index),
        textMessageBuilder:
            (
            context,
            message,
            index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) => FlyerChatTextMessage(
          message: message,
          index: index,
          showStatus: true,
          showTime: true,
        ),
        fileMessageBuilder:
            (
            context,
            message,
            index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) => FlyerChatFileMessage(
          message: message,
          index: index,
          showStatus: true,
          showTime: true,
        ),
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
          return ChatMessage(
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
        },
      ),
    );
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
  // 关闭图片画廊
  void _closeImageGallery() {
    galleryLogic.onCloseGalleryPressed();
    setState(() => _showAppBar = true);
  }
}