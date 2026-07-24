import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/bot_badge.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'assistant_plaza_provider.dart';

/// 搜索输入防抖时长
const _kSearchDebounce = Duration(milliseconds: 300);

/// 触底加载更多的提前量（px）
const _kLoadMoreThreshold = 200.0;

/// AI 助手广场页 —— 透明 AI 冷启动 M3 · APP-1
///
/// 顶部透明声明卡（明确 AI 身份 + E2EE 红线卖点）+ 搜索 + 分页助手卡片。
class AssistantPlazaPage extends ConsumerStatefulWidget {
  const AssistantPlazaPage({super.key});

  @override
  ConsumerState<AssistantPlazaPage> createState() => _AssistantPlazaPageState();
}

class _AssistantPlazaPageState extends ConsumerState<AssistantPlazaPage> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assistantPlazaProvider.notifier).initData();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String kwd) {
    _debounce?.cancel();
    _debounce = Timer(_kSearchDebounce, () {
      ref.read(assistantPlazaProvider.notifier).updateKwd(kwd.trim());
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.maxScrollExtent - notification.metrics.pixels <
        _kLoadMoreThreshold) {
      ref.read(assistantPlazaProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantPlazaProvider);
    final notifier = ref.read(assistantPlazaProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final showStateView =
        state.isLoading || state.error != null || state.list.isEmpty;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: IosPageTemplate(
        title: t.agent.plazaTitle,
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: notifier.refresh),
          SliverToBoxAdapter(child: _buildTransparencyBanner(context)),
          SliverToBoxAdapter(
            child: searchBar(
              context,
              hintText: t.agent.searchHint,
              onChanged: _onSearchChanged,
            ),
          ),
          if (showStateView)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AsyncStateView(
                isLoading: state.isLoading,
                error: state.error,
                isEmpty: state.list.isEmpty,
                onRetry: notifier.refresh,
                emptyText: state.kwd.isEmpty
                    ? t.agent.emptyTitle
                    : t.agent.searchEmpty,
                emptyIcon: CupertinoIcons.person_2,
                child: const SizedBox.shrink(),
              ),
            )
          else ...[
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _AssistantCard(
                  model: state.list[index],
                  brightness: brightness,
                ),
                childCount: state.list.length,
              ),
            ),
            SliverToBoxAdapter(
              child: state.isLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.regular),
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  : const SizedBox(height: 40),
            ),
          ],
        ],
      ),
    );
  }

  /// 透明声明卡：明确 AI 身份 + 「加密聊天里只有真人」的 E2EE 卖点
  Widget _buildTransparencyBanner(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.medium,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: AppColors.getIosBlue(brightness).withValues(alpha: 0.1),
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.shield,
            color: AppColors.getIosBlue(brightness),
            size: 20,
          ),
          AppSpacing.horizontalMedium,
          Expanded(
            child: Text(
              t.agent.transparencyBanner,
              style: context
                  .textStyle(
                    FontSizeType.footnote,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  )
                  .copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 助手卡片：头像 + 昵称 + AI 徽章 + 简介（2 行）+「发消息」
class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.model, required this.brightness});

  final PeopleModel model;
  final Brightness brightness;

  void _openChat(BuildContext context) {
    // 昵称/简介可能含 &、空格、emoji，必须编码防 query 串裂
    context.push(
      '/chat/${model.id}'
      '?type=C2C'
      '&title=${Uri.encodeComponent(model.nickname)}'
      '&avatar=${Uri.encodeComponent(model.avatar)}'
      '&sign=${Uri.encodeComponent(model.sign)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.getIosSeparator(brightness).withValues(alpha: 0.3),
          width: 0.33,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(imgUri: model.avatar, width: 56, height: 56),
          AppSpacing.horizontalMedium,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        model.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(
                          FontSizeType.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AppSpacing.horizontalTiny,
                    BotBadge(accountType: model.accountType),
                  ],
                ),
                AppSpacing.verticalSmall,
                Text(
                  model.sign,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                AppSpacing.verticalSmall,
                Align(
                  alignment: Alignment.centerRight,
                  child: RoundedElevatedButton(
                    text: t.agent.sendMessage,
                    highlighted: true,
                    size: const Size(96, 44),
                    borderRadius: AppRadius.button,
                    onPressed: () => _openChat(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
