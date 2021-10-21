import 'dart:async';

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
  final String? id; // 用户ID
  final String? type; // [C2C | GROUP]
  final String? title;
  final String? avatar;

  ChatPage({
    required this.id,
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

  String newGroupName = "";

  @override
  void initState() {
    super.initState();
    initData();
    if (_msgStreamSubs == null) {
      // Register listeners for all events:
      _msgStreamSubs = eventBus.on<types.Message>().listen((e) async {
        debugPrint(
            ">>>>> on ws chat_view initState: " + e.runtimeType.toString());

        if (e is types.Message) {
          setState(() {
            _counter.messages.value.insert(0, e);
          });
        }
      });
    }
  }

  void initData() async {
    if (!mounted) {
      return;
    }
    List<types.Message>? messages = await logic.getMessages(widget.id!);
    debugPrint(">>>>> on _loadMessages msg: ${messages.toString()}");
    if (messages != null && messages.length > 0) {
      setState(() {
        _counter.messages.value = messages;
      });
    }
    // 消除消息提醒
    _counter.conversationMsgRemindCounters[widget.id!] = 0;
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
      widget.id!,
      widget.avatar ?? '',
      widget.title!,
      widget.type!,
      message,
      true,
    );
    setState(() {
      _counter.messages.value.insert(0, message);
      _counter.conversations[widget.id!] = cobj;
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
        author: logic.user,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: const Uuid().v4(),
        mimeType: lookupMimeType(result.files.single.path!),
        name: result.files.single.name,
        size: result.files.single.size,
        uri: result.files.single.path!,
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
        author: logic.user,
        createdAt: DateTimeHelper.currentTimeMillis(),
        height: image.height.toDouble(),
        id: const Uuid().v4(),
        name: result.name,
        size: bytes.length,
        uri: result.path,
        width: image.width.toDouble(),
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
    final index = _counter.messages.value
        .indexWhere((element) => element.id == message.id);
    final updatedMessage =
        _counter.messages.value[index].copyWith(previewData: previewData);

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      setState(() {
        _counter.messages.value[index] = updatedMessage;
      });
    });
  }

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: logic.user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
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
                widget.id ?? widget.title,
                callBack: (v) {},
              )
            : ChatInfoPage(widget.id!)),
      )
    ];

    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: new PageAppBar(
        title: newGroupName == "" ? widget.title : newGroupName,
        rightDMActions: rWidget,
      ),
      body: SafeArea(
        bottom: false,
        child: Chat(
          messages: _counter.messages,
          onAttachmentPressed: _handleAtachmentPressed,
          onMessageTap: _handleMessageTap,
          onPreviewDataFetched: _handlePreviewDataFetched,
          onSendPressed: _handleSendPressed,
          user: logic.user,
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
    super.dispose();
  }
}
