/// 面聊记录详情原文流（T16）。
///
/// 契约源：UI-SPEC §2「详情/原文校对」+ DESIGN.md §4：
/// - segment 列表：说话人标签（人工标记来源加 pill）、时间点（tap 回听
///   定位播放器）、录音中手动重点 pill、人工修订 pill；
/// - 搜索命中高亮；命中跳转只 seek 播放器，**不抢用户当前阅读位置**；
///   阅读锚点与播放片段分离时由「回到播放位置」入口滚动回来；
/// - editor 点片段进入校对；viewer 只读（无校对入口）；
/// - 仅录音/无语音/转写失败真实降级（不渲染虚构正文，UI-SPEC §2/§4）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_ui_helpers.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_mark_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_speaker_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 原文流展示模式（页面按记录状态裁决；降级视图不渲染虚构正文）。
enum TalkRecordTranscriptMode {
  /// 有原文片段，正常列表。
  normal,

  /// 仅录音（record_only / not_requested / unavailable）。
  recordOnly,

  /// 无语音（no_speech；不显示「转写失败」，UI-SPEC §4）。
  noSpeech,

  /// 转写失败（录音仍可回听；editor/owner 可重试）。
  failed,

  /// 转写排队/处理中（不伪造百分比）。
  processing,
}

class TalkRecordTranscriptView extends StatefulWidget {
  const TalkRecordTranscriptView({
    super.key,
    required this.mode,
    required this.segments,
    required this.speakers,
    required this.marks,
    required this.query,
    required this.canEdit,
    required this.playingPositionMs,
    required this.playerActive,
    required this.onQueryChanged,
    required this.onListenFrom,
    required this.onEditSegment,
    required this.onRetryTranscribe,
    required this.onAnchorMismatchChanged,
  });

  final TalkRecordTranscriptMode mode;
  final List<TalkRecordSegmentModel> segments;
  final List<TalkRecordSpeakerModel> speakers;
  final List<TalkRecordMarkModel> marks;
  final String query;
  final bool canEdit;

  /// 播放器当前进度（毫秒）；-1 表示未激活。
  final int playingPositionMs;
  final bool playerActive;
  final ValueChanged<String> onQueryChanged;
  final void Function(int positionMs) onListenFrom;
  final void Function(TalkRecordSegmentModel segment) onEditSegment;
  final VoidCallback onRetryTranscribe;
  final ValueChanged<bool> onAnchorMismatchChanged;

  @override
  State<TalkRecordTranscriptView> createState() =>
      TalkRecordTranscriptViewState();
}

