import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:extended_text/extended_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/helper/datetime.dart';
import 'package:imboy/page/chat_info/chat_info_view.dart';
import 'package:imboy/page/group_detail/group_detail_view.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';
import 'package:popup_menu/popup_menu.dart';
import 'package:uuid/uuid.dart';

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
  final logic = Get.put(ChatLogic());

  final _counter = Get.put(MessageService());

  StreamSubscription<dynamic>? _msgStreamSubs;

  // 当前会话新增消息
  List<types.Message> messages = [];

  String newGroupName = "";

  var _connectivityResult;
  RxString _connectStateDescription = "".obs;

  int _page = 1;

  @override
  void initState() {
    //监听Widget是否绘制完毕
    super.initState();
    if (!mounted) {
      return;
    }
    _handleEndReached();

    if (_connectivityResult == null) {
      debugPrint(">>>>> on chat_view/initData _connectivityResult ");
      _connectivityResult = Connectivity()
          .onConnectivityChanged
          .listen((ConnectivityResult result) {
        if (result == ConnectivityResult.mobile) {
          _connectStateDescription.value = "手机网络";
          // setState(() {
          // });
        } else if (result == ConnectivityResult.wifi) {
          _connectStateDescription.value = "Wifi网络";
        } else {
          _connectStateDescription.value = "无网络";
        }
      });
    }

    if (_msgStreamSubs == null) {
      // Register listeners for all events:
      String toId = widget.toId;
      _msgStreamSubs = eventBus.on<types.Message>().listen((e) async {
        debugPrint(">>>>> on MessageService chat_view initState: " +
            e.runtimeType.toString());

        if (e is types.Message && e.author.id == toId) {
          setState(() {
            messages.insert(0, e);
          });
          _counter.decreaseConversationRemind(toId, 1);
        }
      });
      _msgStreamSubs = eventBus.on<List<types.Message>>().listen((e) async {
        types.Message msg = e.first;
        final index = messages.indexWhere((element) => element.id == msg.id);
        debugPrint(">>>>> on MessageService chat_view initState:$index; " +
            msg.toJson().toString());
        if (index > -1) {
          messages.setRange(index, index + 1, e);
          setState(() {
            messages;
          });
        }
      });
    }
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
            _counter.decreaseConversationRemind(widget.toId, 1);
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

  Future<void> _addMessage(types.Message message) async {
    // 先显示在聊天UI里面
    // 异步发送WS消息
    // 异步存储sqlite消息(未发送成功）
    //   发送成功后，更新conversation、更新消息状态
    //   发送失败后，放入异步队列，重新发送

    String cuid = logic.current.currentUid;
    ConversationModel cobj = await logic.addMessage(
      cuid,
      widget.toId,
      widget.avatar ?? '',
      widget.title!,
      widget.type!,
      message,
    );
    setState(() {
      messages.insert(0, message);
      _counter.conversations[widget.toId] = cobj;
    });
    // _counter.update();
  }

  void _handleAtachmentPressed() {
    Get.bottomSheet(
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
        id: const Uuid().v4(),
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

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);

      final message = types.ImageMessage(
        author: logic.cuser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        height: image.height.toDouble(),
        id: const Uuid().v4(),
        name: result.name,
        size: bytes.length,
        uri: result.path,
        width: image.width.toDouble(),
        remoteId: widget.toId,
        status: types.Status.sending,
      );

      _addMessage(message);
    }
  }

  void _onMessageDoubleTap(BuildContext c1, types.Message message) async {
    if (message is types.TextMessage) {
      Get.bottomSheet(
        Container(
          width: Get.width,
          height: Get.height,
          padding: EdgeInsets.fromLTRB(12, 10, 4, 10),
          color: Colors.white,
          child: Center(
            child: ExtendedText(
              message.text,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.black,
                fontSize: 32,
              ),
            ),
          ),
        ),
        isScrollControlled: true,
      );
    }
  }

  void _onMessageLongPress(BuildContext c1, types.Message message) async {
    if (message is types.FileMessage) {
      await OpenFile.open(message.uri);
    }
    PopupMenu menu = PopupMenu(
      // backgroundColor: Colors.teal,
      // lineColor: Colors.tealAccent,
      // maxColumn: 2,
      items: [
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
          title: '撤回',
          textAlign: TextAlign.center,
          textStyle: TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
          image: Icon(
            Icons.play_disabled,
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
      ],
      context: c1,
      onClickMenu: onClickMenu,
      // stateChanged: stateChanged,
      // onDismiss: onDismiss,
    );
    RenderBox renderBox = c1.findRenderObject() as RenderBox;
    var offset = renderBox.localToGlobal(Offset.zero);
    double l = offset.dx / 2 - renderBox.size.width / 2 + 75.0;
    double r = renderBox.size.width / 2 - 75.0;
    double dx = message.author.id == logic.current.currentUid ? r : l;
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

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: logic.cuser,
      createdAt: DateTimeHelper.currentTimeMillis(),
      id: const Uuid().v4(),
      text: message.text,
      remoteId: widget.toId,
      status: types.Status.sending,
    );
    debugPrint(">>>>> on chat _handleSendPressed ${textMessage.toString()}");
    _addMessage(textMessage);
  }

  // 手指滑动 事件
  void _onPanUpdate(DragUpdateDetails e) async {}

  void _onMessageStatusTap(types.Message msg) {
    if (msg.status != types.Status.sending) {
      return;
    }
    int diff = DateTimeHelper.currentTimeMillis();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    var rWidget = [
      new InkWell(
        child: new Image(image: AssetImage('assets/images/right_more.png')),
        onTap: () => Get.to(widget.type == 'GROUP'
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
          onEndReachedThreshold: 0.8,
          onEndReached: _handleEndReached,
          // bubbleBuilder: _bubbleBuilder,
          // textMessageBuilder: Obx(() => textMessageBuilder),
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<ChatLogic>();

    if (_msgStreamSubs != null) {
      _msgStreamSubs!.cancel();
      _msgStreamSubs = null;
    }
    debugPrint(">>>>> on chat_view/dispose _connectivityResult ");

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
