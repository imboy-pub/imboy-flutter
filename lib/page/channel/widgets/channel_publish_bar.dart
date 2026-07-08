import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/voice_record/voice_widget.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:xid/xid.dart';

import '../channel_provider.dart';

/// 频道发布输入栏
///
/// 从详情页 [_buildMessageInput] + [_sendMessage] + 媒体/语音上传逻辑抽出。
/// 独立 StatefulWidget，通过 Provider 编排发布行为，详情页只负责挂载。
class ChannelPublishBar extends ConsumerStatefulWidget {
  /// 请求聚焦输入框（由父层 AppBar 按钮触发）
  final FocusNode focusNode;

  const ChannelPublishBar({super.key, required this.focusNode});

  @override
  ConsumerState<ChannelPublishBar> createState() => _ChannelPublishBarState();
}

class _ChannelPublishBarState extends ConsumerState<ChannelPublishBar> {
  final TextEditingController _messageController = TextEditingController();
  bool _isUploadingMedia = false;
  bool _showVoiceInput = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// 外部触发聚焦
  void focus() {
    if (widget.focusNode.canRequestFocus) widget.focusNode.requestFocus();
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

    if (success) {
      _messageController.clear();
      setState(() {});
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.channel.publishFailed)));
    }
  }

  /// 语音录制完成
  Future<void> _handleVoiceRecordFinished(AudioFile? obj) async {
    if (obj == null) return;
    final t = context.t;
    final Uint8List bytes = await obj.file.readAsBytes();
    if (bytes.isEmpty) return;

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

  /// 选择并发送媒体文件
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

    try {
      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

        String msgType = ChannelMessageType.file;
        String uploadPrefix = 'files';
        Map<String, dynamic> payload = {
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
          if (!mounted) return;
          if (result == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.t.common.uploadFailed)),
            );
            continue;
          }
          payload['uri'] = result['video_uri'];
          payload['size'] = result['size'];
          payload['duration'] = asset.duration;
          payload['thumb'] = {'uri': result['thumb_uri']};
        } else {
          // 图片/文件仍走单文件上传
          final uploadedUri = await _uploadChannelFile(
            file,
            prefix: uploadPrefix,
          );
          if (!mounted) return;
          if (uploadedUri == null || uploadedUri.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.t.common.uploadFailed)),
            );
            continue;
          }
          payload['uri'] = uploadedUri;
        }

        final fileName = asset.title ?? file.path.split('/').last;
        final content = fileName.trim().isEmpty ? '[media]' : fileName;

        final success = await ref
            .read(channelDetailProvider.notifier)
            .publishMessage(
              content: content,
              msgType: msgType,
              payload: payload,
            );

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t.channel.publishFailed)),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
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
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
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
                : Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      maxHeight: 120,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: AppRadius.borderRadiusRegular,
                      border: Border.all(
                        color: isDark
                            ? AppColors.iosSeparatorDark
                            : AppColors.iosSeparator.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: widget.focusNode,
                      enabled: !isBusy,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: context.t.channel.writeMessage,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      style: context
                          .textStyle(
                            FontSizeType.body,
                            color: AppColors.getTextColor(
                              Theme.of(context).brightness,
                            ),
                          )
                          .copyWith(height: 1.4),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!isBusy) _sendMessage();
                      },
                    ),
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
