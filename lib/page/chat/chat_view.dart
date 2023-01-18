import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/picker_method.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/image_gallery/image_gallery_logic.dart';
import 'package:imboy/component/message/message.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/voice_record/voice_widget.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/page/chat_info/chat_info_view.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/group_detail/group_detail_view.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:imboy/store/provider/attachment_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:mime/mime.dart';
import 'package:niku/namespace.dart' as n;
import 'package:open_file/open_file.dart';
import 'package:photo_view/photo_view.dart';
import 'package:popup_menu/popup_menu.dart' as popupmenu;
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:xid/xid.dart';

import 'chat_logic.dart';
import 'widget/chat_input.dart';
// ignore: must_be_immutable
import 'widget/extra_item.dart';

// ignore: must_be_immutable
class ChatPage extends StatefulWidget {
  int conversationId; // 会话ID
  final String toId; // 用户ID
  final String type; // [C2C | GROUP]
  final String title;
  final String avatar;
  final String sign;

  ChatPage({
    Key? key,
    this.conversationId = 0,
    required this.toId,
    required this.title,
    required this.avatar,
    required this.sign,
    this.type = 'C2C',
  }) : super(key: key);
  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final logic = getx.Get.put(ChatLogic());
  final clogic = getx.Get.put(ConversationLogic());
  final gallerylogic = getx.Get.put(ImageGalleryLogic());

  bool _showAppBar = true;
  // 当前会话新增消息
  List<types.Message> messages = [];

  String newGroupName = "";

  int _page = 1;

  int get maxAssetsCount => 9;

