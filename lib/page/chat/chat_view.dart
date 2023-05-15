import 'dart:io';
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/message/message_image_builder.dart';
import 'package:imboy/page/chat/send_to/send_to_view.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:mime/mime.dart';
import 'package:niku/namespace.dart' as n;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:xid/xid.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart' as getx;
import 'package:open_file/open_file.dart';
import 'package:popup_menu/popup_menu.dart' as popupmenu;

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/picker_method.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/image_gallery/image_gallery_logic.dart';
import 'package:imboy/component/message/message.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/voice_record/voice_widget.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_view.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/group/group_detail/group_detail_view.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:imboy/store/provider/attachment_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'chat_logic.dart';
import 'widget/chat_input.dart';

// ignore: must_be_immutable
import 'widget/extra_item.dart';
import 'widget/quote_tips.dart';
import 'widget/select_friend.dart';

// ignore: must_be_immutable
class ChatPage extends StatefulWidget {
  int conversationId; // 会话ID
  final String peerId; // 用户ID
  final String peerAvatar;
  final String peerTitle;
  final String peerSign;
  final String type; // [C2C | GROUP]

  ChatPage({
    Key? key,
    this.conversationId = 0,
    required this.peerId,
    required this.peerTitle,
    required this.peerAvatar,
    required this.peerSign,
    this.type = 'C2C',
  }) : super(key: key);

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  // 网络状态描述
  getx.RxBool connected = true.obs;

  final logic = getx.Get.put(ChatLogic());
  final galleryLogic = getx.Get.put(ImageGalleryLogic());
  final conversationLogic = getx.Get.put(ConversationLogic());

  bool _showAppBar = true;

  String newGroupName = "";

  int _page = 1;

  int get maxAssetsCount => 9;

  List<AssetEntity> assets = <AssetEntity>[];

  types.Message? quoteMessage;

  @override
  void initState() {
    //监听Widget是否绘制完毕
    super.initState();

    // 检查WS链接状态
    WSService.to.openSocket();
    initData();
    unawaited(_handleEndReached());
    // 异步检查是否有离线数据 TODO leeyi 2023-01-29 16:43:47
  }

  /// 初始化一些数据
  Future<void> initData() async {
    if (availableMaps.isEmpty) {
      try {
        availableMaps = await MapLauncher.installedMaps;
      } catch (e) {
        //
      }
    }
    // 检查网络状态
    var res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      connected = false.obs;
    } else {
      connected = true.obs;
    }
    // 监听网络状态
    Connectivity().onConnectivityChanged.listen((ConnectivityResult r) {
      if (r == ConnectivityResult.none) {
        connected = false.obs;
      } else {
        connected = true.obs;
      }
    });

