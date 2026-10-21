/// 面聊记录片段校对页（T16）。
///
/// 契约源：UI-SPEC §2「原文校对」+ DESIGN §5.6：
/// - 可编辑文字 + 原稿对照（编辑期保留进入时快照；服务端模型原版在
///   受控历史中——§4，T15 联调接入真实对照源）；
/// - 保存成功 → 服务端推进 content_revision 并标摘要 stale（fixture 语义
///   同步验证）；原音频不变；
/// - 版本冲突（412）：**保留本地输入**供对比/重新提交，不静默覆盖；
///   展示服务器最新稿，提供「采用服务器稿」与「重新提交」。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_ui_helpers.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart'
    show TalkRecordApiException;
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 片段校对页。
class TalkRecordSegmentEditPage extends ConsumerStatefulWidget {
  const TalkRecordSegmentEditPage({
    super.key,
    required this.recordId,
    required this.segmentId,
  });

  final String recordId;
  final String segmentId;

  @override
  ConsumerState<TalkRecordSegmentEditPage> createState() =>
      _TalkRecordSegmentEditPageState();
}

enum _SavePhase { idle, saving, saved, conflict, failed }

class _TalkRecordSegmentEditPageState
    extends ConsumerState<TalkRecordSegmentEditPage> {
  final TextEditingController _controller = TextEditingController();
  StreamSubscription<dynamic>? _localeSubscription;

  /// 进入时的原稿快照（编辑对照；不声称服务端历史）。
  String _originalSnapshot = '';
  bool _loaded = false;
  bool _loading = true;
  bool _loadFailed = false;
  _SavePhase _savePhase = _SavePhase.idle;

  /// 412 时服务器最新稿（保留本地输入对比）。
  String _serverText = '';

  TalkRecordSegmentModel? _segment;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ref
        .read(talkRecordSegmentsProvider.notifier)
        .bind(widget.recordId, force: true);
    final state = ref.read(talkRecordSegmentsProvider);
    TalkRecordSegmentModel? segment;
    for (final s in state.segments) {
      if (s.id == widget.segmentId) segment = s;
    }
    if (!mounted) return;
    if (state.phase == TalkRecordSegmentsPhase.ready && segment != null) {
      _segment = segment;
      _originalSnapshot = segment.text;
      if (!_loaded) _controller.text = segment.text;
      _loaded = true;
      _loadFailed = false;
      _savePhase = _SavePhase.idle;
    } else {
      _loadFailed = true;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final segment = _segment;
    if (segment == null) return;
    setState(() => _savePhase = _SavePhase.saving);
    try {
      await ref
          .read(talkRecordDetailServiceProvider)
          .patchSegment(
            widget.recordId,
            widget.segmentId,
            text: _controller.text,
            ifMatch: talkRecordSegmentEtagOf(segment),
          );
      // 成功：刷新详情（content_revision/摘要 stale 生效）与片段列表后返回。
      await ref
          .read(talkRecordDetailProvider.notifier)
          .reloadAfterContentChange();
      await ref.read(talkRecordSegmentsProvider.notifier).reload();
      if (!mounted) return;
      setState(() => _savePhase = _SavePhase.saved);
      context.pop();
    } on TalkRecordApiException catch (e) {
      if (!mounted) return;
      if (e.isRevisionStale) {
        // 412：刷新服务器最新稿供对比；本地输入保留（不清空 controller）。
        await _refreshServerText();
        setState(() => _savePhase = _SavePhase.conflict);
      } else {
        setState(() => _savePhase = _SavePhase.failed);
      }
    } on Object {
      if (mounted) setState(() => _savePhase = _SavePhase.failed);
    }
  }

  Future<void> _refreshServerText() async {
    try {
      final page = await ref
          .read(talkRecordDetailServiceProvider)
          .segments(widget.recordId);
      for (final s in page.list) {
        if (s.id == widget.segmentId) {
          _serverText = s.text;
          _segment = s;
        }
      }
    } on Object {
      // 刷新失败保留旧值；冲突视图仍可重新提交。
    }
  }

  /// 底部按钮在冲突态即「重新提交」：使用 [_refreshServerText] 刷新后的
  /// 服务器 revision 作 If-Match，本地输入保持不变。
  void _adoptServerText() {
    _controller.text = _serverText;
    setState(() => _savePhase = _SavePhase.idle);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return IosPageTemplate(
      title: t.talkRecord.segmentEditTitle,
      body: _loading
          ? const ShimmerList()
          : _loadFailed
          ? _LoadFailed(onRetry: _load)
          : _buildEditor(brightness),
      bottomWidget: SafeArea(top: false, child: _buildBottom(brightness)),
    );
  }

  Widget _buildEditor(Brightness brightness) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.regular),
            decoration: BoxDecoration(
              color: brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.person_crop_circle,
                      size: AppSpacing.medium + 4,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Text(
                      t.talkRecord.segmentTimeLabel(
                        time: talkRecordFormatDuration(_segment?.startMs ?? 0),
                      ),
                      style: context
                          .textStyle(
                            FontSizeType.footnote,
                            fontWeight: FontWeight.w600,
                            color: brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          )
                          .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.medium),
                Text(
                  t.talkRecord.segmentOriginalLabel,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.tiny),
                // C-F3：原稿对照可换行。
                Text(
                  _savePhase == _SavePhase.conflict && _serverText.isNotEmpty
                      ? _serverText
                      : _originalSnapshot,
                  key: const ValueKey('talk_record_segment_original'),
                  maxLines: null,
                  style: context.textStyle(
                    FontSizeType.body,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                if (_savePhase == _SavePhase.conflict) ...[
                  const SizedBox(height: AppSpacing.small),
                  _ConflictBanner(
                    serverText: _serverText,
                    onAdoptServer: _adoptServerText,
                  ),
                ],
                const SizedBox(height: AppSpacing.medium),
                Text(
                  t.talkRecord.segmentEditLabel,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.tiny),
                CupertinoTextField(
                  key: const ValueKey('talk_record_segment_field'),
                  controller: _controller,
                  minLines: 4,
                  maxLines: 10,
                  placeholder: t.talkRecord.segmentEditPlaceholder,
                  // 冲突/失败不清空：保留本地输入（UI-SPEC §2）。
                  onChanged: (_) {
                    if (_savePhase != _SavePhase.idle) {
                      setState(() => _savePhase = _SavePhase.idle);
                    }
                  },
                ),
                if (_savePhase == _SavePhase.failed)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.small),
                    child: Text(
                      t.talkRecord.segmentSaveFailed,
                      maxLines: null,
                      style: context.textStyle(
                        FontSizeType.caption2,
                        color: AppColors.getIosOrange(brightness),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottom(Brightness brightness) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: SizedBox(
        width: double.infinity,
        // C-F2/C-F4：保存主按钮 ≥48pt、primaryDark 底 + 白字 w600。
        height: AppSpacing.xxxLarge,
        child: CupertinoButton(
          key: const ValueKey('talk_record_segment_save'),
          borderRadius: BorderRadius.circular(10),
          color: AppColors.primaryDark,
          padding: EdgeInsets.zero,
          onPressed: _savePhase == _SavePhase.saving ? null : _save,
          child: Text(
            _savePhase == _SavePhase.conflict
                ? t.talkRecord.segmentResubmit
                : t.talkRecord.segmentSave,
            style: context.textStyle(
              FontSizeType.medium,
              fontWeight: FontWeight.w600,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({
    required this.serverText,
    required this.onAdoptServer,
  });

  final String serverText;
  final VoidCallback onAdoptServer;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_segment_conflict_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.small),
      decoration: BoxDecoration(
        color: AppColors.getIosOrange(brightness)
            .withValues(alpha: brightness == Brightness.dark ? 0.24 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.segmentConflictTitle,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: AppColors.getIosOrange(brightness),
            ),
          ),
          const SizedBox(height: AppSpacing.tiny),
          // C-F3：冲突说明可换行。
          Text(
            t.talkRecord.segmentConflictBody,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.footnote,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          CupertinoButton(
            key: const ValueKey('talk_record_segment_adopt_server'),
            minimumSize: const Size(44, 36),
            padding: EdgeInsets.zero,
            onPressed: onAdoptServer,
            child: Text(t.talkRecord.segmentAdoptServer),
          ),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.talkRecord.loadFailedTitle,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.medium,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          CupertinoButton(
            key: const ValueKey('talk_record_segment_load_retry'),
            onPressed: onRetry,
            child: Text(t.talkRecord.loadFailedAction),
          ),
        ],
      ),
    );
  }
}
