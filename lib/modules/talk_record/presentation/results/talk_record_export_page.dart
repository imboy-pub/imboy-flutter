/// 面聊记录（talk_record）导出页（T21）。
///
/// 契约源：UI-SPEC §2「导出」行 + §3 角色表 + §4 状态文案；DESIGN §9：
/// - 格式选择 txt/md（V1 冻结；不含音频/未授权参与者信息）；
/// - 可导出判定 = 能力（caps.export：owner 策略允许 / grant.allow_export）
///   ∩ 策略（实例/企业；owner 不能绕过，§8）；禁用态 disabled + 原因；
/// - 生成状态：排队/就绪（排队不伪造完成时刻，§3）；到期倒计时展示
///   （到期时刻 + 剩余分钟，随刷新更新——组件级近似，无周期定时器）；
/// - 主动确认「独立副本无法收回」后才可生成（UI-SPEC §2 冻结）；
/// - 下载入口：短时受控 URL（fixture 示例，不产生真实文件）；
///   真实下载前每次重验权限（§4）；
/// - 到期 410 视图 + 重新生成入口（§4 到期 410；不可开永久 URL）。
///
/// 组件阶段：所有数据经 fixture/服务注入；真实导出链路待 T19/T20 联调。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_result_views.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_providers.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_invalid_view.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_views.dart'
    show talkRecordShareCardDecoration, talkRecordShareFormatDate;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 导出页。
class TalkRecordExportPage extends ConsumerStatefulWidget {
  const TalkRecordExportPage({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<TalkRecordExportPage> createState() =>
      _TalkRecordExportPageState();
}

class _TalkRecordExportPageState extends ConsumerState<TalkRecordExportPage> {
  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(talkRecordExportCenterProvider.notifier)
          .bind(widget.recordId, force: true);
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = ref.watch(talkRecordExportCenterProvider);
    final Widget body;
    switch (center.phase) {
      case TalkRecordExportPhase.idle:
      case TalkRecordExportPhase.loading:
        body = const ShimmerList();
      case TalkRecordExportPhase.noAccess:
        // §11.3：无权限/不存在统一失效视图（不泄露信息）。
        body = const TalkRecordInvalidView();
      case TalkRecordExportPhase.failed:
        body = _FailedView(
          onRetry: () =>
              ref.read(talkRecordExportCenterProvider.notifier).reload(),
        );
      case TalkRecordExportPhase.ready:
        body = _ExportBody(recordId: widget.recordId);
    }
    return IosPageTemplate(title: t.talkRecord.exportTitle, body: body);
  }
}

class _ExportBody extends ConsumerWidget {
  const _ExportBody({required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = ref.watch(talkRecordExportCenterProvider);
    if (center.artifactPhase == TalkRecordExportArtifactPhase.expired) {
      // 到期 410 视图（§4）：重新生成入口。
      return TalkRecordOperationResultView(
        tone: TalkRecordResultTone.failure,
        title: t.talkRecord.exportExpiredTitle,
        body: t.talkRecord.exportExpiredBody,
        actions: [
          TalkRecordResultAction(
            key: const ValueKey('talk_record_export_regenerate'),
            label: t.talkRecord.exportRegenerate,
            primary: true,
            onPressed: () {
              ref
                  .read(talkRecordExportCenterProvider.notifier)
                  .prepareRegenerate();
            },
          ),
          TalkRecordResultAction(
            key: const ValueKey('talk_record_export_expired_back'),
            label: t.talkRecord.resultBack,
            onPressed: () => _backToDetail(context),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FormatCard(center: center),
          const SizedBox(height: AppSpacing.xLarge),
          if (!center.canExport)
            _DisabledCard(reason: center.disableReason)
          else ...[
            _IndependentCopyArea(),
            if (center.writePhase == TalkRecordExportWritePhase.conflict)
              TalkRecordResultsBanner(
                key: const ValueKey('talk_record_export_conflict_banner'),
                text: t.talkRecord.exportConflictHint,
                color: AppColors.getIosOrange(Theme.of(context).brightness),
              ),
            if (center.artifactPhase == TalkRecordExportArtifactPhase.failed)
              TalkRecordResultsBanner(
                key: const ValueKey('talk_record_export_failed_banner'),
                text: t.talkRecord.exportFailedBody,
                color: AppColors.getIosOrange(Theme.of(context).brightness),
              ),
            _ArtifactCard(center: center),
            const SizedBox(height: AppSpacing.small),
            _GenerateButton(center: center),
            const SizedBox(height: AppSpacing.small),
            _FixtureHint(),
          ],
        ],
      ),
    );
  }

  void _backToDetail(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('$kTalkRecordDetailPath/$recordId');
    }
  }
}

/// 格式卡（禁用态可读不可选）。
class _FormatCard extends ConsumerWidget {
  const _FormatCard({required this.center});

