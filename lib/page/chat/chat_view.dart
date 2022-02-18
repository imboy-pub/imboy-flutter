import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:extended_text/extended_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart' as Getx;
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/widget/chat/chat_input.dart';
import 'package:imboy/component/widget/chat/extra_item.dart';
import 'package:imboy/component/widget/chat/voice_record.dart';
import 'package:imboy/component/widget/message/custom_message.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/helper/datetime.dart';
import 'package:imboy/helper/picker_method.dart';
import 'package:imboy/page/chat_info/chat_info_view.dart';
import 'package:imboy/page/group_detail/group_detail_view.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/store/provider/upload_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';
import 'package:popup_menu/popup_menu.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:xid/xid.dart';

import 'chat_logic.dart';

class ChatPage extends StatefulWidget {
  final int id; // 会话ID
  final String toId; // 用户ID
  final String? type; // [C2C | GROUP]
  final String? title;
  final String? avatar;

  ChatPage({
    required this.id,
    required this.toId,
    this.title,
    this.avatar,
    this.type = 'C2C',
  });
  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final logic = Getx.Get.put(ChatLogic());

  // 当前会话新增消息
  List<types.Message> messages = [];

  String newGroupName = "";

  var _connectivityResult;
  Getx.RxString _connectStateDescription = "".obs;

  int _page = 1;

  AssetEntity? entity;
  Uint8List? data;

  int get maxAssetsCount => 9;

  List<AssetEntity> assets = <AssetEntity>[];

  int get assetsLength => assets.length;

  @override
  void initState() {
    //监听Widget是否绘制完毕
    super.initState();
    if (!mounted) {
      return;
    }
    _handleEndReached();

    // Register listeners for all events:
    String toId = widget.toId;
    // 接收到新的消息订阅
    eventBus.on<types.Message>().listen((e) async {
      debugPrint(">>> on MessageService chat_view initState: " +
          e.runtimeType.toString());

      if (e is types.Message && e.author.id == toId) {
        MessageService.to.decreaseConversationRemind(toId, 1);
        messages.insert(0, e);
        if (mounted) {
          setState(() {
            messages;
          });
        }
      }
    });

    // 消息状态更新订阅
    eventBus.on<List<types.Message>>().listen((e) async {
      types.Message msg = e.first;
      final index = messages.indexWhere((element) => element.id == msg.id);
      debugPrint(">>> on MessageService chat_view initState:$index; " +
          msg.toJson().toString());
      if (index > -1) {
        messages.setRange(index, index + 1, e);
        if (mounted) {
          setState(() {
            messages;
          });
        }
      }
    });
  }

  Future<void> _handleEndReached() async {
    // 初始化 当前会话新增消息
    List<types.Message>? items = await logic.getMessages(
      widget.toId,
      _page,
      10,
    );

    debugPrint(">>>>> on _loadMessages msg: ${items.toString()}");
    if (items != null && items.length > 0) {
      // 消除消息提醒
      items.forEach((msg) async {
        if (msg.status == types.Status.delivered) {
          bool res = await logic.markAsRead(widget.id, msg);
          if (res) {
            MessageService.to.decreaseConversationRemind(widget.toId, 1);
          }
        }
        debugPrint(">>>>> on chat initData msg :${msg.toString()}");
      });

      setState(() {
        messages = [
          ...messages,
          ...items,
        ];
        _page = _page + 1;
      });
    }
  }

  Future<bool> _addMessage(types.Message message) async {
    // 先显示在聊天UI里面
    // 异步发送WS消息
    // 异步存储sqlite消息(未发送成功）
    //   发送成功后，更新conversation、更新消息状态
    //   发送失败后，放入异步队列，重新发送
    bool res = await logic.addMessage(
      UserRepoLocal.to.currentUid,
      widget.toId,
      widget.avatar ?? '',
      widget.title!,
      widget.type!,
      message,
    );

    setState(() {
      if (res) {
        messages.insert(0, message);
      }
    });
    return res;
    // _msgService.update();
  }

