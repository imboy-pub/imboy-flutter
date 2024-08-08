import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart' as getx;
import 'package:image/image.dart' as img;
import 'package:imboy/component/ui/line.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:mime/mime.dart';
import 'package:niku/namespace.dart' as n;
import 'package:open_file/open_file.dart';
import 'package:photo_view/photo_view.dart';
import 'package:popup_menu/popup_menu.dart' as popupmenu;
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:xid/xid.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/chat_extend_model.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/picker_method.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/image_gallery/image_gallery_logic.dart';
import 'package:imboy/component/message/message.dart';
import 'package:imboy/component/message/message_image_builder.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/voice_record/voice_widget.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_view.dart';
import 'package:imboy/page/chat/send_to/send_to_view.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/group/group_detail/group_detail_view.dart';
import 'package:imboy/page/mine/user_collect/user_collect_logic.dart';
import 'package:imboy/page/mine/user_collect/user_collect_view.dart';
import 'package:imboy/service/assets.dart';
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

// ignore: must_be_immutable
class ChatPage extends StatefulWidget {
  final String type; // [C2C | C2G | C2S]
  final String peerId; // 用户ID | GroupId | SID
  final String peerAvatar;
  final String peerTitle;
  final String peerSign;

  // final String computeTitle;
  // final int popTime;
  final Map<String, dynamic>? options;

