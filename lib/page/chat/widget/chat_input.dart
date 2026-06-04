import 'package:imboy/i18n/strings.g.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/chat/mention_model.dart';
import 'package:imboy/component/chat/mention_list_widget.dart';
import 'package:imboy/component/chat/mention_text_formatter.dart';
import 'package:imboy/component/chat/mention_provider.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/page/chat/widget/quick_reply_manage_page.dart';
import 'package:imboy/service/quick_reply_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 生产环境的 [QuickReplyStore] 适配器：桥接项目已有的 [StorageService]。
///
/// 不放在 `quick_reply_service.dart` 里是为了保持 domain 层纯测试（不
/// 传递依赖 StorageService → config/init.dart 等单例链）。
class _StorageServiceQuickReplyStore implements QuickReplyStore {
  const _StorageServiceQuickReplyStore();

  @override
  Future<String?> getString(String key) async {
    final v = StorageService.to.getString(key);
    return v.isEmpty ? null : v;
  }

  @override
  Future<void> setString(String key, String value) async {
    await StorageService.to.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await StorageService.to.remove(key);
  }
}

/// 键盘高度观察者
class _KeyboardObserver with WidgetsBindingObserver {
  final VoidCallback onKeyboardChanged;

  _KeyboardObserver(this.onKeyboardChanged);

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    onKeyboardChanged();
  }
}

/// 部分代码来自该项目，感谢作者 CaiJingLong https://github.com/CaiJingLong/flutter_like_wechat_input
/// 输入类型枚举
enum InputType {
  text, // 文本输入
  voice, // 语音输入
  emoji, // 表情输入
  extra, // 附加功能
}

/// 发送按钮显示模式
enum SendButtonVisibilityMode {
  editing, // 编辑时显示
  always, // 始终显示
}

