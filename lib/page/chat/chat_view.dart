import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
// import 'package:intl/date_symbol_data_local.dart';
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';
import 'package:uuid/uuid.dart';

import 'chat_logic.dart';

class ChatPage extends StatefulWidget {
  final int? id; // 会话ID
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

  @override
  void initState() {
    super.initState();
    initData();
    if (_msgStreamSubs == null) {
      // Register listeners for all events:
      _msgStreamSubs = eventBus.on<types.Message>().listen((e) async {
        debugPrint(">>>>> on MessageService chat_view initState: " +
            e.runtimeType.toString());

        if (e is types.Message && e.author.id == widget.toId) {
          setState(() {
            messages.insert(0, e);
          });
          _counter.decreaseConversationRemind(widget.toId, 1);
        }
      });
      _msgStreamSubs = eventBus.on<List<types.Message>>().listen((e) async {
        types.Message msg = e.first;
        int index = -1;
        for (var i = 0; i < messages.length; i++) {
          if (messages[i].id == msg.id) {
            index = i;
            break;
          }
        }
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
    if (_connectivityResult == null) {
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
  }

  void initData() async {
    if (!mounted) {
      return;
    }

    // 初始化 当前会话新增消息
    List<types.Message>? items = await logic.getMessages(widget.toId);
    debugPrint(">>>>> on _loadMessages msg: ${items.toString()}");
    if (items != null && items.length > 0) {
      setState(() {
        messages = items;
      });
    }
    // 消除消息提醒
    _counter.setConversationRemind(widget.toId, 0);
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

  void _handleMessageTap(types.Message message) async {
    if (message is types.FileMessage) {
      await OpenFile.open(message.uri);
    }
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
    _addMessage(textMessage);
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
          // bubbleBuilder: _bubbleBuilder,
          // textMessageBuilder: Obx(() => textMessageBuilder),
          onAttachmentPressed: _handleAtachmentPressed,
          onMessageTap: _handleMessageTap,
          onPreviewDataFetched: _handlePreviewDataFetched,
          onSendPressed: _handleSendPressed,
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
    //在页面销毁的时候一定要取消网络状态的监听
    if (_connectivityResult != null) {
      _connectivityResult.cancle();
    }
    super.dispose();
  }

  // 手指滑动 事件
  void _onPanUpdate(DragUpdateDetails e) async {
    if (_connectivityResult == ConnectivityResult.none) {
      Get.snackbar("Tips", "网络连接异常ws");
      return;
    }
    // 1秒内只能出发一次 TODO leeyi 2021-11-19 00:28:28
    // 检查为发送消息
    messages.forEach((obj) async {
      logic.sendWsMsg(logic.getMsgFromTmsg(widget.type!, widget.id!, obj));
      setState(() {
        messages;
      });
    });
  }
}
