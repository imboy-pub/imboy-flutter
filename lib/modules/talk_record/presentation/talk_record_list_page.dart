/// 面聊记录列表页（T10）。
///
/// 契约源：UI-SPEC.md §2「列表」+ DESIGN.md §3/§9：
/// - 当前空间上下文（个人=不显示工作区；企业=带当前企业，未知工作区
///   不显示、不暗示全员可读）；
/// - 全部/我创建/共享给我筛选 + 搜索（空态保留筛选与搜索 + 新建入口，
///   不把「无结果」误报「从未创建」）；
/// - 记录行：标题/时长/状态/可见范围 pill；本机草稿标记仅本机；
/// - 全局录音条占位（跨空间标注原归属；实际录音由 T09 提供）；
/// - 底部新建按钮（主 CTA，≥48pt）。
///
/// 视觉约束（CONTRACT-FREEZE-T02 §4）：
/// - C-F1：筛选分段选中态 = primaryDark 底 + 白字（5.75:1，不使用
///   #2474E5 文字叠深底）；
/// - C-F2：主按钮 primaryDark 底 + 白字 w600；
/// - C-F3：提示/状态文字不设 maxLines 截断，Wrap 自然换行；
/// - C-F4/触达：行 ≥44pt、按钮 ≥48pt。
library;

import 'dart:async';

import 'talk_record_pending_uploads.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/config/router/routes/talk_record_routes.dart'
    show kTalkRecordPreparePath;
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_recording_bar.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_ui_helpers.dart';

/// 面聊记录列表页。
class TalkRecordListPage extends ConsumerStatefulWidget {
  const TalkRecordListPage({super.key, required this.entryContext});

  /// 入口上下文（个人/企业 + 可选工作区）。
  final TalkRecordEntryContext entryContext;

  @override
  ConsumerState<TalkRecordListPage> createState() => _TalkRecordListPageState();
}

class _TalkRecordListPageState extends ConsumerState<TalkRecordListPage> {
  StreamSubscription<dynamic>? _localeSubscription;

  /// 本地搜索关键字（即时过滤已加载页，与 group_list 先例一致；
  /// 提交/刷新时随 q 送服务端）。
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bind() async {
    await ref.read(talkRecordListProvider.notifier).bind(widget.entryContext);
  }

  Future<void> _switchFilter(TalkRecordListFilter filter) async {
    await ref.read(talkRecordListProvider.notifier).setFilter(filter);
  }

  Future<void> _submitSearch(String value) async {
    setState(() => _keyword = value);
    await ref.read(talkRecordListProvider.notifier).setQuery(value);
  }

  List<TalkRecordModel> _filtered(List<TalkRecordModel> source) {
    final kw = _keyword.trim().toLowerCase();
    if (kw.isEmpty) return source;
    return source
        .where(
          (m) =>
              m.title.toLowerCase().contains(kw) ||
              (m.title.isEmpty && t.talkRecord.untitledRecord.contains(kw)),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(talkRecordListProvider);
    final filtered = _filtered(state.records);

    return IosPageTemplate(
      title: t.talkRecord.listTitle,
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => ref.read(talkRecordListProvider.notifier).reload(),
        ),
        // 空间上下文（仅企业）：无卡片轻量说明行，完整展示企业/工作区名、
        // 允许自然换行（C-F3）；个人空间为默认态不展示（§8.12）。
        // 不放导航栏 trailing —— 固定窄槽对长企业名必然截断。
        if (widget.entryContext.isOrganization)
          SliverToBoxAdapter(
            child: _ContextCaption(entryContext: widget.entryContext),
          ),
        SliverToBoxAdapter(
          child: TalkRecordPendingUploads(contextFilter: widget.entryContext),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.medium,
              AppSpacing.regular,
              AppSpacing.medium,
            ),
            child: CupertinoSearchTextField(
              key: const ValueKey('talk_record_search_field'),
              placeholder: t.talkRecord.searchHint,
              suffixMode: OverlayVisibilityMode.editing,
              onChanged: (v) => setState(() => _keyword = v),
              onSubmitted: _submitSearch,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular)
                .copyWith(bottom: AppSpacing.medium),
            child: _FilterSegments(
              current: state.filter,
              onSelected: _switchFilter,
            ),
          ),
        ),
        if (state.phase == TalkRecordListPhase.loading ||
            state.phase == TalkRecordListPhase.idle)
          const SliverFillRemaining(child: ShimmerList())
        else if (state.phase == TalkRecordListPhase.failed &&
            state.records.isEmpty)
          SliverFillRemaining(
            child: _LoadFailedView(
              // 失败重试必须强制 reload（bind 对同上下文会早退）。
              onRetry: () => ref
                  .read(talkRecordListProvider.notifier)
                  .reload(refreshing: false),
            ),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            child: _EmptyStateView(
              neverCreated:
                  state.filter == TalkRecordListFilter.all &&
                  state.query.isEmpty &&
                  _keyword.isEmpty,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xLarge),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return _RecordRow(record: filtered[index]);
              }, childCount: filtered.length),
            ),
          ),
      ],
      bottomWidget: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TalkRecordGlobalRecordingBar(currentContext: widget.entryContext),
            _CreateButton(entryContext: widget.entryContext),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 空间上下文说明行（仅企业上下文渲染；个人空间不展示）