  final TalkRecordExportCenterState center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('talk_record_export_format_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: talkRecordShareCardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.exportFormatSectionTitle,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          TalkRecordExportFormatSegment(
            current: center.format,
            enabled: center.canExport,
            onSelect: (f) =>
                ref.read(talkRecordExportCenterProvider.notifier).setFormat(f),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            t.talkRecord.exportFormatHint,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.footnote,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 禁用原因卡（可导出判定失败时唯一主内容；不渲染生成按钮）。
class _DisabledCard extends StatelessWidget {
  const _DisabledCard({required this.reason});

  final TalkRecordExportDisableReason reason;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = AppColors.getIosOrange(brightness);
    return Container(
      key: const ValueKey('talk_record_export_disabled_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: talkRecordShareCardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.talkRecord.exportCapabilitySectionTitle,
            style: context.textStyle(
              FontSizeType.footnote,
              fontWeight: FontWeight.w600,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Row(
            children: [
              Icon(CupertinoIcons.lock, size: AppSpacing.xLarge, color: color),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  talkRecordExportDisableReasonText(reason),
                  // C-F3：原因可换行。
                  maxLines: null,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 生成状态卡：排队/就绪 + 到期时刻与剩余分钟（组件级倒计时近似：
/// 无周期定时器，随状态变化/刷新更新；真实到期以服务端 410 为准）。
class _ArtifactCard extends ConsumerWidget {
  const _ArtifactCard({required this.center});

  final TalkRecordExportCenterState center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    if (center.artifactPhase == TalkRecordExportArtifactPhase.idle ||
        center.artifactPhase == TalkRecordExportArtifactPhase.creating ||
        center.artifactPhase == TalkRecordExportArtifactPhase.failed) {
      return const SizedBox.shrink();
    }
    final queued = center.artifactPhase == TalkRecordExportArtifactPhase.queued;
    final expiresAt = center.artifact?.expiresAt;
    final remaining = expiresAt?.difference(DateTime.now()).inMinutes;
    return Container(
      key: ValueKey(
        'talk_record_export_artifact_card_'
        '${center.artifactPhase.name}',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: talkRecordShareCardDecoration(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                queued
                    ? CupertinoIcons.hourglass
                    : CupertinoIcons.checkmark_seal,
                size: AppSpacing.xLarge,
                color: queued
                    ? (brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary)
                    : AppColors.getIosGreen(brightness),
              ),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  queued
                      ? t.talkRecord.exportQueuedTitle
                      : t.talkRecord.exportReadyTitle,
                  maxLines: null,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            queued
                ? t.talkRecord.exportQueuedBody
                : t.talkRecord.exportReadyBody,
            maxLines: null,
            style: context.textStyle(
              FontSizeType.footnote,
              color: brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          if (!queued && expiresAt != null) ...[
            const SizedBox(height: AppSpacing.tiny),
            Text(
              '${t.talkRecord.exportExpiresAt(date: talkRecordShareFormatDate(expiresAt))}'
              '${remaining != null && remaining > 0 ? ' · ${t.talkRecord.exportRemaining(minutes: remaining)}' : ''}',
              maxLines: null,
              style: context.textStyle(
                FontSizeType.footnote,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
          if (queued)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: CupertinoButton(
                key: const ValueKey('talk_record_export_refresh_state'),
                minimumSize: const Size(120, 44),
                onPressed: () => ref
                    .read(talkRecordExportCenterProvider.notifier)
                    .refreshExportState(),
                child: Text(t.talkRecord.exportRefreshState),
              ),
            ),
          if (!queued)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: _DownloadArea(center: center),
            ),
        ],
      ),
    );
  }
}

/// 下载区（fixture：取链接 → 展示示例；失败横幅；410 由上层到期视图接管）。
class _DownloadArea extends ConsumerWidget {
  const _DownloadArea({required this.center});

  final TalkRecordExportCenterState center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          // C-F2：主操作 ≥48。
          height: 48,
          child: CupertinoButton(
            key: const ValueKey('talk_record_export_download'),
            minimumSize: const Size.fromHeight(48),
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(8),
            onPressed:
                center.downloadPhase == TalkRecordExportDownloadPhase.fetching
                ? null
                : () => ref
                      .read(talkRecordExportCenterProvider.notifier)
                      .requestDownload(),
            child: Text(
              center.downloadPhase == TalkRecordExportDownloadPhase.fetching
                  ? t.talkRecord.exportDownloading
                  : t.talkRecord.exportDownload,
              style: context.textStyle(
                FontSizeType.body,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ),
        if (center.downloadPhase == TalkRecordExportDownloadPhase.fetched)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.small),
            child: TalkRecordResultsBanner(
              key: const ValueKey('talk_record_export_downloaded_banner'),
              text: t.talkRecord.exportDownloadReady,
              color: AppColors.primaryDark,
            ),
          ),
        if (center.downloadPhase == TalkRecordExportDownloadPhase.cancelled)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.small),
            child: TalkRecordResultsBanner(
              key: const ValueKey('talk_record_export_cancelled_banner'),
              text: t.talkRecord.exportDownloadCancelled,
              color: AppColors.getTextSecondary(brightness),
            ),
          ),
        if (center.downloadPhase == TalkRecordExportDownloadPhase.failed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.small),
            child: TalkRecordResultsBanner(
              key: const ValueKey('talk_record_export_download_failed_banner'),
              text: t.talkRecord.exportDownloadFailed,
              color: AppColors.getIosOrange(brightness),
            ),
          ),
      ],
    );
  }
}

/// 生成主按钮（可导出 + 已确认独立副本；未确认 disabled）。
class _GenerateButton extends ConsumerWidget {
  const _GenerateButton({required this.center});

  final TalkRecordExportCenterState center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      // C-F2：主操作 ≥48 + primaryDark 实底白字。
      height: 48,
      child: CupertinoButton(
        key: const ValueKey('talk_record_export_generate'),
        minimumSize: const Size.fromHeight(48),
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(8),
        // canGenerate=false 时 onPressed null = disabled（CupertinoButton
        // 惯例；独立副本未确认/生成中/已有产物均禁用）。
        onPressed: center.canGenerate
            ? () => ref
                  .read(talkRecordExportCenterProvider.notifier)
                  .createExport()
            : null,
        child: Text(
          center.creating
              ? t.talkRecord.exportGenerating
              : t.talkRecord.exportGenerate,
          style: context.textStyle(
            FontSizeType.body,
            fontWeight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// 独立副本确认区（仅可导出时出现；主动确认后才可生成）。
class _IndependentCopyArea extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = ref.watch(talkRecordExportCenterProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xLarge),
      child: TalkRecordIndependentCopySection(
        acked: center.independentCopyAcked,
        onChanged: (v) => ref
            .read(talkRecordExportCenterProvider.notifier)
            .setIndependentCopyAcked(v),
      ),
    );
  }
}

/// 组件阶段诚实标注（fixture 示例，不产生真实文件）。
class _FixtureHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Text(
      t.talkRecord.exportFixtureHint,
      maxLines: null,
      textAlign: TextAlign.center,
      style: context.textStyle(
        FontSizeType.caption2,
        color: brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.onRetry});

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
            key: const ValueKey('talk_record_export_retry'),
            onPressed: onRetry,
            child: Text(t.talkRecord.loadFailedAction),
          ),
        ],
      ),
    );
  }
}