  List<AssetEntity> assets = <AssetEntity>[];

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
    eventBus.on<types.Message>().listen((types.Message e) async {
      if (mounted && e.author.id == toId) {
        clogic.decreaseConversationRemind(toId, 1);
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

      if (msg is types.ImageMessage) {
        gallerylogic.pushToGallery(msg);
      }

      final index = messages.indexWhere((element) => element.id == msg.id);
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

  /// 用于分页(无限滚动)。当用户滚动时调用
  /// 到列表的最后(减去[onEndReachedThreshold])。
  Future<void> _handleEndReached() async {
    if (widget.conversationId == 0) {
      widget.conversationId = await clogic.createConversationId(
        widget.toId,
        widget.avatar,
        widget.title,
        widget.type,
      );
    }
    // 初始化 当前会话新增消息
    List<types.Message>? items = await logic.getMessages(
      widget.toId,
      _page,
      10,
    );
    List<String> msgIds = [];
    if (items != null && items.isNotEmpty) {
      // 消除消息提醒
      for (var msg in items) {
        if (msg is types.ImageMessage) {
          gallerylogic.pushToGallery(msg);
        }
        //enum Status { delivered, error, seen, sending, sent }
        if (msg.author.id == widget.toId && msg.status != types.Status.seen) {
          msgIds.add(msg.id);
        }
      }
      ConversationModel? cobj = msgIds.isNotEmpty
          ? await logic.markAsRead(widget.conversationId, msgIds)
          : null;
      if (cobj != null) {
        clogic.decreaseConversationRemind(widget.toId, msgIds.length);
        clogic.replace(cobj);
      }

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
    String type = widget.type == 'null' ? 'C2C' : widget.type;
    // debugPrint(">>> on _addMessage type :${type}");
    await logic.addMessage(
      UserRepoLocal.to.currentUid,
      widget.toId,
      widget.avatar,
      widget.title,
      type,
      message,
    );

    setState(() {
      messages.insert(0, message);
    });
    return true;
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
          author: logic.cuser,
          createdAt: DateTimeHelper.currentTimeMillis(),
          id: Xid().toString(),
          mimeType: lookupMimeType(result.files.single.path!),
          name: result.files.single.name,
          size: result.files.single.size,
          uri: uri,
          remoteId: widget.toId,
          status: types.Status.sending,
        );

        _addMessage(message);
      }, (DioError error) {
        debugPrint(">>> on upload ${error.toString()}");
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
      await AttachmentProvider.uploadImg("camera", entity, (
        Map<String, dynamic> resp,
        String imgUrl,
      ) async {
        double w = getx.Get.width;
        imgUrl += "&width=${w.toInt()}";

        if (entity.type == AssetType.image) {
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
        } else if (entity.type == AssetType.video) {
          Map<String, dynamic> metadata = {
            'custom_type': 'video',
            'thumb': (resp['thumb'] as EntityImage).toJson(),
            'video': (resp['video'] as EntityVideo).toJson(),
          };
          debugPrint(">>> on upload metadata: ${metadata.toString()}");
          final message = types.CustomMessage(
            author: logic.cuser,
            createdAt: DateTimeHelper.currentTimeMillis(),
            id: Xid().toString(),
            remoteId: widget.toId,
            status: types.Status.sending,
            metadata: metadata,
          );
          _addMessage(message);
        }
      }, (DioError error) {
        debugPrint(">>> on upload error ${error.toString()}");
      });
      if (mounted) {
        setState(() {});
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
    for (var entity in assets) {
      await AttachmentProvider.uploadImg("img", entity, (
        Map<String, dynamic> resp,
        String imgUrl,
      ) async {
        if (entity.type == AssetType.image) {
          double w = getx.Get.width;
          imgUrl += "&width=${w.toInt()}";

          debugPrint(">>> on upload imgUrl $imgUrl");
          debugPrint(">>> on upload $resp.toString()");

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
        } else if (entity.type == AssetType.video) {
          Map<String, dynamic> metadata = {
            'custom_type': 'video',
            'thumb': (resp['thumb'] as EntityImage).toJson(),
            'video': (resp['video'] as EntityVideo).toJson(),
          };
          debugPrint(">>> on upload metadata: ${metadata.toString()}");
          final message = types.CustomMessage(
            author: logic.cuser,
            createdAt: DateTimeHelper.currentTimeMillis(),
            id: Xid().toString(),
            remoteId: widget.toId,
            status: types.Status.sending,
            metadata: metadata,
          );
          _addMessage(message);
        }
        assets.removeAt(
          assets.indexWhere((element) => element.id == entity.id),
        );
      }, (DioError error) {
        debugPrint(">>> on upload ${error.toString()}");
      });
    }
  }

  void _handleVoiceSelection(AudioFile? obj) async {
    if (obj == null) {
      return;
    }
    await AttachmentProvider.uploadFile('audio', obj.file, (
      Map<String, dynamic> resp,
      String uri,
    ) async {
      Map<String, dynamic> metadata = {
        'custom_type': 'audio',
        'uri': uri,
        'size': (await obj.file.readAsBytes()).length,
        'duration_ms': obj.duration.inMilliseconds,
        // 'wave_form': obj.waveForm,
        'mime_type': obj.mimeType,
      };
      debugPrint("> on upload metadata: ${metadata.toString()}");
      final message = types.CustomMessage(
        author: logic.cuser,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: Xid().toString(),
        remoteId: widget.toId,
        status: types.Status.sending,
        metadata: metadata,
      );

      obj.file.delete(recursive: true);
      _addMessage(message);
    }, (DioError error) {
      debugPrint(">>> on upload ${error.toString()}");
    }, process: false);

  }

  void _onMessageDoubleTap(BuildContext c1, types.Message message) async {
    if (message is types.TextMessage) {
      getx.Get.bottomSheet(
        InkWell(
          onTap: () {
            getx.Get.back();
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(0.0),
            height: double.infinity,
            // Creates insets from offsets from the left, top, right, and bottom.
            padding: const EdgeInsets.fromLTRB(16, 28, 0, 10),
            alignment: Alignment.center,
            color: Colors.white,
            child: Center(
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Text(
                    message.text,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 24,
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
    } else if (message is types.FileMessage) {
      File? tmpF = await DefaultCacheManager().getSingleFile(message.uri);
      await OpenFile.open(tmpF.path);
    } else if (message is types.ImageMessage) {
      gallerylogic.onImagePressed(message);
      setState(() {
        _showAppBar = false;
      });
    }
  }

  void _onMessageLongPress(BuildContext c1, types.Message message) async {
    if (message is types.FileMessage) {
      await OpenFile.open(message.uri);
    }
    var items = [
      popupmenu.MenuItem(
        // id: 'copy', // TODO 2023-01-11 为了支持多语言需要新增id参数
        title: '复制',
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          color: Color(0xffc5c5c5),
          fontSize: 10.0,
        ),
        image: const Icon(
          Icons.copy,
          color: Colors.white,
        ),
        userInfo: message,
      ),
      popupmenu.MenuItem(
        title: '转发',
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          fontSize: 10.0,
          color: Colors.white,
        ),
        image: const Icon(
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
      popupmenu.MenuItem(
        title: '引用',
        textAlign: TextAlign.center,
        textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
        image: const Icon(
          Icons.format_quote,
          color: Colors.white,
        ),
        userInfo: message,
      ),

      popupmenu.MenuItem(
        title: '删除',
        textAlign: TextAlign.center,
        textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
        image: const Icon(
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
        popupmenu.MenuItem(
          title: '撤回',
          textAlign: TextAlign.center,
          textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
          image: const Icon(
            Icons.play_disabled,
            color: Colors.white,
          ),
          userInfo: message,
        ),
      );
    }
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
    RenderBox renderBox = c1.findRenderObject() as RenderBox;
    var offset = renderBox.localToGlobal(Offset.zero);
    double l = offset.dx / 2 - renderBox.size.width / 2 + 75.0;
    double r = renderBox.size.width / 2 - 75.0;
    double dx = message.author.id == UserRepoLocal.to.currentUid ? r : l;
    debugPrint(
        ">>> on chat _handleMessageTap dx:${offset.dx},dy:${offset.dy},w:${renderBox.size.width},h:${renderBox.size.height}");
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
    final updatedMessage = (messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      messages[index] = updatedMessage;
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
    return await _addMessage(textMessage);
  }

  void _onMessageStatusTap(BuildContext ctx, types.Message msg) {
    if (msg.status != types.Status.sending) {
      return;
    }
    int diff = DateTimeHelper.currentTimeMillis() - msg.createdAt!;
    if (diff > 800) {
      // 检查为发送消息
      logic.sendWsMsg(logic.getMsgFromTmsg(
        widget.type,
        widget.conversationId,
        msg,
      ));
      setState(() {
        messages;
      });
    }
  }

  onClickMenu(popupmenu.MenuItemProvider item) async {
    popupmenu.MenuItem it = item as popupmenu.MenuItem;
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
      InkWell(
        child: const Image(image: AssetImage('assets/images/right_more.png')),
        onTap: () => getx.Get.to(widget.type == 'GROUP'
            ? GroupDetailPage(
                widget.toId,
                callBack: (v) {},
              )
            : ChatInfoPage(widget.toId)),
      )
    ];
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: _showAppBar
          ? PageAppBar(
              title: newGroupName == "" ? widget.title : newGroupName,
              rightDMActions: rWidget,
            )
          : null,
      body: n.Stack(
        [
          Chat(
            user: logic.cuser,
            messages: messages,
            // showUserAvatars: true,
            // showUserNames: true,
            customMessageBuilder: (types.CustomMessage msg,
                {required int messageWidth}) {
              return CustomMessageBuilder(
                message: msg,
              );
            },
            onEndReachedThreshold: 0.8,
            // 300000 = 5分钟 默认 900000 = 15 分钟
            dateHeaderThreshold: 300000,
            customDateHeaderText: (DateTime dt) =>
                DateTimeHelper.customDateHeader(dt),
            onEndReached: _handleEndReached,
            onBackgroundTap: () {
              // 收起输聊天底部弹出框
              AnimationController _bottomHeightController = getx.Get.find();
              _bottomHeightController.animateBack(0);
            },
            onMessageTap: (BuildContext c1, types.Message message) async {
              if (message is types.ImageMessage) {
                gallerylogic.onImagePressed(message);
                setState(() {
                  _showAppBar = false;
                });
              } else if (message is types.FileMessage) {
                File? tmpF =
                    await DefaultCacheManager().getSingleFile(message.uri);
                await OpenFile.open(tmpF.path);
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
            // debugPrint(">>> on chatinput onTextFieldTap");
            // },
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
                  options: {
                    "to": widget.toId,
                    "title": widget.title,
                    "avatar": widget.avatar,
                    "sign": widget.sign,
                  }),
            ),
            // 禁用 flutter_chat_ui 的相册
            disableImageGallery: true,
          ),
          if (gallerylogic.isImageViewVisible.isTrue)
            IMBoyImageGallery(
              images: gallerylogic.gallery.value,
              pageController: gallerylogic.galleryPageController!,
              onClosePressed: () {
                debugPrint(">>> on onClosePressed ");
                gallerylogic.onCloseGalleryPressed();
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
      ),
    );
  }

  @override
  void dispose() {
    getx.Get.delete<ChatLogic>();

    super.dispose();
  }
}