class TalkRecordTranscriptViewState extends State<TalkRecordTranscriptView> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _rowKeys = {};
  final GlobalKey _listViewportKey = GlobalKey();

  /// 用户阅读锚点（最近位于视口顶部的片段 seq）。
  int? _anchorSeq;

  /// 上报去重（didUpdateWidget/滚动回调中调用宿主回调必须推迟到帧后，
  /// 否则会触发 build 期 setState 断言）。
  bool? _lastReportedMismatch;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _anchorSeq = widget.segments.isEmpty ? null : widget.segments.first.seq;
    // 挂载时（如播放在别处进行后切回原文页签）也要上报一次锚点差。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportMismatch();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TalkRecordTranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments &&
        widget.segments.isNotEmpty &&
        _anchorSeq == null) {
      _anchorSeq = widget.segments.first.seq;
    }
    _reportMismatch();
  }

  /// 「回到播放位置」：滚动原文到播放中片段并更新锚点（不改变播放进度）。
  void jumpToPlayingSegment() {
    final seq = _playingSeq();
    if (seq == null) return;
    _scrollToSeq(seq);
  }

  int? _playingSeq() {
    if (!widget.playerActive || widget.playingPositionMs < 0) return null;
    for (final s in widget.segments) {
      if (widget.playingPositionMs >= s.startMs &&
          widget.playingPositionMs < s.endMs) {
        return s.seq;
      }
    }
    if (widget.segments.isNotEmpty &&
        widget.playingPositionMs >= widget.segments.last.endMs) {
      return widget.segments.last.seq;
    }
    return null;
  }

  void _scrollToSeq(int seq) {
    final key = _rowKeys[seq];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        alignment: 0.02,
      );
      _anchorSeq = seq;
      _reportMismatch();
      return;
    }
    // 行未构建（长列表）：按比例估算跳转，构建后再精确对齐（组件阶段
    // 近似；真实精度由 T15 联调换 scrollable_positioned_list 或索引锚点）。
    if (_scroll.hasClients && widget.segments.isNotEmpty) {
      final ratio = seq / widget.segments.length;
      _scroll.position.jumpTo(_scroll.position.maxScrollExtent * ratio);
      _anchorSeq = seq;
      _reportMismatch();
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients || !mounted) return;
    // 锚点以「列表视口」顶部为基准（不含搜索框区域）。
    final viewportCtx = _listViewportKey.currentContext;
    final viewportBox = viewportCtx?.findRenderObject();
    if (viewportBox is! RenderBox || !viewportBox.attached) return;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    int? topSeq;
    double bestAbove = -1;
    double bestBelow = double.infinity;
    int? belowSeq;
    for (final entry in _rowKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      // 视口顶以上最近行（含刚滚出/贴近顶部的行）为阅读锚点；全在下方
      // 时取首行。+48 容差与 ensureVisible 的对齐量匹配，避免回位后
      // 锚点又被滚回上一行。
      if (top <= viewportTop + 48) {
        if (top > bestAbove) {
          bestAbove = top;
          topSeq = entry.key;
        }
      } else if (top < bestBelow) {
        bestBelow = top;
        belowSeq = entry.key;
      }
    }
    topSeq ??= belowSeq;
    if (topSeq != null && topSeq != _anchorSeq) {
      _anchorSeq = topSeq;
      _reportMismatch();
    }
  }

  void _reportMismatch() {
    final playing = _playingSeq();
    final mismatch =
        widget.playerActive &&
        playing != null &&
        _anchorSeq != null &&
        playing != _anchorSeq;
    if (_lastReportedMismatch == mismatch) return;
    _lastReportedMismatch = mismatch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onAnchorMismatchChanged(mismatch);
    });
  }

  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (widget.mode != TalkRecordTranscriptMode.normal) {
      return _DegradedView(
        mode: widget.mode,
        canEdit: widget.canEdit,
        onRetry: widget.onRetryTranscribe,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.regular,
            AppSpacing.small,
            AppSpacing.regular,
            AppSpacing.tiny,
          ),
          child: CupertinoSearchTextField(
            key: const ValueKey('talk_record_transcript_search'),
            placeholder: t.talkRecord.transcriptSearchHint,
            suffixMode: OverlayVisibilityMode.editing,
            onChanged: widget.onQueryChanged,
          ),
        ),
        _HitCountLine(query: widget.query, segments: widget.segments),
        Expanded(
          child: widget.segments.isEmpty
              ? _EmptyTranscript()
              : ListView.builder(
                  key: _listViewportKey,
                  controller: _scroll,
                  padding: const EdgeInsets.only(
                    bottom: AppSpacing.xLarge,
                    top: AppSpacing.tiny,
                  ),
                  itemCount: widget.segments.length,
                  itemBuilder: (context, index) {
                    final segment = widget.segments[index];
                    return _SegmentRow(
                      key: _rowKeyFor(segment.seq),
                      segment: segment,
                      speaker: _speakerOf(segment),
                      mark: _markIn(segment),
                      query: widget.query,
                      canEdit: widget.canEdit,
                      playing: _playingSeq() == segment.seq,
                      onListenFrom: widget.onListenFrom,
                      onEditSegment: widget.onEditSegment,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Key _rowKeyFor(int seq) => _rowKeys.putIfAbsent(seq, GlobalKey.new);

  TalkRecordSpeakerModel? _speakerOf(TalkRecordSegmentModel segment) {
    if (segment.speakerId.isEmpty) return null;
    for (final s in widget.speakers) {
      if (s.id == segment.speakerId) return s;
    }
    return null;
  }

  TalkRecordMarkModel? _markIn(TalkRecordSegmentModel segment) {
    for (final m in widget.marks) {
      if (m.positionMs >= segment.startMs && m.positionMs < segment.endMs) {
        return m;
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// 行
// ---------------------------------------------------------------------------

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    super.key,
    required this.segment,
    required this.speaker,
    required this.mark,
    required this.query,
    required this.canEdit,
    required this.playing,
    required this.onListenFrom,
    required this.onEditSegment,
  });

  final TalkRecordSegmentModel segment;
  final TalkRecordSpeakerModel? speaker;
  final TalkRecordMarkModel? mark;
  final String query;
  final bool canEdit;
  final bool playing;
  final ValueChanged<int> onListenFrom;
  final ValueChanged<TalkRecordSegmentModel> onEditSegment;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final speakerName = (speaker != null && speaker!.displayName.isNotEmpty)
        ? speaker!.displayName
        : (speaker?.localLabel ?? t.talkRecord.speakerUnknown);

    return Semantics(
      label: t.talkRecord.segmentRowSemanticLabel(
        speaker: speakerName,
        time: talkRecordFormatDuration(segment.startMs),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // editor 点片段进入校对；viewer 只读（时间 pill 仍可回听定位）。
        onTap: canEdit ? () => onEditSegment(segment) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.tiny + 2,
          ),
          padding: const EdgeInsets.all(AppSpacing.small + 2),
          decoration: BoxDecoration(
            color: playing
                ? AppColors.primaryLight.withValues(
                    alpha: brightness == Brightness.dark ? 0.24 : 1,
                  )
                : (brightness == Brightness.dark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(10),
          ),
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: _SpeakerPill(name: speakerName, speaker: speaker),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  _TimePill(
                    segmentId: segment.id,
                    startMs: segment.startMs,
                    onTap: () => onListenFrom(segment.startMs),
                  ),
                ],
              ),
              if (mark != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.tiny),
                  child: _MarkPill(text: mark!.text),
                ),
              const SizedBox(height: AppSpacing.tiny),
              _SegmentText(text: segment.text, query: query),
              if (segment.origin == TalkRecordSegmentOrigin.human)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.tiny),
                  child: _HumanEditedPill(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeakerPill extends StatelessWidget {
  const _SpeakerPill({required this.name, required this.speaker});

  final String name;
  final TalkRecordSpeakerModel? speaker;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final manual =
        speaker?.identitySource == TalkRecordSpeakerIdentitySource.manual;
    final selfClaim =
        speaker?.identitySource == TalkRecordSpeakerIdentitySource.selfClaim;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(
          alpha: brightness == Brightness.dark ? 0.28 : 0.1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
          if (manual || selfClaim) ...[
            const SizedBox(width: 4),
            Text(
              manual
                  ? t.talkRecord.speakerManualPill
                  : t.talkRecord.speakerSelfClaimPill,
              key: const ValueKey('talk_record_speaker_source_pill'),
              style: context.textStyle(
                FontSizeType.caption2,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.segmentId,
    required this.startMs,
    required this.onTap,
  });

  final String segmentId;
  final int startMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Semantics(
      button: true,
      label: t.talkRecord.segmentListenLabel(
        time: talkRecordFormatDuration(startMs),
      ),
      child: GestureDetector(
        key: ValueKey('talk_record_segment_time_$segmentId'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
            alignment: Alignment.center,
            child: Text(
              talkRecordFormatDuration(startMs),
              style: context
                  .textStyle(
                    FontSizeType.footnote,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  )
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkPill extends StatelessWidget {
  const _MarkPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_mark_pill'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
      decoration: BoxDecoration(
        color: AppColors.getIosOrange(brightness)
            .withValues(alpha: brightness == Brightness.dark ? 0.24 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.star_fill,
            size: 12,
            color: AppColors.getIosOrange(brightness),
          ),
          const SizedBox(width: 4),
          // C-F3：重点文字可换行。
          Flexible(
            child: Text(
              text.isEmpty
                  ? t.talkRecord.markDefaultText
                  : '${t.talkRecord.markPillPrefix} $text',
              softWrap: true,
              style: context.textStyle(
                FontSizeType.caption2,
                color: AppColors.getIosOrange(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HumanEditedPill extends StatelessWidget {
  const _HumanEditedPill();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_human_edited_pill'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkTextSecondary.withValues(alpha: 0.2)
            : AppColors.lightTextSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        t.talkRecord.segmentHumanEditedPill,
        style: context.textStyle(
          FontSizeType.caption2,
          color: brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _SegmentText extends StatelessWidget {
  const _SegmentText({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final style = context.textStyle(
      FontSizeType.body,
      color: brightness == Brightness.dark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary,
    );
    // C-F3：正文自然换行，不截断。
    if (query.isEmpty) {
      return Text(text, style: style);
    }
    return Text.rich(
      TextSpan(children: _highlightSpans(text, query, context, style)),
      style: style,
    );
  }

  List<InlineSpan> _highlightSpans(
    String text,
    String query,
    BuildContext context,
    TextStyle base,
  ) {
    final spans = <InlineSpan>[];
    final lower = text.toLowerCase();
    final kw = query.toLowerCase();
    var start = 0;
    while (true) {
      final idx = lower.indexOf(kw, start);
      if (idx < 0 || kw.isEmpty) break;
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + kw.length),
          // 命中高亮：primaryDark 粗体（对比满足正文可读，底色浅蓝）。
          style: base.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
            backgroundColor: AppColors.primaryLight,
          ),
        ),
      );
      start = idx + kw.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }
}

// ---------------------------------------------------------------------------
// 命中计数 / 空态 / 降级
// ---------------------------------------------------------------------------

class _HitCountLine extends StatelessWidget {
  const _HitCountLine({required this.query, required this.segments});

  final String query;
  final List<TalkRecordSegmentModel> segments;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();
    final kw = query.toLowerCase();
    final count = segments
        .where((s) => s.text.toLowerCase().contains(kw))
        .length;
    return Padding(
      key: const ValueKey('talk_record_transcript_hit_count'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: SizedBox(
        width: double.infinity,
        // C-F3：计数行可换行。
        child: Text(
          count > 0
              ? t.talkRecord.transcriptHitCount(count: count)
              : t.talkRecord.transcriptNoHit,
          style: context.textStyle(
            FontSizeType.footnote,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyTranscript extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Text(
          t.talkRecord.transcriptEmpty,
          textAlign: TextAlign.center,
          style: context.textStyle(
            FontSizeType.normal,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _DegradedView extends StatelessWidget {
  const _DegradedView({
    required this.mode,
    required this.canEdit,
    required this.onRetry,
  });

  final TalkRecordTranscriptMode mode;
  final bool canEdit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final (title, body) = switch (mode) {
      TalkRecordTranscriptMode.recordOnly => (
        t.talkRecord.detailRecordOnlyTitle,
        t.talkRecord.detailRecordOnlyBody,
      ),
      TalkRecordTranscriptMode.noSpeech => (
        t.talkRecord.detailNoSpeechTitle,
        t.talkRecord.detailNoSpeechBody,
      ),
      TalkRecordTranscriptMode.failed => (
        t.talkRecord.detailTranscribeFailedTitle,
        canEdit
            ? t.talkRecord.detailTranscribeFailedBodyEditor
            : t.talkRecord.detailTranscribeFailedBodyViewer,
      ),
      TalkRecordTranscriptMode.processing => (
        t.talkRecord.detailTranscribingTitle,
        t.talkRecord.detailTranscribingBody,
      ),
      TalkRecordTranscriptMode.normal => ('', ''),
    };

    return Center(
      key: ValueKey('talk_record_transcript_degraded_${mode.name}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode == TalkRecordTranscriptMode.failed
                  ? CupertinoIcons.exclamationmark_triangle
                  : CupertinoIcons.waveform,
              size: 44,
              color: mode == TalkRecordTranscriptMode.failed
                  ? AppColors.getIosOrange(brightness)
                  : AppColors.getIosBlue(brightness).withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.medium,
                fontWeight: FontWeight.w600,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            // C-F3：降级说明可换行，不单行截断。
            Text(
              body,
              textAlign: TextAlign.center,
              maxLines: null,
              style: context.textStyle(
                FontSizeType.normal,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            if (mode == TalkRecordTranscriptMode.failed && canEdit) ...[
              const SizedBox(height: AppSpacing.medium),
              CupertinoButton(
                key: const ValueKey('talk_record_transcript_retry'),
                onPressed: onRetry,
                child: Text(t.talkRecord.detailTranscribeRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
