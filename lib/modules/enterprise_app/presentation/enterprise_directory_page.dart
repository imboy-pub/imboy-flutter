/// 受限目录检索页（FULL-05 / INT-16、INT-17 的界面与状态）。
///
/// 硬边界「UI 侧不得提供全量导出入口」的界面层落法：
/// - 本页只有**一个**搜索动作 + **一个**「加载更多」动作，两者都带
///   cursor 且页大小恒有界（[kDirectoryMaxPageSize]）；
/// - **不渲染**任何导出/下载/全量按钮，也没有对应的回调参数可注入
///   （不是「隐藏了按钮」，而是**不存在**入口——测试以公开成员集合 +
///   源码命名黑名单双向钉死）；
/// - 页尾常驻 [t.enterpriseApp.directoryBounded] 说明，向用户如实交代边界。
///
/// 颜色/间距/字号一律走 token。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageRoute;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_app/domain/enterprise_app_error.dart';
import 'package:imboy/modules/enterprise_app/domain/enterprise_directory.dart';
import 'package:imboy/modules/enterprise_app/infrastructure/enterprise_app_api.dart';
import 'package:imboy/modules/enterprise_app/presentation/enterprise_error_view.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class EnterpriseDirectoryPage extends StatefulWidget {
  const EnterpriseDirectoryPage({
    super.key,
    this.api,
    this.workspaceId = '',
    this.pageSize = kDirectoryDefaultPageSize,
  });

  final EnterpriseAppApi? api;

  /// 可选 workspace 边界（INT-17）。
  final EntityId workspaceId;

  /// 页大小（调用方不得传超上限值；超限本地即拒，见 [validateDirectoryPageSize]）。
  final int pageSize;

  @override
  State<EnterpriseDirectoryPage> createState() =>
      _EnterpriseDirectoryPageState();
}

class _EnterpriseDirectoryPageState extends State<EnterpriseDirectoryPage> {
  late final EnterpriseAppApi _api = widget.api ?? EnterpriseAppApi();

  final List<DirectoryMemberItem> _items = <DirectoryMemberItem>[];
  String _cursor = '';
  bool _hasMore = false;
  bool _loadedOnce = false;
  bool _busy = false;
  EnterpriseErrorUiState? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  /// 唯一的取数动作：带 cursor 的一页（首拉 cursor 为空）。
  Future<void> _loadMore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final EnterpriseDirectoryResult<DirectoryMemberItem> page = await _api
          .directoryUsersPage(
            cursor: _cursor,
            pageSize: widget.pageSize,
            workspaceId: widget.workspaceId,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = !page.isEnd;
        _loadedOnce = true;
        _busy = false;
      });
    } on EnterpriseAppApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.uiState;
        _loadedOnce = true;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.enterpriseApp.directoryTitle)),
      body: Column(
        children: <Widget>[
          // 常驻边界说明：用户随时可见「不提供全量导出」。
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
              vertical: AppSpacing.small,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  CupertinoIcons.info_circle,
                  size: AppSpacing.regular,
                  color: AppColors.slateText,
                ),
                AppSpacing.horizontalTiny,
                Expanded(
                  child: Text(
                    t.enterpriseApp.directoryBounded,
                    style: context.textStyle(
                      FontSizeType.tiny,
                      color: AppColors.slateText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    final EnterpriseErrorUiState? error = _error;
    if (error != null) {
      return SingleChildScrollView(
        child: EnterpriseErrorView(state: error, onRetry: _loadMore),
      );
    }
    if (_loadedOnce && _items.isEmpty) {
      return EnterpriseEmptyView(
        message: t.enterpriseApp.directoryEmpty,
        note: t.enterpriseApp.directoryBounded,
      );
    }
    return ListView.builder(
      itemCount: _items.length + 1,
      itemBuilder: (BuildContext ctx, int index) {
        if (index == _items.length) return _footer();
        final DirectoryMemberItem item = _items[index];
        return ListTile(
          title: Text(item.userId),
          subtitle: item.externalUserId.isEmpty
              ? null
              : Text(item.externalUserId),
        );
      },
    );
  }

  Widget _footer() {
    if (_busy && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.large),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Center(
          child: Text(
            t.enterpriseApp.directoryEnd,
            style: context.textStyle(
              FontSizeType.tiny,
              color: AppColors.slateText,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Center(
        child: TextButton(
          onPressed: _busy ? null : _loadMore,
          child: Text(t.enterpriseApp.directoryLoadMore),
        ),
      ),
    );
  }
}

/// 打开受限目录页（供路由/入口调用）。
Future<void> openEnterpriseDirectoryPage(
  BuildContext context, {
  EnterpriseAppApi? api,
  EntityId workspaceId = '',
}) {
  return Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) =>
          EnterpriseDirectoryPage(api: api, workspaceId: workspaceId),
    ),
  );
}