  void _handleAtachmentPressed() {
    Getx.Get.bottomSheet(
      Container(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.photo),
              title: Text('Photo'),
              onTap: () => {_handleImageSelection()},
            ),
            ListTile(
              leading: Icon(Icons.drive_file_move),
              title: Text('File'),
              onTap: () => {_handleFileSelection()},
            ),
          ],
        ),
      ),
      backgroundColor: AppColors.BgColor,
    );
  }

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final message = types.FileMessage(
        author: logic.cuser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: Xid().toString(),
        mimeType: lookupMimeType(result.files.single.path!),
        name: result.files.single.name,
        size: result.files.single.size,
        uri: result.files.single.path!,
        remoteId: widget.toId,
        status: types.Status.sending,
      );

      _addMessage(message);
    }
  }

  /**
   * 拍摄
   */
  Future<void> _handlePickerSelection() async {
    BuildContext context = Getx.Get.context!;
    final Size size = MediaQuery.of(context).size;
    final double scale = MediaQuery.of(context).devicePixelRatio;
    try {
      final AssetEntity? _entity = await CameraPicker.pickFromCamera(
        context,
        enableRecording: true,
      );
      if (_entity != null && entity != _entity) {
        entity = _entity;
        if (mounted) {
          setState(() {});
        }
        data = await _entity.thumbDataWithSize(
          (size.width * scale).toInt(),
          (size.height * scale).toInt(),
        );
        if (mounted) {
          setState(() {});
        }
      }
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

  void _handleImageSelection() async {
    await _selectAssets(PickMethod.cameraAndStay(maxAssetsCount: 9));
    var up = UploadProvider();
    assets.forEach((entity) async {
      await up.uploadImg("chat", (
        Map<String, dynamic> resp,
        String imgUrl,
      ) async {
        debugPrint(">>> on upload imgUrl ${imgUrl}");
        debugPrint(">>> on upload ${resp.toString()}");

        final message = types.ImageMessage(
          author: logic.cuser,
          createdAt: DateTimeHelper.currentTimeMillis(),
          id: Xid().toString(),
          name: await entity.titleAsync,
          height: entity.height * 1.0,
          width: entity.width * 1.0,
          size: resp["data"]["size"],
          uri: imgUrl,
          remoteId: widget.toId,
          status: types.Status.sending,
        );

        _addMessage(message);
        assets.removeAt(
          assets.indexWhere((element) => element.id == entity.id),
        );
      }, (DioError error) {
        debugPrint(">>> on upload ${error.toString()}");
      }, entity);
    });
  }

  void _onMessageDoubleTap(BuildContext c1, types.Message message) async {
    if (message is types.TextMessage) {
      Getx.Get.bottomSheet(
        GestureDetector(
          onTap: () {
            Getx.Get.back();
          },
          child: Container(
            width: Getx.Get.width,
            height: Getx.Get.height,
            // Creates insets from offsets from the left, top, right, and bottom.
            padding: EdgeInsets.fromLTRB(16, 24, 6, 10),
            alignment: Alignment.center,
            color: Colors.white,
            child: Center(
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: ExtendedText(
                    message.text,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // 是否支持全屏弹出，默认false
        isScrollControlled: true,
        enableDrag: false,
      );
    }
  }

  void _onMessageLongPress(BuildContext c1, types.Message message) async {
    if (message is types.FileMessage) {
      await OpenFile.open(message.uri);
    }
    var items = [
      MenuItem(
        title: '复制',
        textAlign: TextAlign.center,
        textStyle: TextStyle(
          color: Color(0xffc5c5c5),
          fontSize: 10.0,
        ),
        image: Icon(
          Icons.copy,
          color: Colors.white,
        ),
        userInfo: message,
      ),
      MenuItem(
        title: '转发',
        textAlign: TextAlign.center,
        textStyle: TextStyle(
          fontSize: 10.0,
          color: Colors.white,
        ),
        image: Icon(
          Icons.forward,
          color: Colors.white,
        ),
        userInfo: message,
      ),
      // MenuItem(
      //   title: '收藏',
      //   textAlign: TextAlign.center,
      //   textStyle: TextStyle(
      //     color: Color(0xffc5c5c5),
      //     fontSize: 10.0,
      //   ),
      //   image: Icon(
      //     Icons.collections_bookmark,
      //     color: Colors.white,
      //   ),
      //   userInfo: message,
      // ),
      // MenuItem(
      //   title: '多选',
      //   textAlign: TextAlign.center,
      //   textStyle: TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
      //   image: Icon(
      //     Icons.add_road,
      //     color: Colors.white,
      //   ),
      //   userInfo: message,
      // ),
      MenuItem(
        title: '引用',
        textAlign: TextAlign.center,
        textStyle: TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
        image: Icon(
          Icons.format_quote,
          color: Colors.white,
        ),
        userInfo: message,
      ),

      MenuItem(
        title: '删除',
        textAlign: TextAlign.center,
        textStyle: TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
        image: Icon(
          Icons.remove,
          color: Colors.white,
        ),
        userInfo: message,
      ),
    ];
    //
    bool isRevoked = (message is types.CustomMessage) &&
            message.metadata!['custom_type'] == 'revoked'
        ? true
        : false;
    if (message.author.id == UserRepoLocal.to.currentUid &&
        isRevoked == false) {
      items.add(
        MenuItem(
          title: '撤回',
          textAlign: TextAlign.center,
          textStyle: TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
          image: Icon(
            Icons.play_disabled,
            color: Colors.white,
          ),
          userInfo: message,
        ),
      );
    }
    PopupMenu menu = PopupMenu(
      // backgroundColor: Colors.teal,
      // lineColor: Colors.tealAccent,
      // maxColumn: 2,
      items: items,
      context: c1,
      onClickMenu: onClickMenu,
      // stateChanged: stateChanged,
      // onDismiss: onDismiss,
    );
    RenderBox renderBox = c1.findRenderObject() as RenderBox;
    var offset = renderBox.localToGlobal(Offset.zero);
    double l = offset.dx / 2 - renderBox.size.width / 2 + 75.0;
    double r = renderBox.size.width / 2 - 75.0;
    double dx = message.author.id == UserRepoLocal.to.currentUid ? r : l;
    debugPrint(">>>>> on chat _handleMessageTap left ${dx}, l: ${l}, r: ${r}");
    debugPrint(
        ">>>>> on chat _handleMessageTap dx:${offset.dx},dy:${offset.dy},w:${renderBox.size.width},h:${renderBox.size.height}");
    menu.show(
      rect: Rect.fromLTWH(
        dx,
        offset.dy,
        renderBox.size.width,
        renderBox.size.height,
      ),
    );
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = messages[index].copyWith(previewData: previewData);

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      setState(() {
        messages[index] = updatedMessage;
      });
    });
  }

  Future<bool> _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: logic.cuser,
      createdAt: DateTimeHelper.currentTimeMillis(),
      id: Xid().toString(),
      text: message.text,
      remoteId: widget.toId,
      status: types.Status.sending,
    );
    debugPrint(">>>>> on chat _handleSendPressed ${textMessage.toString()}");
    return await _addMessage(textMessage);
  }

  // 手指滑动 事件
  void _onPanUpdate(DragUpdateDetails e) async {}

  void _onMessageStatusTap(BuildContext ctx, types.Message msg) {
    if (msg.status != types.Status.sending) {
      return;
    }
    int diff = DateTimeHelper.currentTimeMillis() as int;
    if (diff > 1500) {
      // 检查为发送消息
      logic.sendWsMsg(logic.getMsgFromTmsg(
        widget.type!,
        widget.id,
        msg,
      ));
    }
    setState(() {
      messages;
    });
  }

  onClickMenu(MenuItemProvider item) async {
    MenuItem it = item as MenuItem;
    types.Message msg = it.userInfo as types.Message;
    if (it.menuTitle == "删除") {
      bool res = await logic.removeMessage(msg.id);
      if (res) {
        final index = messages.indexWhere((element) => element.id == msg.id);
        setState(() {
          messages.removeAt(index);
        });
      }
    } else if (it.menuTitle == "复制" && msg is types.TextMessage) {
      Clipboard.setData(ClipboardData(text: msg.text));
    } else if (it.menuTitle == "撤回") {
      await logic.revokeMessage(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    var rWidget = [
      new InkWell(
        child: new Image(image: AssetImage('assets/images/right_more.png')),
        onTap: () => Getx.Get.to(widget.type == 'GROUP'
            ? GroupDetailPage(
                widget.toId,
                callBack: (v) {},
              )
            : ChatInfoPage(widget.toId)),
      )
    ];

    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: new PageAppBar(
        title: newGroupName == "" ? widget.title : newGroupName,
        rightDMActions: rWidget,
      ),
      body: GestureDetector(
        //手指滑动
        onPanUpdate: _onPanUpdate,
        child: Chat(
          messages: messages,
          // showUserAvatars: true,
          // showUserNames: true,
          customMessageBuilder: (types.CustomMessage msg,
              {required int messageWidth}) {
            return CustomMessage(message: msg, messageWidth: messageWidth);
          },
          onEndReachedThreshold: 0.8,
          // 300000 = 5分钟 默认 900000 = 15 分钟
          dateHeaderThreshold: 300000,
          customDateHeaderText: (DateTime dt) =>
              DateTimeHelper.customDateHeader(dt),
          onEndReached: _handleEndReached,
          onAttachmentPressed: _handleAtachmentPressed,
          // onMessageTap: _handleMessageTap,
          onMessageDoubleTap: _onMessageDoubleTap,
          onMessageLongPress: _onMessageLongPress,
          onPreviewDataFetched: _handlePreviewDataFetched,
          onSendPressed: _handleSendPressed,
          onMessageStatusTap: _onMessageStatusTap,
          onMessageStatusLongPress: _onMessageStatusTap,
          hideBackgroundOnEmojiMessages: false,
          user: logic.cuser,
          theme: const ImboyChatTheme(),
          customBottomWidget: ChatInput(
            // 发送除非事件
            onSendPressed: _handleSendPressed,
            sendButtonVisibilityMode: SendButtonVisibilityMode.editing,
            onAttachmentPressed: _handleAtachmentPressed,
            voiceWidget: VoiceRecord(),
            extraWidget: ExtraItems(
              // 照片
              handleImageSelection: _handleImageSelection,
              // 文件
              handleFileSelection: _handleFileSelection,
              // 拍摄
              handlePickerSelection: _handlePickerSelection,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    Getx.Get.delete<ChatLogic>();

    //在页面销毁的时候一定要取消网络状态的监听
    // if (_connectivityResult != null &&
    //     _connectivityResult != ConnectivityResult.none) {
    //   debugPrint(">>> on chat_view dispose _connectivityResult: " +
    //       _connectivityResult.toString());
    //   _connectivityResult.cancle();
    // }
    super.dispose();
  }
}