// 无卡片、无底色：14pt 图标 + small 次级文字，完整名称自然换行（C-F3），
// 只承担「这些记录属于哪个空间」的消歧职责，不提供切换。
// ---------------------------------------------------------------------------

class _ContextCaption extends StatelessWidget {
  const _ContextCaption({required this.entryContext});

  final TalkRecordEntryContext entryContext;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(CupertinoIcons.building_2_fill, size: 14, color: color),
          ),
          const SizedBox(width: AppSpacing.tiny),
          Expanded(
            child: Text(
              _label(),
              // C-F3：名称不设 maxLines，长企业名自然换行、不省略。
              style: context.textStyle(FontSizeType.small, color: color),
            ),
          ),
        ],
      ),
    );
  }

  String _label() {
    if (!entryContext.isOrganization) return t.talkRecord.contextPersonal;
    final name = entryContext.organizationName.isNotEmpty
        ? entryContext.organizationName
        : t.talkRecord.contextOrgFallback;
    // 企业上下文：仅当入口真实携带工作区时展示（不带未知工作区）。
    return entryContext.hasWorkspace
        ? '$name · ${entryContext.workspaceName}'
        : name;
  }
}

// ---------------------------------------------------------------------------
// 筛选分段（C-F1：选中态 primaryDark 底 + 白字）
// ---------------------------------------------------------------------------

class _FilterSegments extends StatelessWidget {
  const _FilterSegments({required this.current, required this.onSelected});

