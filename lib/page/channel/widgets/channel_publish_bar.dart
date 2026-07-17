import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/chat/composer_field.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/upload/batch_upload_controller.dart';
import 'package:imboy/component/voice_record/voice_widget.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:xid/xid.dart';

import '../channel_provider.dart';

/// 单个媒体上传结果：待发布消息的三要素。
typedef _ChannelMediaUpload = ({
  String msgType,
  String content,
  Map<String, dynamic> payload,
});

/// 频道发布输入栏
///
/// 从详情页 [_buildMessageInput] + [_sendMessage] + 媒体/语音上传逻辑抽出。
/// 独立 StatefulWidget，通过 Provider 编排发布行为，详情页只负责挂载。
class ChannelPublishBar extends ConsumerStatefulWidget {
  /// 输入框焦点（父层持有，用于键盘/语音切换管理）
  final FocusNode focusNode;

  const ChannelPublishBar({super.key, required this.focusNode});

  @override
  ConsumerState<ChannelPublishBar> createState() => _ChannelPublishBarState();
}

class _ChannelPublishBarState extends ConsumerState<ChannelPublishBar> {
  /// 频道媒体单批并发上限。
  /// ponytail: 固定 3，避免大文件同批打满带宽；需要更细粒度限流时再升级为信号量池。
  static const int _uploadConcurrency = 3;

  final TextEditingController _messageController = TextEditingController();
  bool _isUploadingMedia = false;
  bool _showVoiceInput = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  @override
  void dispose() {
    _persistDraftOnExit();
    _messageController.dispose();
    super.dispose();
  }

  /// 频道草稿存储 key，按 channelId 隔离；频道未加载时返回空串，调用方据此跳过读写。
  String get _draftKey {
    final channelId = ref.read(channelDetailProvider).channel?.id;
    return channelId == null ? '' : 'channel_draft_$channelId';
  }

  /// 恢复上次未发送的草稿文本（复用朋友圈 StorageService 草稿模式）。
  void _restoreDraft() {
    final key = _draftKey;
    if (key.isEmpty || !mounted) return;
    final draft = StorageService.to.getString(key);
    if (draft.isEmpty) return;
    setState(() => _messageController.text = draft);
    AppLoading.showInfo(context.t.discovery.momentsDraftRestored);
  }