/// 聊天输入框组件
class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.type,
    required this.peerId,
    required this.onSendPressed,
    required this.composerHeight,
    this.isAttachmentUploading,
    this.onAttachmentPressed,
    this.onTextChanged,
    this.onTextFieldTap,
    this.extraWidget,
    this.voiceWidget,
    this.quoteTipsWidget,
    this.sendButtonVisibilityMode = SendButtonVisibilityMode.editing,
    this.handleSafeArea = true,
    this.backgroundColor,
    this.hintText = 'Type a message',
    this.keyboardAppearance,
    this.autocorrect = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.sentences,
    this.keyboardType = TextInputType.multiline,
    this.textInputAction = TextInputAction.newline,
    this.maxLines = 6,
    this.minLines = 1,
    this.maxLength = 1000,
    this.contentInsertionConfiguration,
    // @提及功能回调
    this.onMentionsChanged,
    // 禁言状态
    this.isMuted = false,
    this.muteMessage,
  });

  final String type; // 聊天类型
  final String peerId; // 对方ID
  final bool? isAttachmentUploading; // 附件是否正在上传
  final VoidCallback? onAttachmentPressed; // 附件按钮点击事件
  final Future<bool> Function(String) onSendPressed; // 发送按钮回调
  final void Function(String)? onTextChanged; // 文本变更回调
  final void Function()? onTextFieldTap; // 输入框点击回调
  final SendButtonVisibilityMode sendButtonVisibilityMode; // 发送按钮模式
  final Widget? extraWidget; // 扩展面板
  final Widget? voiceWidget; // 语音输入组件
  final Widget? quoteTipsWidget; // 引用消息条
  final bool? handleSafeArea; // 是否处理安全区
  final Color? backgroundColor; // 背景色
  final String? hintText; // 输入框提示语
  final Brightness? keyboardAppearance; // 键盘主题
  final bool? autocorrect; // 是否自动校正
  final bool autofocus; // 是否自动获取焦点
  final TextCapitalization textCapitalization; // 首字母大写策略
  final TextInputType? keyboardType; // 键盘类型
  final TextInputAction? textInputAction; // 键盘回车行为
  final int? maxLines; // 最大行数
  final int? minLines; // 最小行数
  final int? maxLength; // 最大输入长度
  final ValueNotifier<double> composerHeight; // 外部传递的输入区高度notifier（用于丝滑动画）
  final ContentInsertionConfiguration? contentInsertionConfiguration; // 内容插入配置
  /// @提及变更回调
  final void Function(List<String> mentionIds)? onMentionsChanged;

  /// 是否被禁言
  final bool isMuted;

  /// 禁言提示文案（如"你已被禁言，剩余 X 分钟"）
  final String? muteMessage;

  @override
  State<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  final _inputFocusNode = FocusNode(); // 输入框焦点
  final _keyboardListenerFocusNode = FocusNode(); // 键盘监听器焦点
  final _textController = TextEditingController(); // 文本输入控制器

  // 公开内部方法供外部调用
  FocusNode get inputFocusNode => _inputFocusNode;
  TextEditingController get textController => _textController;
  late AnimationController _bottomHeightController; // 兼容旧动画逻辑
  late String draftKey; // 草稿key
  late String draftCursorKey; // C3: 草稿光标位置 key
  Timer? _debounceTimer;

  final _emojiShowing = ValueNotifier<bool>(false); // 是否显示表情面板
  final _inputType = ValueNotifier<InputType>(InputType.text); // 当前输入类型
  final _sendButtonVisible = ValueNotifier<bool>(false); // 发送按钮可见性
  final _characterCount = ValueNotifier<int>(0); // 字符计数
  final _isFocused = ValueNotifier<bool>(false); // 输入框聚焦状态
  final _showMentionList = ValueNotifier<bool>(false); // 是否显示@提及列表
  final _mentionKeyword = ValueNotifier<String>(''); // @提及搜索关键词
  final _showQuickReplies = ValueNotifier<bool>(false); // 是否显示快捷回复
  // S2: 快捷回复短语支持用户持久化自定义。初始为空，initState 从
  // QuickReplyService 加载（未持久化时自动填入 _defaultQuickReplies）。
  final _quickReplies = ValueNotifier<List<String>>(const []);

  /// @提及数据（用于跟踪文本中的 @提及）
  MentionData _mentionData = const MentionData();

  /// 是否已加载群成员
  bool _membersLoaded = false;

  final double iconSize = 40; // 图标大小
  final double _softKeyHeight = 270; // 软键盘默认高度

  /// 字体大小（Web 兼容）
  double get fontSize => 22 * (Platform.isIOS ? 1.2 : 1.0);

  double _keyboardHeight = 0; // 当前键盘高度
  bool _isTransitioningToTextFromPanel = false; // 是否正在从面板切换回文本（用于丝滑动画）

  ThemeNotifier get _themeNotifier =>
      ProviderScope.containerOf(context).read(themeProvider.notifier);
  Color _themeColor(String key) => _themeNotifier.getThemeColor(key);
  double _themeFontSize(FontSizeType type) =>
      _themeNotifier.getFontSize(type, context: context);

  @override
  void initState() {
    super.initState();
    draftKey = "draft${widget.type}_${widget.peerId}";
    draftCursorKey = "draftCursor${widget.type}_${widget.peerId}";

    _initTextController();
    _initAnimationController();
    _initEventListeners();
    _initFocusListener();
    _initMentionListener();

    // S2: 加载用户自定义快捷回复；未持久化时返回内置默认
    unawaited(_loadQuickReplies());

    _setupKeyboardListener();

    // 如果是群聊，加载群成员列表
    if (widget.type == 'C2G') {
      _loadGroupMembers();
    }
  }

  /// 加载群成员列表
  Future<void> _loadGroupMembers() async {
    if (widget.peerId.isEmpty || _membersLoaded) return;

    // 使用 ProviderScope.containerOf 获取 ProviderContainer
    final container = ProviderScope.containerOf(context);
    await container
        .read(mentionNotifierProvider.notifier)
        .loadGroupMembers(widget.peerId);
    _membersLoaded = true;
  }

  /// S2: 默认快捷回复（i18n；首次使用时填充到存储）
  List<String> get _defaultQuickReplies => [
    t.common.quickReplyOk,
    t.chat.quickReplyReceived,
    t.chat.quickReplyThanks,
    t.common.understood,
    t.chat.quickReplyWait,
    t.common.noProblem,
    t.common.onMyWay,
    t.common.quickReplyOkThanks,
  ];

  /// S2: 从 StorageService 加载当前用户的快捷回复列表到 _quickReplies。
  /// 未持久化时返回内置默认。适配器 [_StorageServiceQuickReplyStore] 桥接
  /// 项目已有的 [StorageService]。
  Future<void> _loadQuickReplies() async {
    final uid = UserRepoLocal.to.currentUid;
    if (uid.isEmpty) {
      // 未登录态安全兜底，避免 key=quick_replies: 污染
      _quickReplies.value = _defaultQuickReplies;
      return;
    }
    final service = QuickReplyService(
      const _StorageServiceQuickReplyStore(),
      defaults: _defaultQuickReplies,
    );
    final list = await service.load(uid);
    if (mounted) {
      _quickReplies.value = list;
    }
  }

  /// 初始化文本控制器（监听输入变化、控制发送按钮显隐）
  void _initTextController() {
    if (widget.sendButtonVisibilityMode == SendButtonVisibilityMode.editing) {
      _sendButtonVisible.value = _textController.text.trim().isNotEmpty;
      _textController.addListener(_handleTextControllerChange);
    } else {
      _sendButtonVisible.value = true;
    }
  }

  /// 初始化动画控制器（用于底部面板展开/收起动画，实际已被丝滑高度控制替代）
  void _initAnimationController() {
    _bottomHeightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _bottomHeightController.animateBack(0);
  }

  /// 初始化焦点监听器
  void _initFocusListener() {
    _inputFocusNode.addListener(() {
      _isFocused.value = _inputFocusNode.hasFocus;
      if (_inputFocusNode.hasFocus) {
        updateState(InputType.text);
      }
    });
  }

  /// 初始化事件监听器（输入框获取焦点自动切回文本模式）
  void _initEventListeners() {
    /// 加载本地草稿（避免信息丢失提升用户体验）
    final draft = StorageService.to.getString(draftKey);
    if (draft.isNotEmpty) {
      _setText(draft);
      // C3: 恢复上次离开时的光标位置（clamp 到合法区间，防止数据损坏）
      final cursorStr = StorageService.to.getString(draftCursorKey);
      final cursor = int.tryParse(cursorStr);
      if (cursor != null) {
        final clamped = cursor.clamp(0, _textController.text.length);
        _textController.selection = TextSelection.collapsed(offset: clamped);
      }
    }

    // 监听输入框焦点变化，自动切换到文本输入模式
    // 已移至 _initFocusListener()
  }

  /// 设置键盘监听器（获取键盘高度，兼容多机型，动态设置输入区高度实现丝滑）
  void _setupKeyboardListener() {
    // 立即检查一次键盘状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mediaQuery = MediaQuery.of(context);
      final newKeyboardHeight = mediaQuery.viewInsets.bottom;

      if (newKeyboardHeight != _keyboardHeight) {
        _keyboardHeight = newKeyboardHeight;
        _updateComposerHeightByKeyboard();
      }
    });

    // 监听后续的键盘变化
    WidgetsBinding.instance.addObserver(
      _KeyboardObserver(_updateComposerHeightByKeyboard),
    );
  }

  /// 处理键盘快捷键
  void _handleKeyboardShortcuts(KeyEvent event) {
    if (event is KeyDownEvent) {
      final logicalKey = event.logicalKey;

      // Command/Ctrl + Enter 发送消息
      if (HardwareKeyboard.instance.isControlPressed &&
          logicalKey == LogicalKeyboardKey.enter) {
        _handleSendPressed();
      }

      // Escape 键收起键盘和面板
      if (logicalKey == LogicalKeyboardKey.escape) {
        hideAllPanel();
      }

      // Command/Ctrl + K 切换输入模式
      if (HardwareKeyboard.instance.isControlPressed &&
          logicalKey == LogicalKeyboardKey.keyK) {
        updateState(
          _inputType.value == InputType.text ? InputType.voice : InputType.text,
        );
      }
    }
  }

  /// 根据系统键盘/自定义面板动态设置输入区高度
  /// 优化版本：快速响应，减少延迟
  void _updateComposerHeightByKeyboard() {
    if (!mounted) return;

    // 触发重绘，以便 build 方法中重新计算 panelHeight
    setState(() {});
  }

  /// 初始化@提及监听器
  void _initMentionListener() {
    _textController.addListener(_handleMentionDetection);
  }

  /// 处理@提及检测
  void _handleMentionDetection() {
    // 只在群聊中启用 @提及功能
    if (widget.type != 'C2G') {
      _showMentionList.value = false;
      return;
    }

    final text = _textController.text;
    final selection = _textController.selection;

    // 使用工具方法检测 @提及 触发
    final (show, keyword) = MentionTextEditorHelper.detectMentionTrigger(
      text,
      selection,
    );

    if (show) {
      _showMentionList.value = true;
      _mentionKeyword.value = keyword;
      // 更新 Provider 中的关键词
      try {
        final container = ProviderScope.containerOf(context);
        container.read(mentionNotifierProvider.notifier).updateKeyword(keyword);
      } catch (_) {
        // Provider 可能未初始化，忽略
      }
    } else {
      _showMentionList.value = false;
      _mentionKeyword.value = '';
    }

    // 根据光标位置更新 @提及数据（处理删除操作）
    _mentionData = _mentionData.removeByCursorPosition(selection.extentOffset);
    _notifyMentionsChanged();
  }

  /// 处理选择 @提及候选项
  void _handleMentionSelected(MentionCandidate candidate) {
    final text = _textController.text;
    final selection = _textController.selection;

    // 使用工具方法插入 @提及
    final newValue = MentionTextEditorHelper.insertMention(
      text: text,
      selection: selection,
      candidate: candidate,
    );

    // 记录 @提及数据
    final atIndex = text.lastIndexOf('@', selection.extentOffset - 1);
    if (atIndex != -1) {
      final displayName = candidate.displayName;
      final endPos = atIndex + displayName.length + 2;
      final userId = candidate.isAllMention ? 'all' : candidate.userId;

      _mentionData = _mentionData.addMention(userId, atIndex, endPos);
      _notifyMentionsChanged();
    }

    _textController.value = newValue;
    _showMentionList.value = false;
    _mentionKeyword.value = '';
  }

  /// 通知 @提及变更
  void _notifyMentionsChanged() {
    widget.onMentionsChanged?.call(_mentionData.mentionIds);
  }

  /// 构建快捷回复面板
  Widget _buildQuickRepliesPanel() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showQuickReplies,
      builder: (context, showQuickReplies, _) {
        if (!showQuickReplies) return const SizedBox.shrink();

        return ValueListenableBuilder<List<String>>(
          valueListenable: _quickReplies,
          builder: (context, replies, _) {
            return Container(
              height: 60,
              decoration: BoxDecoration(
                color: _themeColor('surface'),
                border: Border(
                  top: BorderSide(
                    color: _themeColor('outline').withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                // S2-b: 末尾追加"管理"入口（settings icon 按钮）
                itemCount: replies.length + 1,
                itemBuilder: (context, index) {
                  if (index == replies.length) {
                    // 管理按钮
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: IconButton(
                        tooltip: t.chat.quickReplyManage,
                        icon: Icon(Icons.tune, color: _themeColor('primary')),
                        onPressed: _openQuickReplyManage,
                      ),
                    );
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => _insertQuickReply(replies[index]),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _themeColor(
                          'primary',
                        ).withValues(alpha: 0.1),
                        foregroundColor: _themeColor('primary'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderRadiusRegular,
                        ),
                        elevation: 0,
                      ),
                      child: Text(replies[index]),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// S2-b: 打开快捷回复管理页；返回后刷新 _quickReplies（反映用户增删改）
  Future<void> _openQuickReplyManage() async {
    final currentDefaults = _defaultQuickReplies;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuickReplyManagePage(defaults: currentDefaults),
      ),
    );
    if (!mounted) return;
    await _loadQuickReplies();
  }

  /// 插入快捷回复
  void _insertQuickReply(String reply) {
    _textController.text = reply;
    _sendButtonVisible.value = true;
    _showQuickReplies.value = false;
  }

  /// 构建@提及列表
  Widget _buildMentionList() {
    // 只在群聊中显示 @提及列表
    if (widget.type != 'C2G') {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _showMentionList,
      builder: (context, showMentionList, _) {
        if (!showMentionList) return const SizedBox.shrink();

        return ValueListenableBuilder<String>(
          valueListenable: _mentionKeyword,
          builder: (context, keyword, _) {
            // 使用 Builder 获取 ProviderContainer
            return Builder(
              builder: (context) {
                // 从 ProviderContainer 获取状态
                final container = ProviderScope.containerOf(context);
                final mentionState = container.read(mentionNotifierProvider);

                return MentionListWidget(
                  candidates: mentionState.candidates,
                  keyword: keyword,
                  showAllMention: mentionState.showAllMention,
                  isAdmin: mentionState.isAdmin,
                  onSelected: _handleMentionSelected,
                  maxHeight: 180,
                );
              },
            );
          },
        );
      },
    );
  }

  /// 处理文本控制器变化（带节流，存储草稿，发送文本变更回调）
  void _handleTextControllerChange() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final text = _textController.text.trim();
      _sendButtonVisible.value = text.isNotEmpty;
      _characterCount.value = text.characters.length;

      // 超长自动裁剪并存储草稿
      if (text.length <= (widget.maxLength ?? 1000)) {
        StorageService.to.setString(draftKey, _textController.text);
        // C3: 同步保存光标位置（baseOffset 可能为 -1 表示无 selection，忽略）
        final baseOffset = _textController.selection.baseOffset;
        if (baseOffset >= 0) {
          StorageService.to.setString(draftCursorKey, baseOffset.toString());
        }
      }

      widget.onTextChanged?.call(_textController.text);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inputFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    _textController.dispose();
    _bottomHeightController.dispose();
    _emojiShowing.dispose();
    _inputType.dispose();
    _sendButtonVisible.dispose();
    _characterCount.dispose();
    _isFocused.dispose();
    _showMentionList.dispose();
    _mentionKeyword.dispose();
    _showQuickReplies.dispose();
    _quickReplies.dispose();

    // 清理 @提及状态
    if (widget.type == 'C2G') {
      try {
        final container = ProviderScope.containerOf(context);
        container.read(mentionNotifierProvider.notifier).clear();
      } catch (_) {
        // Provider 可能未初始化，忽略
      }
    }

    super.dispose();
  }

  /// 设置文本内容（支持emoji安全插入/裁剪，保持光标位置）
  void _setText(String insertText) {
    final maxLength = widget.maxLength ?? 1000;
    final oldValue = _textController.value;

    int start = oldValue.selection.start;
    int end = oldValue.selection.end;

    // 边界校验，防止崩溃
    if (start < 0 ||
        end < 0 ||
        start > oldValue.text.length ||
        end > oldValue.text.length) {
      start = end = oldValue.text.length;
    }

    String newText = oldValue.text.replaceRange(start, end, insertText);

    // emoji安全长度判断
    if (newText.characters.length > maxLength) {
      final allowInsertLength =
          maxLength - (oldValue.text.characters.length - (end - start));
      if (allowInsertLength <= 0) return;
      insertText = insertText.characters.take(allowInsertLength).toString();
      newText = oldValue.text.replaceRange(start, end, insertText);
    }
    if (newText.length > maxLength) {
      final allowInsertLength =
          maxLength - (oldValue.text.length - (end - start));
      if (allowInsertLength <= 0) return;
      insertText = insertText.substring(0, allowInsertLength);
      newText = oldValue.text.replaceRange(start, end, insertText);
    }
    final offset = start + insertText.length;
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  /// 公开的设置文本方法，供外部调用
  void setText(String text) {
    _textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// 处理发送按钮点击（异步发送，草稿清理，安全判断 mounted）
  Future<void> _handleSendPressed() async {
    final trimmedText = _textController.text.trim();
    iPrint('📤 [ChatInput._handleSendPressed] 开始: text="$trimmedText"');
    if (trimmedText.isNotEmpty) {
      iPrint('📤 [ChatInput._handleSendPressed] 调用 widget.onSendPressed');
      final res = await widget.onSendPressed(trimmedText);
      iPrint('📤 [ChatInput._handleSendPressed] onSendPressed 返回: $res');
      if (!mounted) return; // 异步gap后安全检查
      if (res) {
        _textController.clear();
        StorageService.to.remove(draftKey);
        StorageService.to.remove(draftCursorKey); // C3: 同步清除光标位置
        // 清空 @提及数据
        _mentionData = const MentionData();
        _notifyMentionsChanged();
        iPrint('✅ [ChatInput._handleSendPressed] 发送成功，已清空输入框');
        // 发送后自动收起键盘
        FocusScope.of(context).unfocus();
      } else {
        iPrint('⚠️ [ChatInput._handleSendPressed] 发送失败，保留输入框内容');
      }
    } else {
      iPrint('⚠️ [ChatInput._handleSendPressed] 输入为空，跳过发送');
    }
  }

  /// 统一对外收起所有面板（键盘、emoji、extra），并让输入区高度归零
  void hideAllPanel() {
    FocusScope.of(context).unfocus();
    _inputType.value = InputType.text;
    _emojiShowing.value = false;
  }

  /// 对外提供unfocus方法，用于收起输入框和面板
  void unfocus() {
    hideAllPanel();
  }

  /// 获取当前消息的 @提及 ID 列表
  List<String> getMentionIds() {
    return _mentionData.mentionIds;
  }

  /// 获取当前消息的 @提及数据
  MentionData getMentionData() {
    return _mentionData;
  }

  /// 手动触发 @提及列表（供外部调用）
  void showMentionPicker() {
    if (widget.type == 'C2G') {
      // 在光标位置插入 @ 符号
      final text = _textController.text;
      final selection = _textController.selection;
      final newText = text.replaceRange(selection.start, selection.end, '@');
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + 1),
      );
      // 触发 @提及 检测
      _handleMentionDetection();
    }
  }

  /// 切换输入类型（文本/语音/表情/扩展面板），优化版本：实现键盘高度锁定 (Height Locking) 消除闪烁
  Future<void> updateState(InputType type) async {
    if (type == _inputType.value) return;

    final oldType = _inputType.value;
    _inputType.value = type;
    _emojiShowing.value = type == InputType.emoji;

    if (type == InputType.text) {
      // 切换到文本输入，先收起面板，再唤起键盘
      if (oldType == InputType.emoji || oldType == InputType.extra) {
        _isTransitioningToTextFromPanel = true;
      }

      _updateComposerHeightByKeyboard(); // 先更新高度
      // 立即请求焦点，不使用 await 延迟，减少空白闪烁
      if (mounted) {
        FocusScope.of(context).requestFocus(_inputFocusNode);
      }
    } else if (type == InputType.voice) {
      // 切换到语音模式，收起所有面板
      FocusScope.of(context).unfocus();
      // 等待键盘收起的微小延迟
      await Future<dynamic>.delayed(const Duration(milliseconds: 50));
      _updateComposerHeightByKeyboard();
    } else {
      // 切换到emoji/extra：不等待键盘收起，直接展示面板（利用已缓存的 _keyboardHeight 作为 panelHeight）
      // 这就是业界标杆的“高度锁定”机制，消除切换闪烁
      FocusScope.of(context).unfocus();

      if (mounted) {
        // 直接重建，因为面板的高度会使用刚才锁定的键盘高度
        setState(() {});
      }
    }
  }

  /// 构建底部容器（emoji/扩展面板，带动画）—— 丝滑高度逻辑
  Widget _buildBottomContainer({
    required Widget child,
    required double height,
  }) {
    // 如果高度为0，且不显示，则隐藏（避免点击穿透等问题）
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 面板区域消费手势，避免向上冒泡触发返回/侧滑
        onTap: () {}, // 故意留空：仅用于消费 tap 手势，不执行任何动作
        child: child,
      ),
    );
  }

  /// 构建底部项目（emoji/扩展面板内容）
  Widget _buildBottomItems() {
    return ValueListenableBuilder<InputType>(
      valueListenable: _inputType,
      builder: (context, inputType, _) {
        if (inputType == InputType.extra) {
          // 扩展功能面板
          return widget.extraWidget ?? const Center(child: Text("Extra Items"));
        } else if (inputType == InputType.emoji) {
          final columns = MediaQuery.of(context).size.width ~/ (fontSize + 10);
          return ValueListenableBuilder<bool>(
            valueListenable: _emojiShowing,
            builder: (context, emojiShowing, _) {
              return Offstage(
                offstage: !emojiShowing,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // 面板命中不穿透，避免触发外层返回/侧滑
                  child: EmojiPicker(
                    onEmojiSelected: (Category? category, Emoji emoji) {
                      _setText(emoji.emoji);
                    },
                    onBackspacePressed: () {
                      if (_textController.text.isNotEmpty) {
                        _textController
                          ..text = _textController.text.characters
                              .skipLast(1)
                              .toString()
                          ..selection = TextSelection.fromPosition(
                            TextPosition(offset: _textController.text.length),
                          );
                      }
                    },
                    config: Config(
                      checkPlatformCompatibility: true,
                      emojiViewConfig: EmojiViewConfig(
                        columns: columns,
                        emojiSizeMax: fontSize,
                        verticalSpacing: 0,
                        horizontalSpacing: 4,
                        recentsLimit: columns * 3 - 2,
                        buttonMode: ButtonMode.MATERIAL,
                        backgroundColor: _themeColor('surface'),
                      ),
                      skinToneConfig: SkinToneConfig(
                        indicatorColor: _themeColor('surface'),
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        tabBarHeight: 48,
                        backgroundColor: _themeColor('surface'),
                        iconColor: _themeColor('textSecondary'),
                        iconColorSelected: _themeColor('primary'),
                        indicatorColor: _themeColor('primary'),
                        categoryIcons: const CategoryIcons(
                          recentIcon: Icons.access_time_outlined,
                          smileyIcon: Icons.emoji_emotions_outlined,
                          animalIcon: Icons.cruelty_free_outlined,
                          foodIcon: Icons.coffee_outlined,
                          activityIcon: Icons.sports_soccer_outlined,
                          travelIcon: Icons.directions_car_filled_outlined,
                          objectIcon: Icons.lightbulb_outline,
                          symbolIcon: Icons.emoji_symbols_outlined,
                          flagIcon: Icons.flag_outlined,
                        ),
                      ),
                      bottomActionBarConfig: BottomActionBarConfig(
                        enabled: true,
                        backgroundColor: _themeColor('surface'),
                        buttonColor: _themeColor('primary'),
                        buttonIconColor: Colors.white,
                      ),
                      searchViewConfig: SearchViewConfig(
                        backgroundColor: _themeColor('surface'),
                        buttonIconColor: _themeColor('primary'),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }
        return const SizedBox();
      },
    );
  }

  /// 构建输入框（支持多行、emoji、安全选择等，支持键盘快捷键）
  Widget _buildInputField() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isFocused,
      builder: (context, isFocused, _) {
        return KeyboardListener(
          focusNode: _keyboardListenerFocusNode,
          onKeyEvent: _handleKeyboardShortcuts,
          child: TextField(
            key: const Key('chat_message_input'),
            controller: _textController,
            focusNode: _inputFocusNode,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            enableInteractiveSelection: true,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            contentInsertionConfiguration: widget.contentInsertionConfiguration,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: _themeColor('textSecondary'),
                fontSize: _themeFontSize(FontSizeType.medium),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterText: '',
              filled: isFocused,
              fillColor: isFocused
                  ? _themeColor('primary').withValues(alpha: 0.05)
                  : Colors.transparent,
            ),
            style: TextStyle(
              color: _themeColor('textPrimary'),
              fontSize: _themeFontSize(FontSizeType.medium),
            ),
            onChanged: (val) {
              _handleTextControllerChange();
            },
            onTap: () {
              updateState(InputType.text);
              widget.onTextFieldTap?.call();
            },
            onSubmitted: (_) => _handleSendPressed(),
          ),
        );
      },
    );
  }

  /// 构建语音输入组件（使用增强版语音录制器或自定义组件）
  Widget _buildVoiceInput() {
    if (widget.voiceWidget != null) {
      return widget.voiceWidget!;
    }
    return SizedBox.shrink();
  }

  /// 构建输入按钮（文本/语音切换，AnimatedSwitcher 平滑过渡）
  Widget _buildInputButton() {
    return ValueListenableBuilder<InputType>(
      valueListenable: _inputType,
      builder: (context, inputType, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) {
            return FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                alignment: Alignment.topCenter,
                child: child,
              ),
            );
          },
          child: inputType == InputType.voice
              ? KeyedSubtree(
                  key: const ValueKey('voice'),
                  child: _buildVoiceInput(),
                )
              : KeyedSubtree(
                  key: const ValueKey('text'),
                  child: _buildInputField(),
                ),
        );
      },
    );
  }

  /// 构建左侧按钮（语音/键盘切换）
  Widget _buildLeftButton() {
    return ValueListenableBuilder<InputType>(
      valueListenable: _inputType,
      builder: (context, inputType, _) {
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            if (inputType == InputType.voice) {
              updateState(InputType.text);
            } else {
              updateState(InputType.voice);
            }
          },
          minimumSize: Size(44, 44),
          child: Icon(
            inputType != InputType.voice
                ? CupertinoIcons.mic
                : CupertinoIcons.keyboard,
            size: 28,
            color: AppColors.iosGray,
          ),
        );
      },
    );
  }

  /// 构建表情按钮
  Widget _buildEmojiButton() {
    return ValueListenableBuilder<InputType>(
      valueListenable: _inputType,
      builder: (context, inputType, _) {
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            updateState(
              inputType != InputType.emoji ? InputType.emoji : InputType.text,
            );
          },
          minimumSize: Size(44, 44),
          child: Icon(
            inputType != InputType.emoji
                ? CupertinoIcons.smiley
                : CupertinoIcons.keyboard,
            size: 28,
            color: AppColors.iosGray,
          ),
        );
      },
    );
  }

  /// 构建附加功能按钮
  Widget _buildExtraButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _sendButtonVisible,
      builder: (context, sendButtonVisible, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: sendButtonVisible
              ? const SizedBox.shrink(key: ValueKey('empty_extra'))
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  key: const ValueKey('extra_button'),
                  onPressed: () {
                    updateState(
                      _inputType.value != InputType.extra
                          ? InputType.extra
                          : InputType.text,
                    );
                  },
                  minimumSize: Size(44, 44),
                  child: Icon(
                    CupertinoIcons.plus_circle,
                    size: 28,
                    color: AppColors.iosGray,
                  ),
                ),
        );
      },
    );
  }

  /// 构建发送按钮（带动画效果，iOS 17 风格）
  Widget _buildSendButton() {
    final brightness = Theme.of(context).brightness;
    return ValueListenableBuilder<bool>(
      valueListenable: _sendButtonVisible,
      builder: (context, sendButtonVisible, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: sendButtonVisible
              ? Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: CupertinoButton(
                    key: const ValueKey('send_button'),
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.getIosBlue(brightness),
                    onPressed: _handleSendPressed,
                    minimumSize: Size(32, 32),
                    child: const Icon(
                      CupertinoIcons.arrow_up,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty_button')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 每次构建时都设置键盘监听器，确保能及时响应键盘变化
    _setupKeyboardListener();

    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (bottomInset > (bottomPadding + 50)) {
      _keyboardHeight = bottomInset;
    }

    final targetPanelHeight = _keyboardHeight > 0
        ? _keyboardHeight
        : _softKeyHeight;
    double panelHeight = 0;

    if (_inputType.value == InputType.emoji ||
        _inputType.value == InputType.extra) {
      panelHeight = targetPanelHeight;
    } else if (_inputType.value == InputType.text) {
      if (_isTransitioningToTextFromPanel) {
        panelHeight = max(targetPanelHeight, bottomInset);
        if (bottomInset >= targetPanelHeight * 0.9) {
          _isTransitioningToTextFromPanel = false;
        }
      } else {
        panelHeight = bottomInset;
      }
    } else {
      panelHeight = 0;
    }

    // 禁言状态：显示禁言提示条替代输入区
    if (widget.isMuted) {
      return Container(
        color: widget.backgroundColor ?? _themeColor('surface'),
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _themeColor('error').withValues(alpha: 0.08),
                border: Border(
                  top: BorderSide(
                    color: _themeColor('error').withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.volume_off,
                    size: 18,
                    color: _themeColor('error').withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.muteMessage ?? t.common.mutedCannotSend,
                      style: TextStyle(
                        color: _themeColor('error').withValues(alpha: 0.8),
                        fontSize: _themeFontSize(FontSizeType.small),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final composerBgColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurfaceGrouped;

    return Container(
      color: composerBgColor,
      child: Column(
        children: [
          // 引用消息提示条
          if (widget.quoteTipsWidget != null) widget.quoteTipsWidget!,

          // 主输入区域
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.getIosSeparator(
                    Theme.of(context).brightness,
                  ).withValues(alpha: 0.3),
                  width: 0.33,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 左侧语音/键盘切换按钮
                _buildLeftButton(),

                // 中间输入区域（文本输入框或语音按钮）
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: 40,
                      maxHeight: (widget.maxLines ?? 6) * 24.0 + 16,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.getIosSeparator(
                          Theme.of(context).brightness,
                        ).withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _buildInputButton(),
                        ),
                        // @提及列表
                        Positioned(
                          bottom: 50,
                          left: 0,
                          right: 0,
                          child: _buildMentionList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // 表情按钮
                _buildEmojiButton(),

                // 发送按钮或附加功能按钮
                ValueListenableBuilder<bool>(
                  valueListenable: _sendButtonVisible,
                  builder: (context, sendButtonVisible, _) {
                    return sendButtonVisible
                        ? _buildSendButton()
                        : _buildExtraButton();
                  },
                ),
              ],
            ),
          ),

          // 底部面板
          _buildBottomContainer(
            child: _buildBottomItems(),
            height: panelHeight,
          ),

          // 快捷回复面板
          _buildQuickRepliesPanel(),

          // 安全区填充
          if (panelHeight == 0) SizedBox(height: bottomPadding),
        ],
      ),
    );
  }
}