  /*
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
    this.options,
  });

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  // 网络状态描述
  getx.RxBool connected = true.obs;

  final galleryLogic = getx.Get.put(ImageGalleryLogic());
  final ChatLogic logic = getx.Get.find();
  final ConversationLogic conversationLogic = getx.Get.find();

  bool _showAppBar = true;

  String newGroupName = "";

  final int _size = 16;

  int get maxAssetsCount => 9;

  List<AssetEntity> assets = <AssetEntity>[];

  types.Message? quoteMessage;

  // 消息重复投递导致的聊天列表消息重复显示问题
  // 只需要再 ssMsg listen 的时候 add(msg.id)就可以了
  Set<String> msgIds = {};
  // ignore: prefer_typing_uninitialized_variables
  late var currentUser;
  late ConversationModel conversation;

  late StreamSubscription ssMsgExt;
  late StreamSubscription ssMsg;
  late StreamSubscription ssMsgState;
  @override
  void initState() {
    // 初始化的时候置空数据，放在该位置（initData之前），不会出现闪屏
    logic.initState();

    //监听Widget是否绘制完毕
    super.initState();

    initData();
    // 异步检查是否有离线数据 TODO leeyi 2023-01-29 16:43:47
  }

  /// 初始化一些数据
  Future<void> initData() async {
    msgIds = {};
    currentUser = types.User(
      id: UserRepoLocal.to.currentUid,
      firstName: UserRepoLocal.to.current.nickname,
      imageUrl: UserRepoLocal.to.current.avatar,
    );
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      connected = false.obs;
    } else {
      connected = true.obs;
    }
    bool showConversation = widget.options?['showConversation'] ?? true;
    conversation = await conversationLogic.createConversation(
      type: widget.type,
      peerId: widget.peerId,
      avatar: widget.peerAvatar,
      title: widget.peerTitle,
      subtitle: "",
      lastTime: showConversation ? DateTimeHelper.utc() : 0,
    );
    if (showConversation) {
      eventBus.fire(conversation);
    }
    logic.state.nextAutoId = 0;

    if (widget.type == 'C2G') {
      logic.state.memberCount = widget.options?['memberCount'] ?? 0;
      iPrint("logic.state.selects chat_vew ${widget.options.toString()}");
      newGroupName = await logic.groupTitle(
        widget.peerId,
        widget.peerTitle,
        logic.state.memberCount,
      );
    }

    if (availableMaps.isEmpty) {
      try {
        availableMaps = await MapLauncher.installedMaps;
      } catch (e) {
        //
      }
    }

    // 获取本地聊天记录
    unawaited(_handleEndReached());

    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> r) {
      if (r.contains(ConnectivityResult.none)) {
        connected = false.obs;
      } else {
        connected = true.obs;
      }
    });

    // 一些异步操作事件的监听
    ssMsgExt = eventBus.on<ChatExtendModel>().listen((ChatExtendModel obj) async {
      iPrint("face_to_face_confirm ${obj.toString()}; $mounted");
      // 监听新成员加入
      if (obj.type == 'join_group' &&
          obj.payload['groupId'] == widget.peerId &&
          (obj.payload['isFirst'] ?? false)) {
        logic.state.memberCount += 1;
        newGroupName = await logic.groupTitle(
          widget.peerId,
          widget.peerTitle,
          logic.state.memberCount,
        );
        if (mounted) {
          setState(() {});
        }
      } else if (obj.type == 'delete_msg') {
        //   removeMessage
        if (obj.payload['conversation'].id == conversation.id) {
          final i = logic.state.messages
              .indexWhere((element) => element.id == obj.payload['msg'].id);
          if (mounted) {
            setState(() {
              logic.state.messages.removeAt(i);
            });
          }
        }
      }
    });

    // 接收到新的消息订阅 for c2c
    ssMsg = eventBus.on<types.Message>().listen((types.Message msg) async {
      iPrint("chat_view/listen one ${msg.id}; ${DateTime.now()}");
      final String conversationUk3 = msg.metadata?['conversation_uk3'] ?? '';
      iPrint("chat_view/listen one $conversationUk3");
      iPrint("chat_view/listen one ${conversationUk3 != conversation.uk3}");
      if (conversationUk3 != conversation.uk3) {
        return;
      }

      // 消息重复投递导致的聊天列表消息重复显示问题
      if (msgIds.contains(msg.id)) {
        return;
      }
      msgIds.add(msg.id);

      final i = logic.state.messages.indexWhere((e) => e.id == msg.id);
      iPrint("changeMessageState 4 ${msg.id}; i $i; mounted $mounted");
      if (i == -1) {
        iPrint("decreaseConversationRemind ${conversation.uk3}");
        String tb = MessageRepo.getTableName(widget.type);
        MessageModel? m = await MessageService.to.changeStatus(
          tb,
          msg.id,
          IMBoyMessageStatus.seen,
        );
        conversationLogic.decreaseConversationRemind(
          conversation,
          1,
        );
        if (m != null) {
          msg = await m.toTypeMessage();
          logic.state.messages.insert(0, msg);

          if (msg is types.ImageMessage) {
            galleryLogic.pushToLast(msg.id, msg.uri);
          }
          if (mounted) {
            setState(() {});
          }
        }
      }
      // 为节省内存，5秒后从 msgIds 移出 msg.id
      Future.delayed(const Duration(seconds: 5), () {
        msgIds.remove(msg.id);
      });
    });
    // debugPrint("> rtc msg S_RECEIVED listen list");

    // 消息状态更新订阅, 这里无需用锁 for c2g
    ssMsgState = eventBus.on<List<types.Message>>().listen((e) async {
      types.Message msg = e.first;

      final i = logic.state.messages.indexWhere((e) => e.id == msg.id);
      debugPrint("chat_view/listen list $i ${msg.toJson().toString()}");
      if (i > -1) {
        logic.state.messages.setRange(i, i + 1, e);
        if (mounted) {
          setState(() {
            logic.state.messages;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    getx.Get.delete<ImageGalleryLogic>();
    ssMsgExt.cancel();
    ssMsg.cancel();
    ssMsgState.cancel();
    msgIds = {};
    super.dispose();
  }

  /// 用于分页(无限滚动)。当用户滚动时调用
  /// 到列表的最后(减去[onEndReachedThreshold])。
  Future<void> _handleEndReached() async {
    // 初始化 当前会话新增消息
    List<types.Message>? items = await logic.pageMessages(
      conversation,
      _size,
    );
    if (items != null && items.isNotEmpty) {
      for (var msg in items) {
        if (msg is types.ImageMessage) {
          galleryLogic.pushToGallery(msg.id, msg.uri);
        }
      }
      // 消除消息提醒
      countConversationRemind(items);
      if (mounted) {
        setState(() {
          logic.state.messages = [
            ...logic.state.messages,
            ...items,
          ];
        });
      }
    } else if (logic.state.nextAutoId == 0 && mounted) {
      setState(() {
        logic.state.messages = [];
      });
    }
    // debugPrint("ChatSettingPage then 3 ${logic.state.messages.length}");
  }

  /// 消除消息提醒
  Future<void> countConversationRemind(List<types.Message> items) async {
    List<String> msgIds = [];
    for (var msg in items) {
      //enum Status { delivered, error, seen, sending, sent }
      if (msg.author.id != UserRepoLocal.to.currentUid &&
          msg.status != types.Status.seen) {
        msgIds.add(msg.id);
      }
    } // end for items
    iPrint(
        "countConversationRemind msgIds.len ${msgIds.length} type ${widget.type}");
    if (msgIds.isEmpty) {
      // 重新计算会话消息提醒数量
      conversationLogic.recalculateConversationRemind(conversation);
    } else {
      await logic.markAsRead(
        widget.type,
        widget.peerId,
        msgIds,
      );
    }
  }

  Future<bool> _addMessage(types.Message message) async {
    // 先显示在聊天UI里面
    // 异步发送WS消息
    // 异步存储sqlite消息(未发送成功）
    //   发送成功后，更新conversation、更新消息状态
    //   发送失败后，放入异步队列，重新发送
    String type = widget.type == 'null' ? 'C2C' : widget.type;
    try {
      await logic.addMessage(
        UserRepoLocal.to.currentUid,
        widget.peerId,
        widget.peerAvatar,
        widget.peerTitle,
        type,
        message,
      );
      setState(() {
        logic.state.messages.insert(0, message);
      });
      return true;
    } catch (e) {
      debugPrint("_addMessage $e");
    }
    return false;
    // _msgService.update();
  }

  /// 选择文件
  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      await AttachmentProvider.uploadFile("files", result.files.single, (
        Map<String, dynamic> resp,
        String uri,
      ) async {
        final message = types.FileMessage(
            id: Xid().toString(),
            author: currentUser,
            createdAt: DateTimeHelper.currentTimeMillis(),
            mimeType: lookupMimeType(result.files.single.path!),
            name: result.files.single.name,
            size: result.files.single.size,
            uri: uri,
            remoteId: widget.peerId,
            status: types.Status.sending,
            metadata: {
              'md5': resp['data']['md5'].toString(),
            });
        // 上传现有的附件，是不需要清理临时文件的
        _addMessage(message);
      }, (Error error) {
        debugPrint("> on upload ${error.toString()}");
      });
    }
  }

  /// 拍摄
  Future<void> _handlePickerSelection() async {
    try {
      final AssetEntity? entity = await CameraPicker.pickFromCamera(
        context,
        pickerConfig: const CameraPickerConfig(
          enableRecording: true,
          onlyEnableRecording: false,
          enableTapRecording: true,
          maximumRecordingDuration: Duration(seconds: 24),
        ),
      );
      if (entity == null) {
        return;
      }
      if (mounted) {
        setState(() {});
      }
      await AttachmentProvider.uploadVideo("camera", entity, (
        Map<String, dynamic> resp,
        String imgUrl,
      ) async {
        double w = getx.Get.width;
        imgUrl += "&width=${w.toInt()}";

        if (entity.type == AssetType.image) {
          final message = types.ImageMessage(
              author: currentUser,
              createdAt: DateTimeHelper.currentTimeMillis(),
              id: Xid().toString(),
              name: await entity.titleAsync,
              height: entity.height * 1.0,
              width: entity.width * 1.0,
              size: resp["data"]["size"],
              uri: imgUrl,
              remoteId: widget.peerId,
              status: types.Status.sending,
              metadata: {
                'md5': resp['data']['md5'].toString(),
              });
          _addMessage(message);
        } else if (entity.type == AssetType.video) {
          Map<String, dynamic> metadata = {
            'custom_type': 'video',
            'thumb': (resp['thumb'] as EntityImage).toJson(),
            'video': (resp['video'] as EntityVideo).toJson(),
          };
          debugPrint("> on upload metadata: ${metadata.toString()}");
          final message = types.CustomMessage(
            author: currentUser,
            createdAt: DateTimeHelper.currentTimeMillis(),
            id: Xid().toString(),
            remoteId: widget.peerId,
            status: types.Status.sending,
            metadata: metadata,
          );
          _addMessage(message);
        }
      }, (Error error) {
        debugPrint("> on upload error ${error.toString()}");
      }, uploadOriginalImage: true);
      if (mounted) {
        setState(() {});
      }
      // 上传成功，删除本地临时文件
      (await entity.file)?.deleteSync();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _selectAssets(PickMethod model) async {
    final List<AssetEntity>? result = await model.method(context, assets);
    if (result != null) {
      assets = List<AssetEntity>.from(result);
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// 发送收藏消息
  Future<void> _handleCollectSelection() async {
    Map<String, String> peer = {
      'peerId': widget.peerId,
      'avatar': widget.peerAvatar,
      'title': widget.peerTitle,
    };

    UserCollectModel? c1 = await Navigator.push(
      context,
      CupertinoPageRoute(
        // “右滑返回上一页”功能
        builder: (_) => UserCollectPage(
          peer: peer,
          isSelect: true,
        ),
      ),
    );
    debugPrint("_handleCollectSelection ${c1?.toMap().toString()}");
    if (c1 != null) {
      Map<String, dynamic> data = c1.info;
      data[MessageRepo.id] = Xid().toString();
      data[MessageRepo.from] = UserRepoLocal.to.currentUid;
      data[MessageRepo.to] = widget.peerId;
      data[MessageRepo.status] = 10;
      data[MessageRepo.conversationUk3] = conversation.uk3;
      data[MessageRepo.createdAt] = DateTimeHelper.currentTimeMillis();

      types.Message msg = await MessageModel.fromJson(data).toTypeMessage();

      bool res = await _addMessage(msg);
      if (res) {
        getx.Get.find<UserCollectLogic>().change(c1.kindId);
        EasyLoading.showSuccess('tip_success'.tr);
      } else {
        EasyLoading.showError('tip_failed'.tr);
      }
    }
  }

  /// 发送个人名片
  Future<void> _handleVisitCardSelection() async {
    Map<String, String> peer = {
      'peerId': widget.peerId,
      'avatar': widget.peerAvatar,
      'title': widget.peerTitle,
    };

    ContactModel? c1 = await Navigator.push(
      context,
      CupertinoPageRoute(
        // “右滑返回上一页”功能
        builder: (_) => SelectFriendPage(
          peer: peer,
        ),
      ),
    );
    // debugPrint("handleVisitCardSelection ${c1?.toJson().toString()}");
    if (c1 != null) {
      Map<String, dynamic> metadata = {
        'custom_type': 'visit_card',
        'uid': c1.peerId,
        'title': c1.nickname,
        'avatar': c1.avatar,
      };
      debugPrint("> location metadata: ${metadata.toString()}");
      final message = types.CustomMessage(
        author: currentUser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: Xid().toString(),
        remoteId: widget.peerId,
        status: types.Status.sending,
        metadata: metadata,
      );
      bool res = await _addMessage(message);
      if (res) {
        EasyLoading.showSuccess('tip_success'.tr);
      } else {
        EasyLoading.showError('tip_failed'.tr);
      }
    }
  }

  /// 发送位置消息
  void _handleLocationSelection(String id, Uint8List? imageBytes,
      String address, String title, String latitude, String longitude) async {
    img.Image image = img.decodeImage(imageBytes!)!;
    final result = img.encodeJpg(image, quality: 65);
    AttachmentProvider.uploadBytes("location", result, (
      Map<String, dynamic> resp,
      String imgUrl,
    ) async {
      double w = getx.Get.width;
      imgUrl += "&width=${w.toInt()}";
      Map<String, dynamic> metadata = {
        'custom_type': 'location',
        'title': title,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'thumb': imgUrl,
        'size': resp['data']['size'],
        'md5': resp['data']['md5'].toString(),
      };

      debugPrint("> location metadata: ${metadata.toString()}");
      final message = types.CustomMessage(
        author: currentUser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: Xid().toString(),
        remoteId: widget.peerId,
        status: types.Status.sending,
        metadata: metadata,
      );
      _addMessage(message);
      // 上传成功，删除本地临时文件
      // file.deleteSync();
    }, (Error error) {
      debugPrint("> on upload ${error.toString()}");
    }, process: false);
  }

  void _handleImageSelection() async {
    await _selectAssets(PickMethod.cameraAndStay(maxAssetsCount: 9));
    for (var entity in assets) {
      await AttachmentProvider.uploadVideo("img", entity, (
        Map<String, dynamic> resp,
        String imgUrl,
      ) async {
        if (entity.type == AssetType.image) {
          double w = getx.Get.width;
          imgUrl += "&width=${w.toInt()}";

          debugPrint("> on upload imgUrl $imgUrl");
          debugPrint("> on upload $resp.toString()");

          final message = types.ImageMessage(
              author: currentUser,
              createdAt: DateTimeHelper.currentTimeMillis(),
              id: Xid().toString(),
              name: await entity.titleAsync,
              height: entity.height * 1.0,
              width: entity.width * 1.0,
              size: resp["data"]["size"],
              uri: imgUrl,
              remoteId: widget.peerId,
              status: types.Status.sending,
              metadata: {
                'md5': resp['data']['md5'].toString(),
              });

          _addMessage(message);
        } else if (entity.type == AssetType.video) {
          Map<String, dynamic> metadata = {
            'custom_type': 'video',
            'thumb': (resp['thumb'] as EntityImage).toJson(),
            'video': (resp['video'] as EntityVideo).toJson(),
          };
          debugPrint("> on upload metadata: ${metadata.toString()}");
          final message = types.CustomMessage(
            author: currentUser,
            createdAt: DateTimeHelper.currentTimeMillis(),
            id: Xid().toString(),
            remoteId: widget.peerId,
            status: types.Status.sending,
            metadata: metadata,
          );
          _addMessage(message);
        }
        assets.removeAt(
          assets.indexWhere((element) => element.id == entity.id),
        );
      }, (Error error) {
        debugPrint("> on upload ${error.toString()}");
      }, uploadOriginalImage: true);
    }
  }

  void _handleVoiceSelection(AudioFile? obj) async {
    if (obj == null) {
      return;
    }
    debugPrint(
        "> on _handleVoiceSelection1 file ${await obj.file.readAsBytes()} ${obj.file.toString()}");
    if ((await obj.file.readAsBytes()).isEmpty) {
      return;
    }
    final List<double> waveform = obj.waveform;
    debugPrint(
        "> on _handleVoiceSelection1 waveform ${obj.waveform.toString()}");
    await AttachmentProvider.uploadFile('audio', obj.file, (
      Map<String, dynamic> resp,
      String uri,
    ) async {
      debugPrint("> on _handleVoiceSelection2 waveform ${waveform.toString()}");
      Map<String, dynamic> metadata = {
        'custom_type': 'audio',
        'uri': uri,
        'size': (await obj.file.readAsBytes()).length,
        'duration_ms': obj.duration.inMilliseconds,
        'waveform': waveform,
        'mime_type': obj.mimeType,
        'md5': resp['data']['md5'].toString(),
      };
      debugPrint("> on upload metadata: ${metadata.toString()}");
      final message = types.CustomMessage(
        author: currentUser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: Xid().toString(),
        remoteId: widget.peerId,
        status: types.Status.sending,
        metadata: metadata,
      );

      obj.file.delete(recursive: true);
      _addMessage(message);
    }, (Error error) {
      debugPrint("> on upload ${error.toString()}");
    }, process: false);
  }

  void _onMessageDoubleTap(BuildContext c1, types.Message message) async {
    if (message is types.TextMessage) {
      showTextMessage(message.text);
    } else if (message is types.FileMessage) {
      confirmOpenFile(message.uri);
    } else if (message is types.ImageMessage) {
      galleryLogic.onImagePressed(message);
      setState(() {
        _showAppBar = false;
      });
    } else if (message is types.CustomMessage) {
      // String customType = message.metadata?['custom_type'] ?? '';
      String txt = message.metadata?['quote_text'] ?? '';
      if (txt.isNotEmpty) {
        showTextMessage(txt);
      }
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = logic.state.messages.indexWhere((e) => e.id == message.id);
    final updatedMessage =
        (logic.state.messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      logic.state.messages[index] = updatedMessage;
    });
  }

  Future<void> updateQuoteMessage(types.Message? msg) async {
    // debugPrint('> on updateQuoteMessage ${msg.toString()}');
    setState(() {
      quoteMessage = msg;
    });
  }

  Future<bool> _handleSendPressed(types.PartialText msg) async {
    if (quoteMessage == null) {
      iPrint("_handleSendPressed 1 ${DateTimeHelper.currentTimeMillis()}");
      final textMessage = types.TextMessage(
        author: currentUser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: Xid().toString(),
        text: msg.text,
        remoteId: widget.peerId,
        status: types.Status.sending,
      );
      return await _addMessage(textMessage);
    } else {
      String quoteMsgAuthorName = quoteMessage!.author.id == widget.peerId
          ? widget.peerTitle
          : UserRepoLocal.to.current.nickname;
      Map<String, dynamic> metadata = {
        'custom_type': 'quote',
        'quote_msg': quoteMessage?.toJson(),
        'quote_msg_author_name': quoteMsgAuthorName,
        'quote_text': msg.text,
      };
      // debugPrint("> on upload metadata: ${metadata.toString()}");
      final message = types.CustomMessage(
        author: currentUser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: Xid().toString(),
        remoteId: widget.peerId,
        status: types.Status.sending,
        metadata: metadata,
      );
      bool res = await _addMessage(message);
      if (res) {
        // 消息发送成功，取消被引用的消息提示
        updateQuoteMessage(null);
      }
      return res;
    }
  }

  void _onMessageStatusTap(BuildContext ctx, types.Message msg) {
    if (msg.status != types.Status.sending) {
      return;
    }
    int diff = DateTimeHelper.utc() - msg.createdAt!;
    if (diff > 1000) {
      // 检查为发送消息
      logic.sendWsMsg(logic.getMsgFromTMsg(
        widget.type,
        conversation.uk3,
        msg,
      ));
      setState(() {
        logic.state.messages;
      });
    }
  }

  void _onMessageLongPress(BuildContext c1, types.Message message) async {
    if (message is types.FileMessage) {
      await OpenFile.open(AssetsService.viewUrl(message.uri).toString());
    }

    if (!context.mounted) return;
    // ignore: use_build_context_synchronously
    popupmenu.PopupMenu menu = popupmenu.PopupMenu(
      // ignore: must_be_immutable
      context: c1,
      items: logic.getPopupMenuItems(message),
      onClickMenu: onClickMenu,
      // stateChanged: stateChanged,
      // onDismiss: onDismiss,
    );
    // ignore: use_build_context_synchronously
    RenderBox renderBox = c1.findRenderObject() as RenderBox;
    Offset offset = renderBox.localToGlobal(Offset.zero);
    double l = offset.dx / 2 - renderBox.size.width / 2 + 75.0;
    double r = renderBox.size.width / 2 - 75.0;
    double dx = message.author.id == UserRepoLocal.to.currentUid ? r : l;
    double dy = offset.dy;
    double h = renderBox.size.height;
    if (dy < 0 || dy > getx.Get.height) {
      dy = getx.Get.height / 2;
    }
    if (h > getx.Get.height) {
      dy = getx.Get.height / 2;
    }
    menu.show(
      rect: Rect.fromLTWH(
        dx,
        dy,
        renderBox.size.width,
        h,
      ),
    );
  }

  void onClickMenu(popupmenu.MenuItemProvider item) async {
    popupmenu.MenuItem it = item as popupmenu.MenuItem;
    types.Message msg = it.userInfo['msg'] as types.Message;
    String itemId = it.userInfo['id'] ?? '';
    debugPrint("> on onClickMenu $itemId, ${msg.id}");
    if (itemId == "delete") {
      n.showDialog(
        context: getx.Get.context!,
        builder: (context) => n.Alert()
          ..contentPadding = n.NikuEdgeInsets.all(0)
          ..backgroundColor = const Color(0xff232323)
          ..content = n.Column([
            ListTile(
              title: Text(
                'delete_for_me'.tr,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final nav = Navigator.of(context);
                if (widget.type == 'C2G') {
                  // 仅仅删除线上的 for 的数据
                  Map<String, dynamic> msg2 = {
                    'id': Xid().toString(),
                    'from': msg.author.id,
                    'to': msg.remoteId, // group id | or user id
                    'type': 'S2C',
                    'payload': {
                      'old_msg_id': msg.id,
                      'to': msg.remoteId,
                      // c2g 的时候为 group id
                      'msg_type': '${widget.type}_DEL_FOR_ME',
                      // c2g_del_for_me
                    },
                    'created_at': DateTimeHelper.utc()
                  };
                  await logic.sendMessage(msg2);
                }
                // 删除消息
                bool res = await logic.removeMessage(conversation, msg);
                if (res) {
                  final i = logic.state.messages
                      .indexWhere((element) => element.id == msg.id);
                  setState(() {
                    logic.state.messages.removeAt(i);
                  });
                  // 关闭AlertDialog
                  nav.pop();
                }
              },
            ),
            if (msg.author.id == UserRepoLocal.to.currentUid)
              n.Padding(
                left: 16,
                right: 16,
                child: HorizontalLine(height: getx.Get.isDarkMode ? 0.5 : 1.0),
              ),
            if (msg.author.id == UserRepoLocal.to.currentUid)
              ListTile(
                title: Text(
                  'delete_for_everyone'.tr,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  final nav = Navigator.of(context);
                  Map<String, dynamic> msg2 = {
                    'id': Xid().toString(),
                    'from': msg.author.id,
                    'to': msg.remoteId, // group id | or user id
                    'type': 'S2C',
                    'payload': {
                      'old_msg_id': msg.id,
                      'to': msg.remoteId, // c2g 的时候为 group id
                      'msg_type': '${widget.type}_DEL_EVERYONE',
                    },
                    'created_at': DateTimeHelper.utc()
                  };
                  await logic.sendMessage(msg2);
                  // 关闭AlertDialog
                  nav.pop();
                },
              ),
          ]),
        // ..actions = [
        //   n.Button('button_cancel'.tr.n)
        //     ..style = n.NikuButtonStyle(
        //       foregroundColor:
        //       Theme.of(context).colorScheme.onSurface,
        //     )
        //     ..onPressed = () {
        //       Navigator.of(context).pop();
        //     },
        //   n.Button('button_delete'.tr.n)
        //     ..style = n.NikuButtonStyle(
        //       foregroundColor:
        //       Theme.of(context).colorScheme.onSurface,
        //     )
        //     ..onPressed = () async {
        //       var nav = Navigator.of(context);
        //
        //       bool res = await logic.deleteDevice(
        //         model.deviceId,
        //       );
        //       if (res) {
        //         state.deviceList.removeAt(
        //           state.deviceList.indexWhere(
        //                   (e) => e.deviceId == model.deviceId),
        //         );
        //         EasyLoading.showSuccess('tip_success'.tr);
        //         nav.pop();
        //         Get.back(times: 1);
        //       } else {
        //         EasyLoading.showError('tip_failed'.tr);
        //       }
        //     },
        // ],
        barrierDismissible: true,
      );
      /*
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            // title: Text('Delete Message'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  title: Text('delete_for_me'.tr),
                  onTap: () async {
                    final nav = Navigator.of(context);
                    if (widget.type == 'C2G') {
                      // 仅仅删除线上的 for 的数据
                      Map<String, dynamic> msg2 = {
                        'id': Xid().toString(),
                        'from': msg.author.id,
                        'to': msg.remoteId, // group id | or user id
                        'type': 'S2C',
                        'payload': {
                          'old_msg_id': msg.id,
                          'to': msg.remoteId,
                          // c2g 的时候为 group id
                          'msg_type': '${widget.type}_DEL_FOR_ME',
                          // c2g_del_for_me
                        },
                        'created_at': DateTimeHelper.utc()
                      };
                      await logic.sendMessage(msg2);
                    }
                    // 删除消息
                    bool res = await logic.removeMessage(conversation, msg);
                    if (res) {
                      final i = logic.state.messages
                          .indexWhere((element) => element.id == msg.id);
                      setState(() {
                        logic.state.messages.removeAt(i);
                      });
                      // 关闭AlertDialog
                      nav.pop();
                    }
                  },
                ),
                if (msg.author.id == UserRepoLocal.to.currentUid)
                  HorizontalLine(height: getx.Get.isDarkMode ? 0.5 : 1.0),
                if (msg.author.id == UserRepoLocal.to.currentUid)
                  ListTile(
                    title: Text('delete_for_everyone'.tr),
                    onTap: () async {
                      final nav = Navigator.of(context);
                      Map<String, dynamic> msg2 = {
                        'id': Xid().toString(),
                        'from': msg.author.id,
                        'to': msg.remoteId, // group id | or user id
                        'type': 'S2C',
                        'payload': {
                          'old_msg_id': msg.id,
                          'to': msg.remoteId, // c2g 的时候为 group id
                          'msg_type': '${widget.type}_DEL_EVERYONE',
                        },
                        'created_at': DateTimeHelper.utc()
                      };
                      await logic.sendMessage(msg2);
                      // 关闭AlertDialog
                      nav.pop();
                    },
                  ),
              ],
            ),
          );
        },
      );
      */
    } else if (itemId == "copy" && msg is types.TextMessage) {
      // 复制消息
      Clipboard.setData(ClipboardData(text: msg.text));
      EasyLoading.showToast('copied'.tr);
    } else if (itemId == "collect") {
      String tb = MessageRepo.getTableName(widget.type);
      // 添加收藏
      bool res = await UserCollectLogic().add(tb: tb, msg: msg);
      if (res) {
        EasyLoading.showSuccess('collected'.tr);
      } else {
        EasyLoading.showError('operation_failed_again_later'.tr);
      }
    } else if (itemId == "revoke") {
      // 撤回消息

      Map<String, dynamic> msg2 = {
        'ts': DateTimeHelper.utc(),
        'id': msg.id,
        'type': '${widget.type.toUpperCase()}_REVOKE',
        'from': msg.author.id,
        'to': msg.remoteId,
      };
      await logic.sendMessage(msg2);
    } else if (itemId == "quote") {
      // 引用消息
      updateQuoteMessage(msg);
    } else if (itemId == "transpond") {
      // 转发消息
      getx.Get.bottomSheet(
        backgroundColor: getx.Get.isDarkMode
            ? const Color.fromRGBO(80, 80, 80, 1)
            : const Color.fromRGBO(240, 240, 240, 1),
        n.Padding(
          top: 24,
          child: SendToPage(msg: msg),
        ),
        // 是否支持全屏弹出，默认false
        isScrollControlled: true,
        // enableDrag: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topRightWidget = [
      InkWell(
        onTap: () => getx.Get.to(
          () => widget.type == 'C2G'
              ? GroupDetailPage(
                  groupId: widget.peerId,
                  memberCount: logic.state.memberCount,
                  title: widget.peerTitle,
                  callBack: (v) {},
                )
              : ChatSettingPage(widget.peerId, type: widget.type, options: {
                  "peerId": widget.peerId,
                  "avatar": widget.peerAvatar,
                  "nickname": widget.peerTitle,
                }),
          transition: getx.Transition.rightToLeft,
          popGesture: true, // 右滑，返回上一页
        )?.then((value) async {
          debugPrint("ChatSettingPage then $value, $mounted");
          bool flush = false;
          if (value != null && value == false) {
            logic.state.nextAutoId = 0;
            _handleEndReached();
            if (mounted) setState(() {});
          }
          debugPrint(
              "ChatSettingPage then flush $flush, memberCount ${logic.state.memberCount}; mounted $mounted");
          if (value is Map<String, dynamic>) {
            int num = value['memberCount'] ?? 0;
            if (num > 0) {
              logic.state.memberCount = num;
              flush = true;
              newGroupName = await logic.groupTitle(
                widget.peerId,
                widget.peerTitle,
                logic.state.memberCount,
              );
              if (mounted) setState(() {});
            }
          }
        }),
        // 三点更多 more icon
        child: n.Padding(
          left: 10,
          right: 10,
          bottom: 10,
          top: 10,
          child: Icon(
            Icons.more_horiz,
            color: Theme.of(context).colorScheme.onPrimary,
            // size: 40,
          ),
        ),
      )
    ];
    return Scaffold(
      appBar: _showAppBar
          ? NavAppBar(
              title: newGroupName == "" ? widget.peerTitle : newGroupName,
              rightDMActions: topRightWidget,
              automaticallyImplyLeading: true,
              popTime: widget.options?['popTime'] ?? 1,
            )
          : null,
      body: n.Column([
        getx.Obx(() {
          return connected.isTrue
              ? const SizedBox.shrink()
              : NetworkFailureTips();
        }),
        Expanded(
          child: n.Stack([
            Chat(
              user: currentUser,
              messages: logic.state.messages,
              showUserAvatars: true,
              avatarBuilder: (types.User author) {
                return n.Padding(
                    right: 4,
                    child: Avatar(
                      imgUri: author.imageUrl ?? '',
                      width: 44,
                      height: 44,
                    ));
              },
              showUserNames: widget.type == 'C2G',
              emptyState: Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(
                  horizontal: 24,
                ),
                child: Text(
                  'tip_empty_chat_placeholder'.tr,
                  textAlign: TextAlign.center,
                ),
              ),
              // bubbleBuilder: (
              //   Widget child, {
              //   required types.Message message,
              //   required bool nextMessageInGroup,
              // }) {
              //   bool isAuthor = message.author.id == UserRepoLocal.to.currentUid;
              //   return n.Column([
              //     Bubble(nip: isAuthor ? BubbleNip.rightCenter : BubbleNip.leftBottom, child: child),
              //     if (strNoEmpty(message.author.firstName) && isAuthor == false)
              //       n.Row([Text(message.author.firstName!)]),
              //   ])
              //     // 内容文本左对齐
              //     ..crossAxisAlignment = isAuthor ? CrossAxisAlignment.end : CrossAxisAlignment.start;
              // },
              textMessageBuilder: (
                types.TextMessage message, {
                required int messageWidth,
                required bool showName,
              }) {
                return IgnorePointer(
                  child: TextMessage(
                    emojiEnlargementBehavior: EmojiEnlargementBehavior.multi,
                    hideBackgroundOnEmojiMessages: true,
                    message: message,
                    showName: showName,
                    usePreviewData: true,
                    // nameBuilder: nameBuilder,
                    onPreviewDataFetched: _handlePreviewDataFetched,
                    // options: textMessageOptions,
                    // usePreviewData: usePreviewData,
                    // userAgent: userAgent,
                  ),
                );
              },
              imageMessageBuilder: (types.ImageMessage message,
                  {required int messageWidth}) {
                return ImageMessageBuilder(
                  message: message,
                  messageWidth: messageWidth,
                );
              },
              // showUserAvatars: true,
              // showUserNames: true,
              customMessageBuilder: (types.CustomMessage msg,
                  {required int messageWidth}) {
                return CustomMessageBuilder(
                  type: widget.type,
                  message: msg,
                );
              },
              scrollController: logic.state.scrollController,
              onEndReachedThreshold: 0.9,
              // 300000 = 5分钟 默认 900000 = 15 分钟
              dateHeaderThreshold: 300000,
              customDateHeaderText: (DateTime dt) =>
                  DateTimeHelper.customDateHeader(dt),
              onEndReached: _handleEndReached,
              onBackgroundTap: () {
                // 收起输聊天底部弹出框
                AnimationController bottomHeightController = getx.Get.find();
                bottomHeightController.animateBack(0);
                setState(() {
                  quoteMessage = null;
                });
              },
              onMessageTap: (BuildContext c1, types.Message message) async {
                if (message is types.ImageMessage) {
                  galleryLogic.onImagePressed(message);
                  setState(() {
                    _showAppBar = false;
                  });
                } else if (message is types.FileMessage) {
                  confirmOpenFile(message.uri);
                }
              },
              onMessageLongPress: _onMessageLongPress,
              onMessageDoubleTap: _onMessageDoubleTap,
              onPreviewDataFetched: _handlePreviewDataFetched,
              onSendPressed: _handleSendPressed,
              onMessageStatusTap: _onMessageStatusTap,
              onMessageStatusLongPress: _onMessageStatusTap,
              hideBackgroundOnEmojiMessages: false,
              theme: getx.Get.isDarkMode
                  ? const AppDarkChatTheme()
                  : const LightChatTheme(),
              // onTextFieldTap: () {
              // debugPrint("> on chatinput onTextFieldTap");
              // },
              slidableMessageBuilder: (types.Message msg, Widget msgWidget) {
                // String sysPrompt = "消息已发出，但被对方拒收了。";
                // 处理系统提示信息
                String sysPrompt = logic.parseSysPrompt(
                  msg.metadata?['sys_prompt'] ?? '',
                );
                return GestureDetector(
                  onLongPress: () {
                    debugPrint("> on GestureDetector");
                    // _onMessageLongPress(getx.Get.context!, msg);
                  },
                  onPanEnd: (DragEndDetails details) {
                    updateQuoteMessage(msg);
                  },
                  child: n.Column([
                    msgWidget,
                    if (strNoEmpty(sysPrompt))
                      n.Row([
                        // row > expand > column > text 换行有效
                        Expanded(
                            child: n.Column([
                          n.Padding(
                            left: 20,
                            right: 10,
                            bottom: 16,
                            child: Text(
                              sysPrompt,
                              // style: const TextStyle(color: AppColors.TipColor),
                              maxLines: 4,
                              softWrap: true,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ])),
                      ])
                        // 内容居中
                        ..mainAxisAlignment = MainAxisAlignment.spaceBetween
                  ]),
                );
              },
              customBottomWidget: widget.type == 'C2S'
                  ? null
                  : ChatInput(
                      type: widget.type,
                      peerId: widget.peerId,
                      // 发送触发事件
                      onSendPressed: _handleSendPressed,
                      sendButtonVisibilityMode:
                          SendButtonVisibilityMode.editing,
                      // voiceWidget: VoiceRecord(),
                      voiceWidget: VoiceWidget(
                        startRecord: () {},
                        stopRecord: _handleVoiceSelection,
                        // 加入定制化Container的相关属性
                        height: 60.0,
                        margin: EdgeInsets.zero,
                      ),
                      extraWidget: ExtraItems(
                          type: widget.type,
                          // 照片
                          handleImageSelection: _handleImageSelection,
                          // 文件
                          handleFileSelection: _handleFileSelection,
                          // 拍摄
                          handlePickerSelection: _handlePickerSelection,
                          // 位置消息
                          handleLocationSelection: _handleLocationSelection,
                          // 个人名片
                          handleVisitCardSelection: _handleVisitCardSelection,
                          // 收藏
                          handleCollectSelection: _handleCollectSelection,
                          options: {
                            "to": widget.peerId,
                            "title": widget.peerTitle,
                            "avatar": widget.peerAvatar,
                            "sign": widget.peerSign,
                          }),
                      // 引用消息
                      quoteTipsWidget: QuoteTipsWidget(
                        title: (quoteMessage != null &&
                                quoteMessage?.author.id ==
                                    UserRepoLocal.to.currentUid)
                            ? UserRepoLocal.to.current.nickname
                            : widget.peerTitle,
                        message: quoteMessage,
                        close: () {
                          updateQuoteMessage(null);
                        },
                      ),
                    ),
              // 禁用 flutter_chat_ui 的相册
              disableImageGallery: true,
            ),
            if (galleryLogic.isImageViewVisible.isTrue)
              IMBoyImageGallery(
                // ignore: invalid_use_of_protected_member
                images: galleryLogic.gallery.value,
                pageController: galleryLogic.galleryPageController!,
                onClosePressed: () {
                  iPrint("IMBoyImageGallery onClosePressed ");
                  galleryLogic.onCloseGalleryPressed();
                  setState(() {
                    _showAppBar = true;
                  });
                },
                options: const IMBoyImageGalleryOptions(
                  maxScale: PhotoViewComputedScale.covered,
                  minScale: PhotoViewComputedScale.contained,
                ),
              )
          ]),
        )
      ]),
    );
  }
}