  /// 退出前把未发送文本落盘；已清空则顺带清掉旧草稿，避免残留。
  void _persistDraftOnExit() {
    final key = _draftKey;
    if (key.isEmpty) return;
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      unawaited(StorageService.to.remove(key));
      return;
    }
    unawaited(StorageService.to.setString(key, content));
  }

  /// 打开「撰写图文」页（公众号式多图+正文，作为单条 imageText 发布）。
  void _openCompose() {
    final channelId = ref.read(channelDetailProvider).channel?.id;
    if (channelId == null) return;
    context.push('/channel/$channelId/compose');
  }

  /// 发送文本消息
  Future<void> _sendMessage() async {
    if (ref.read(channelDetailProvider).isPublishing || _isUploadingMedia) {
      return;
    }
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final success = await ref
        .read(channelDetailProvider.notifier)
        .publishMessage(content: content, msgType: ChannelMessageType.text);

    // await 之后必须查 mounted：用户发送后立刻返回上一页(dispose)时，
    // 成功分支若不检查会 setState after dispose 崩溃（失败分支已有保护）。
    if (!mounted) return;
    if (success) {
      _messageController.clear();
      setState(() {});
      final key = _draftKey;
      if (key.isNotEmpty) unawaited(StorageService.to.remove(key));
      unawaited(HapticFeedback.lightImpact());
      AppLoading.showSuccess(context.t.common.tipSuccess);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t.channel.publishFailed)));
  }

  /// 语音录制完成
  Future<void> _handleVoiceRecordFinished(AudioFile? obj) async {
    if (obj == null) return;
    final t = context.t;
    final Uint8List bytes = await obj.file.readAsBytes();
    if (bytes.isEmpty) return;
    // await(readAsBytes) 之后查 mounted，避免录音完立刻返回页面时
    // setState after dispose（finally 里的 setState 已有 mounted 保护）。
    if (!mounted) return;

    setState(() => _isUploadingMedia = true);
    AppLoading.show(status: t.common.loading);

    try {
      final String mime = obj.mimeType;
      final String ext = mime.contains('/') ? mime.split('/').last : 'mp3';
      final String name = '${Xid().toString()}.$ext';

      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        name,
        mime,
        process: false,
      );
      final String? uploadedUri = meta['object_key'] as String?;

      if (uploadedUri != null && uploadedUri.isNotEmpty) {
        final success = await ref
            .read(channelDetailProvider.notifier)
            .publishMessage(
              content: '',
              msgType: ChannelMessageType.audio,
              payload: {
                'uri': uploadedUri,
                'duration_ms': obj.duration.inMilliseconds,
                'size': bytes.length,
                'waveform': obj.waveform,
              },
            );
        if (success) {
          AppLoading.showSuccess(t.common.tipSuccess);
        } else {
          AppLoading.showError(t.channel.publishFailed);
        }
      } else {
        AppLoading.showError(t.common.uploadFailed);
      }
    } catch (_) {
      AppLoading.showError(t.common.voiceSendFailed);
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
      AppLoading.dismiss();
    }
  }

  /// 选择并发送媒体文件（并行上传，分批限流，保留逐项 payload 组装）
  Future<void> _pickAndSendMedia() async {
    if (ref.read(channelDetailProvider).isPublishing || _isUploadingMedia) {
      return;
    }
    setState(() => _isUploadingMedia = true);

    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 9,
        requestType: RequestType.common,
        textDelegate: const EnglishAssetPickerTextDelegate(),
      ),
    );

    if (assets == null || assets.isEmpty) {
      if (mounted) setState(() => _isUploadingMedia = false);
      return;
    }
    if (!mounted) return;
    final t = context.t;

    // 逐项上传控制器：批内并行、批间串行限流（_uploadConcurrency），失败项保留
    // 为可重试态而非整批作废。已发布项记入 publishedIdx，避免重试后重复发布。
    final controller = BatchUploadController<_ChannelMediaUpload>(
      uploader: _uploadSingleAsset,
      concurrency: _uploadConcurrency,
    );
    void onProgress() {
      final total = controller.length;
      if (total == 0) return;
      final finished = controller.items
          .where((i) => i.isDone || i.isFailed)
          .length;
      AppLoading.showProgress(
        finished / total,
        status: '${t.common.uploading} $finished/$total',
      );
    }

    controller.addListener(onProgress);
    final publishedIdx = <int>{};

    Future<void> publishDone() async {
      final items = controller.items;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (!item.isDone || publishedIdx.contains(i)) continue;
        final ok = await ref
            .read(channelDetailProvider.notifier)
            .publishMessage(
              content: item.result!.content,
              msgType: item.result!.msgType,
              payload: item.result!.payload,
            );
        if (!mounted) return;
        if (ok) publishedIdx.add(i);
      }
    }

    try {
      AppLoading.showProgress(
        0,
        status: '${t.common.uploading} 0/${assets.length}',
      );
      await controller.addAndUpload(assets);
      AppLoading.dismiss();
      controller.removeListener(onProgress);
      if (!mounted) return;

      await publishDone();
      if (!mounted) return;

      final failedCount = controller.items.where((i) => i.isFailed).length;
      if (failedCount > 0) {
        _showUploadFailedSnackBar(failedCount, controller, publishDone);
      } else if (publishedIdx.isNotEmpty) {
        unawaited(HapticFeedback.lightImpact());
        AppLoading.showSuccess(t.common.tipSuccess);
      }
    } finally {
      controller.removeListener(onProgress);
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  /// 弹出「N 项上传失败 + 重试」SnackBar；重试走同一 [controller] 管道，成功项
  /// 经 [publishDone] 补发布，剩余失败继续重新弹出重试入口。
  void _showUploadFailedSnackBar(
    int failedCount,
    BatchUploadController<_ChannelMediaUpload> controller,
    Future<void> Function() publishDone,
  ) {
    if (!mounted) return;
    final t = context.t;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.common.uploadPartialFailed(count: failedCount)),
        action: SnackBarAction(
          label: t.common.buttonRetry,
          onPressed: () =>
              unawaited(_retryFailedMedia(controller, publishDone)),
        ),
      ),
    );
  }

  Future<void> _retryFailedMedia(
    BatchUploadController<_ChannelMediaUpload> controller,
    Future<void> Function() publishDone,
  ) async {
    if (_isUploadingMedia) return;
    setState(() => _isUploadingMedia = true);
    try {
      await controller.retryFailed();
      if (!mounted) return;
      await publishDone();
      if (!mounted) return;
      final failedCount = controller.items.where((i) => i.isFailed).length;
      if (failedCount > 0) {
        _showUploadFailedSnackBar(failedCount, controller, publishDone);
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  /// 上传单个已选资源，返回待发布的消息素材；失败（含文件读取失败）返回
  /// null，由调用方计入失败计数并在汇总提示中体现。
  Future<_ChannelMediaUpload?> _uploadSingleAsset(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return null;

    String msgType = ChannelMessageType.file;
    String uploadPrefix = 'files';
    final payload = <String, dynamic>{
      'name': asset.title ?? file.path.split('/').last,
      'size': await file.length(),
    };

    if (asset.type == AssetType.image) {
      msgType = ChannelMessageType.image;
      uploadPrefix = 'img';
    } else if (asset.type == AssetType.video) {
      msgType = ChannelMessageType.video;
    }

    if (msgType == ChannelMessageType.video) {
      // 视频走统一上传方法（压缩+缩略图+上传三件套）
      final result = await AttachmentApi.uploadVideoFileViaPresign(
        file,
        durationMs: (asset.duration * 1000).toInt(),
        width: asset.width,
        height: asset.height,
        scope: 'channel',
      );
      if (result == null) return null;
      payload['uri'] = result['video_uri'];
      payload['size'] = result['size'];
      payload['duration'] = asset.duration;
      payload['thumb'] = {'uri': result['thumb_uri']};
    } else {
      // 图片/文件仍走单文件上传
      final uploadedUri = await _uploadChannelFile(file, prefix: uploadPrefix);
      if (uploadedUri == null || uploadedUri.isEmpty) return null;
      payload['uri'] = uploadedUri;
    }

    final fileName = asset.title ?? file.path.split('/').last;
    final content = fileName.trim().isEmpty ? '[media]' : fileName;
    return (msgType: msgType, content: content, payload: payload);
  }

  Future<String?> _uploadChannelFile(
    File file, {
    required String prefix,
  }) async {
    String? uploadedUrl;
    final completer = Completer<bool>();

    await AttachmentApi.uploadFileViaPresignCompat(
      prefix,
      file,
      (Map<String, dynamic> resp, String url) {
        if (completer.isCompleted) return;
        if ((resp['status']?.toString() ?? '') == 'ok') {
          uploadedUrl = url;
          completer.complete(true);
        } else {
          completer.complete(false);
        }
      },
      (_) {
        if (!completer.isCompleted) completer.complete(false);
      },
      process: true,
    );

    return (await completer.future) ? uploadedUrl : null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceGrouped = isDark
        ? AppColors.darkBackground
        : AppColors.lightSurfaceGrouped;
    final separator = isDark
        ? AppColors.iosTertiaryLabel
        : AppColors.iosSeparator;
    final secondaryText = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );

    final state = ref.watch(channelDetailProvider);
    final isBusy = state.isPublishing || _isUploadingMedia;
    final hasText = _messageController.text.isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: surfaceGrouped,
        border: Border(top: BorderSide(color: separator, width: 0.33)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.article_outlined, size: 26),
            color: secondaryText,
            onPressed: isBusy ? null : _openCompose,
            tooltip: context.t.channel.writeArticle,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 28),
            color: secondaryText,
            onPressed: isBusy ? null : _pickAndSendMedia,
            tooltip: context.t.common.momentsAddMedia,
          ),
          IconButton(
            tooltip: _showVoiceInput
                ? context.t.chat.switchToKeyboardInput
                : context.t.chat.switchToVoiceInput,
            icon: Icon(
              _showVoiceInput ? Icons.keyboard_alt_outlined : Icons.mic_none,
              size: 28,
            ),
            color: secondaryText,
            onPressed: isBusy
                ? null
                : () {
                    setState(() {
                      _showVoiceInput = !_showVoiceInput;
                      if (_showVoiceInput) {
                        widget.focusNode.unfocus();
                      } else {
                        widget.focusNode.requestFocus();
                      }
                    });
                  },
          ),
          Expanded(
            child: _showVoiceInput
                ? VoiceWidget(
                    startRecord: () {},
                    stopRecord: _handleVoiceRecordFinished,
                    height: 44,
                    margin: EdgeInsets.zero,
                  )
                : ComposerField(
                    controller: _messageController,
                    focusNode: widget.focusNode,
                    enabled: !isBusy,
                    hintText: context.t.channel.writeMessage,
                    // 上限放宽但在折叠阈值(消费侧 channel_message_item:397
                    // content.length > 280)处变警示色，提示作者"超过将被折叠"。
                    maxLength: 2000,
                    warnThreshold: 280,
                    maxLines: 6,
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: () {
                      if (!isBusy) _sendMessage();
                    },
                  ),
          ),
          if (!_showVoiceInput) ...[
            AppSpacing.horizontalSmall,
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasText ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: isBusy
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : hasText
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: AppColors.onPrimary,
                      ),
                      onPressed: _sendMessage,
                      tooltip: context.t.common.buttonSend,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}