  final TalkRecordListFilter current;
  final ValueChanged<TalkRecordListFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // P2：轨道容器 —— surface 底 + 2pt 内边距 + radius 10，分段块浮动其上，
    // 取代原先实心色块贴边拼接的生硬观感；选中配色仍遵守 C-F1 不动。
    return Container(
      height: AppSpacing.xxxLarge,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final filter in [
            TalkRecordListFilter.all,
            TalkRecordListFilter.owned,
            TalkRecordListFilter.shared,
          ])
            Expanded(
              child: _Segment(
                label: switch (filter) {
                  TalkRecordListFilter.owned => t.talkRecord.filterOwned,
                  TalkRecordListFilter.shared => t.talkRecord.filterShared,
                  _ => t.talkRecord.filterAll,
                },
                selected: current == filter,
                onTap: () => onSelected(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // C-F1：选中态对比度 —— 白字 on AppColors.primaryDark(#1565C0) =
    // 5.75:1（≥4.5）；明暗两态一致，不复刻原型 #2474E5-on-#142947 缺陷。
    final selectedColor = AppColors.primaryDark;
    final unselectedFg = brightness == Brightness.dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? selectedColor : null,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyle(
            FontSizeType.normal,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.onPrimary : unselectedFg,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 记录行
// ---------------------------------------------------------------------------

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final TalkRecordModel record;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final status = talkRecordStatusText(record);
    final isLocalDraft = talkRecordIsLocalDraft(record);

    return Container(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.medium,
      ),
      // C-F4/触达：整行 ≥44pt（内容高度自然超出，无 onTap——详情页由
      // T12 交付，记录列表不渲染每行箭头占位）。
      constraints: const BoxConstraints(minHeight: AppSpacing.xLarge + 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.xLarge,
            height: AppSpacing.xLarge,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(
                alpha: brightness == Brightness.dark ? 0.16 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              CupertinoIcons.waveform,
              size: AppSpacing.xLarge - 8,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.title.isNotEmpty
                      ? record.title
                      : t.talkRecord.untitledRecord,
                  style: context.textStyle(
                    FontSizeType.medium,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                // C-F3：状态/标记为 Wrap，长文案自然换行不截断。
                Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      talkRecordFormatDuration(record.durationMs),
                      style: context.textStyle(
                        FontSizeType.normal,
                        color: brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (status != null)
                      _MetaChip(
                        text: status,
                        foreground: brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    _MetaChip(
                      text: talkRecordVisibilityText(record),
                      foreground: AppColors.primaryDark,
                    ),
                    if (isLocalDraft)
                      _MetaChip(
                        text: t.talkRecord.localDraftBadge,
                        foreground: AppColors.getIosOrange(brightness),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text, required this.foreground});

  final String text;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: foreground.withValues(
          alpha: brightness == Brightness.dark ? 0.18 : 0.08,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: context.textStyle(FontSizeType.small, color: foreground),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 空态 / 失败态
// ---------------------------------------------------------------------------

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView({required this.neverCreated});

  /// true=从未创建（默认筛选+无搜索）；false=筛选/搜索无结果
  /// （不误报「从未创建」）。
  final bool neverCreated;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // P3：Hero 图标进 tinted 圆底（88pt 圆 + 40pt 图标），
            // 取代 44pt 半透明裸图标；色板沿用 primaryLight/primaryDark。
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(
                  alpha: brightness == Brightness.dark ? 0.16 : 1,
                ),
              ),
              child: Icon(
                CupertinoIcons.mic,
                size: 40,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: AppSpacing.regular),
            Text(
              neverCreated
                  ? t.talkRecord.emptyNeverCreatedTitle
                  : t.talkRecord.emptyNoMatchTitle,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.large,
                fontWeight: FontWeight.w600,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            // C-F3：副文案可换行。
            Text(
              neverCreated
                  ? t.talkRecord.emptyNeverCreatedSubtitle
                  : t.talkRecord.emptyNoMatchSubtitle,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.normal,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailedView extends StatelessWidget {
  const _LoadFailedView({required this.onRetry});

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
            key: const ValueKey('talk_record_load_retry'),
            onPressed: onRetry,
            child: Text(t.talkRecord.loadFailedAction),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 底部新建按钮（C-F2）
// ---------------------------------------------------------------------------

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.entryContext});

  final TalkRecordEntryContext entryContext;

  String get _path {
    final query = entryContext
        .toQuery()
        .entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$kTalkRecordPreparePath?$query';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: SizedBox(
        width: double.infinity,
        // 主操作 ≥48pt（UI-SPEC §1）。
        height: AppSpacing.xxxLarge,
        child: CupertinoButton(
          key: const ValueKey('talk_record_create_button'),
          // §8.4：Primary Button 圆角 14pt。
          borderRadius: BorderRadius.circular(14),
          // C-F2：白字 on AppColors.primaryDark(#1565C0) = 5.75:1（≥4.5），
          // 替代原型 #2474E5 底白字 4.46:1 的不足；字重 w600、16pt。
          color: AppColors.primaryDark,
          padding: EdgeInsets.zero,
          onPressed: () => context.push(_path),
          child: Text(
            t.talkRecord.createRecord,
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