    // 接收到新的消息订阅
    eventBus.on<types.Message>().listen((types.Message msg) async {
      final index =
          logic.state.messages.indexWhere((element) => element.id == msg.id);
      if (index == -1 && msg.author.id == widget.peerId) {
        if (msg is types.ImageMessage) {
          galleryLogic.pushToGallery(msg.id, msg.uri);
        }

        conversationLogic.decreaseConversationRemind(widget.peerId, 1);
        if (mounted) {
          setState(() {
            logic.state.messages.insert(0, msg);
          });
        }
      }
    });
    debugPrint("> rtc msg S_RECEIVED listen list");
    // 消息状态更新订阅
    eventBus.on<List<types.Message>>().listen((e) async {
      types.Message msg = e.first;

      final index = logic.state.messages.indexWhere(
          (element) => element.id == msg.id
      );
      // debugPrint(
      //     "> rtc msg S_RECEIVED $index, $mounted, ${msg.toJson().toString()}");
      if (index > -1) {
        logic.state.messages.setRange(
          index,
          index + 1,
          e
        );
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
    getx.Get.delete<ChatLogic>();
    getx.Get.delete<ImageGalleryLogic>();

    super.dispose();
  }

  /// 用于分页(无限滚动)。当用户滚动时调用
  /// 到列表的最后(减去[onEndReachedThreshold])。
  Future<void> _handleEndReached() async {
    if (!mounted) {
      return;
    }

    if (widget.conversationId == 0) {
      widget.conversationId = await conversationLogic.createConversationId(
        widget.peerId,
        widget.peerAvatar,
        widget.peerTitle,
        widget.type,
      );
    }
    // 初始化 当前会话新增消息
    List<types.Message>? items = await logic.getMessages(
      widget.peerId,
      _page,
      16,
    );
    // debugPrint("ChatSettingPage then 2 ${items?.length};");
    List<String> msgIds = [];
    if (items != null && items.isNotEmpty) {
      // 消除消息提醒
      for (var msg in items) {
        if (msg is types.ImageMessage) {
          galleryLogic.pushToGallery(msg.id, msg.uri);
        }
        //enum Status { delivered, error, seen, sending, sent }
        if (msg.author.id != UserRepoLocal.to.currentUid &&
            msg.status != types.Status.seen) {
          msgIds.add(msg.id);
        }
      } // end for items
      if (msgIds.isNotEmpty) {
        ConversationModel? conversation = await logic.markAsRead(
          widget.conversationId,
          msgIds,
        );
        // debugPrint(
        //     "_handleEndReached conversation ${msgIds.length} ${conversation?.toJson().toString()}");
        if (conversation != null) {
          conversationLogic.decreaseConversationRemind(
              widget.peerId, msgIds.length);
          conversationLogic.replace(conversation);
        }
      }

      setState(() {
        logic.state.messages = [
          ...logic.state.messages,
          ...items,
        ];
        _page = _page + 1;
      });
    } else if (_page == 1) {
      setState(() {
        logic.state.messages = [];
      });
    }
    // debugPrint("ChatSettingPage then 3 ${logic.state.messages.length}");
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
          author: logic.currentUser,
          createdAt: DateTimeHelper.currentTimeMillis(),
          mimeType: lookupMimeType(result.files.single.path!),
          name: result.files.single.name,
          size: result.files.single.size,
          uri: uri,
          remoteId: widget.peerId,
          status: types.Status.sending,
        );
        // 上传现有的附件，是不需要清理临时文件的
        _addMessage(message);
      }, (DioError error) {
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
            author: logic.currentUser,
            createdAt: DateTimeHelper.currentTimeMillis(),
            id: Xid().toString(),
            name: await entity.titleAsync,
            height: entity.height * 1.0,
            width: entity.width * 1.0,
            size: resp["data"]["size"],
            uri: imgUrl,
            remoteId: widget.peerId,
            status: types.Status.sending,
          );
          _addMessage(message);
        } else if (entity.type == AssetType.video) {
          Map<String, dynamic> metadata = {
            'custom_type': 'video',
            'thumb': (resp['thumb'] as EntityImage).toJson(),
            'video': (resp['video'] as EntityVideo).toJson(),
          };
          debugPrint("> on upload metadata: ${metadata.toString()}");
          final message = types.CustomMessage(
            author: logic.currentUser,
            createdAt: DateTimeHelper.currentTimeMillis(),
            id: Xid().toString(),
            remoteId: widget.peerId,
            status: types.Status.sending,
            metadata: metadata,
          );
          _addMessage(message);
        }
      }, (DioError error) {
        debugPrint("> on upload error ${error.toString()}");
      });
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
    debugPrint("handleVisitCardSelection ${c1?.toJson().toString()}");
    if (c1 != null) {
      Map<String, dynamic> metadata = {
        'custom_type': 'visit_card',
        'uid': c1.peerId,
        'title': c1.nickname,
        'avatar': c1.avatar,
      };
      debugPrint("> location metadata: ${metadata.toString()}");
      final message = types.CustomMessage(
        author: logic.currentUser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: Xid().toString(),
        remoteId: widget.peerId,
        status: types.Status.sending,
        metadata: metadata,
      );
      bool res = await _addMessage(message);
      if (res) {
        EasyLoading.showSuccess('发送成功'.tr);
      } else {
        EasyLoading.showError('发送失败'.tr);
      }
    }
  }

  /// 发送位置消息
  void _handleLocationSelection(
    String id,
    Uint8List? imageBytes,
    String address,
    String title,
    String latitude,
    String longitude,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/$id.png').create();
    file.writeAsBytesSync(imageBytes as List<int>);
    AttachmentProvider.uploadFile("location", file, (
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
      };
      debugPrint("> location metadata: ${metadata.toString()}");
      final message = types.CustomMessage(
        author: logic.currentUser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: Xid().toString(),
        remoteId: widget.peerId,
        status: types.Status.sending,
        metadata: metadata,
      );
      _addMessage(message);
      // 上传成功，删除本地临时文件
      file.deleteSync();
    }, (DioError error) {
      debugPrint("> on upload ${error.toString()}");
    }, name: id);
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
            author: logic.currentUser,
            createdAt: DateTimeHelper.currentTimeMillis(),
            id: Xid().toString(),
            name: await entity.titleAsync,
            height: entity.height * 1.0,
            width: entity.width * 1.0,
            size: resp["data"]["size"],
            uri: imgUrl,
            remoteId: widget.peerId,
            status: types.Status.sending,
          );

          _addMessage(message);
        } else if (entity.type == AssetType.video) {
          Map<String, dynamic> metadata = {
            'custom_type': 'video',
            'thumb': (resp['thumb'] as EntityImage).toJson(),
            'video': (resp['video'] as EntityVideo).toJson(),
          };
          debugPrint("> on upload metadata: ${metadata.toString()}");
          final message = types.CustomMessage(
            author: logic.currentUser,
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
      }, (DioError error) {
        debugPrint("> on upload ${error.toString()}");
      });
    }
  }

  void _handleVoiceSelection(AudioFile? obj) async {
    if (obj == null) {
      return;
    }
    final List<double> waveform = obj.waveform;
    debugPrint("> on _handleVoiceSelection1 ${obj.waveform.toString()}");
    await AttachmentProvider.uploadFile('audio', obj.file, (
      Map<String, dynamic> resp,
      String uri,
    ) async {
      debugPrint("> on _handleVoiceSelection2 ${waveform.toString()}");
      Map<String, dynamic> metadata = {
        'custom_type': 'audio',
        'uri': uri,
        'size': (await obj.file.readAsBytes()).length,
        'duration_ms': obj.duration.inMilliseconds,
        'waveform': waveform,
        'mime_type': obj.mimeType,
      };
      debugPrint("> on upload metadata: ${metadata.toString()}");
      final message = types.CustomMessage(
        author: logic.currentUser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: Xid().toString(),
        remoteId: widget.peerId,
        status: types.Status.sending,
        metadata: metadata,
      );

      obj.file.delete(recursive: true);
      _addMessage(message);
    }, (DioError error) {
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
    final index =
        logic.state.messages.indexWhere((element) => element.id == message.id);
    final updatedMessage =
        (logic.state.messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      logic.state.messages[index] = updatedMessage;
    });
  }

  Future<void> updateQuoteMessage(types.Message? msg) async {
    debugPrint('> on updateQuoteMessage ${msg.toString()}');
    setState(() {
      quoteMessage = msg;
    });
  }

  Future<bool> _handleSendPressed(types.PartialText msg) async {
    if (quoteMessage == null) {
      final textMessage = types.TextMessage(
        author: logic.currentUser,
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
      debugPrint("> on upload metadata: ${metadata.toString()}");
      final message = types.CustomMessage(
        author: logic.currentUser,
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
    int diff = DateTimeHelper.currentTimeMillis() - msg.createdAt!;
    if (diff > 800) {
      // 检查为发送消息
      logic.sendWsMsg(logic.getMsgFromTMsg(
        widget.type,
        widget.conversationId,
        msg,
      ));
      setState(() {
        logic.state.messages;
      });
    }
  }

  void _onMessageLongPress(BuildContext c1, types.Message message) async {
    if (message is types.FileMessage) {
      await OpenFile.open(message.uri);
    }
    List<popupmenu.MenuItemProvider> items = [
      // MenuItem(
      //   title: '收藏'.tr,
      //   userInfo: {"id":"", "msg":message},
      //   textAlign: TextAlign.center,
      //   textStyle: TextStyle(
      //     color: Color(0xffc5c5c5),
      //     fontSize: 10.0,
      //   ),
      //   image: Icon(
      //     Icons.collections_bookmark,
      //     size: 16,
      //     color: Color(0xffc5c5c5),
      //   ),
      // ),
      // MenuItem(
      //   title: '多选'.tr,
      //   userInfo: {"id":"multiselect", "msg":message},
      //   textAlign: TextAlign.center,
      //   textStyle: TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
      //   image: Icon(
      //     Icons.add_road,
      //     size: 16,
      //     color: Color(0xffc5c5c5),
      //   ),
      // ),
    ];
    bool canCopy = false;
    String customType = message.metadata?['custom_type'] ?? '';
    if (message.type == types.MessageType.text) {
      canCopy = true;
    } else if (customType == 'quote') {
      canCopy = true;
    }
    if (canCopy) {
      items.add(popupmenu.MenuItem(
        title: '复制',
        userInfo: {"id": "copy", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          color: Color(0xffc5c5c5),
          fontSize: 10.0,
        ),
        image: const Icon(
          Icons.copy,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }
    //
    bool isRevoked = (message is types.CustomMessage) && customType == 'revoked'
        ? true
        : false;
    if (!isRevoked) {
      items.add(popupmenu.MenuItem(
        title: '转发'.tr,
        userInfo: {"id": "transpond", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          fontSize: 10.0,
          color: Color(0xffc5c5c5),
        ),
        // image: const Icon(
        //   Icons.fork_right_rounded,
        //   color: Colors.white,
        // ),
        image: Image.asset(
          'assets/images/chat/reply_to.png',
          // size: 16,
          color: const Color(0xffc5c5c5),
          // package: 'flutter_plugin_record',
        ),
      ));
      items.add(popupmenu.MenuItem(
        title: '引用'.tr,
        userInfo: {"id": "quote", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
        image: const Icon(
          Icons.format_quote,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }
    if (message.author.id == UserRepoLocal.to.currentUid &&
        isRevoked == false) {
      items.add(
        popupmenu.MenuItem(
          title: '撤回',
          userInfo: {"id": "revoke", "msg": message},
          textAlign: TextAlign.center,
          textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
          image: const Icon(
            Icons.layers_clear_rounded,
            size: 16,
            color: Color(0xffc5c5c5),
          ),
        ),
      );
    }
    items.add(popupmenu.MenuItem(
      title: '删除',
      userInfo: {"id": "delete", "msg": message},
      textAlign: TextAlign.center,
      textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
      image: const Icon(
        Icons.remove_circle_outline_rounded,
        size: 16,
        color: Color(0xffc5c5c5),
      ),
    ));

    // ignore: use_build_context_synchronously
    popupmenu.PopupMenu menu = popupmenu.PopupMenu(
      // backgroundColor: Colors.teal,
      // lineColor: Colors.tealAccent,
      // maxColumn: 2,
      items: items,
      context: c1,
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
    debugPrint("> on chat _handleMessageTap "
        "dx:${offset.dx},dy:${offset.dy},"
        "w:${renderBox.size.width},h:${renderBox.size.height}");
    menu.show(
      rect: Rect.fromLTWH(
        dx,
        offset.dy,
        renderBox.size.width,
        renderBox.size.height,
      ),
    );
  }

  void onClickMenu(popupmenu.MenuItemProvider item) async {
    popupmenu.MenuItem it = item as popupmenu.MenuItem;
    types.Message msg = it.userInfo['msg'] as types.Message;
    String itemId = it.userInfo['id'] ?? '';
    debugPrint("> on onClickMenu $itemId, ${msg.id}");
    if (itemId == "delete") {
      // 删除消息
      bool res = await logic.removeMessage(msg.id);
      if (res) {
        final index =
            logic.state.messages.indexWhere((element) => element.id == msg.id);
        setState(() {
          logic.state.messages.removeAt(index);
        });
      }
    } else if (itemId == "copy" && msg is types.TextMessage) {
      // 复制消息
      Clipboard.setData(ClipboardData(text: msg.text));
    } else if (itemId == "revoke") {
      // 撤回消息
      await logic.revokeMessage(msg);
    } else if (itemId == "quote") {
      // 引用消息
      updateQuoteMessage(msg);
    } else if (itemId == "transpond") {
      // 转发消息
      getx.Get.bottomSheet(
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
    var topRightWidget = [
      InkWell(
        // child: const Image(image: AssetImage('assets/images/right_more.png')),
        child: n.Padding(
          right: 10,
          child: const Icon(
            Icons.more_horiz,
            // size: 40,
          ),
        ),
        onTap: () => getx.Get.to(()=>
          widget.type == 'GROUP'
              ? GroupDetailPage(
                  widget.peerId,
                  callBack: (v) {},
                )
              : ChatSettingPage(widget.peerId, options: {
                  "peerId": widget.peerId,
                  "avatar": widget.peerAvatar,
                  "nickname": widget.peerTitle,
                }),
          transition: Transition.rightToLeft,
          popGesture: true, // 右滑，返回上一页
        )?.then((value) {
          debugPrint("ChatSettingPage then $value, $mounted");
          if (value != null && value) {
            _page = 1;
            _handleEndReached();
          }
        }),
      )
    ];
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: _showAppBar
          ? PageAppBar(
              title: newGroupName == "" ? widget.peerTitle : newGroupName,
              rightDMActions: topRightWidget,
            )
          : null,
      body: n.Column([
        getx.Obx(() {
          return connected.isTrue
              ? const SizedBox.shrink()
              : NetworkFailureTips();
        }),
        Expanded(
            child: n.Stack(
          [
            Chat(
              user: logic.currentUser,
              messages: logic.state.messages,
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
              theme: const ImboyChatTheme(),
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
                              style: const TextStyle(color: AppColors.TipColor),
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
              customBottomWidget: ChatInput(
                // 发送触发事件
                onSendPressed: _handleSendPressed,
                sendButtonVisibilityMode: SendButtonVisibilityMode.editing,
                // voiceWidget: VoiceRecord(),
                voiceWidget: VoiceWidget(
                  startRecord: () {},
                  stopRecord: _handleVoiceSelection,
                  // 加入定制化Container的相关属性
                  height: 40.0,
                  margin: EdgeInsets.zero,
                ),
                extraWidget: ExtraItems(
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
                  debugPrint("> on onClosePressed ");
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
          ],
        ))
      ]),
    );
  }
}
