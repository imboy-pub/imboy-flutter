import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'workspace_attachment_filters.dart';

class WorkspaceAttachmentsPage extends ConsumerWidget {
  const WorkspaceAttachmentsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(currentWorkspaceProvider);
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    // 唯一入口是企业工作台资源项（enterprise_shell_page _resourceEntry），
    // 外层已提供 Scaffold + 「附件」标题栏——本页直接返回内容，自带
    // AppBar 会叠出双层标题。
    return ws == null || uid.isEmpty
        ? Center(child: Text(context.t.workspace.emptyNoWorkspace))
        : _AttachmentIndex(
            key: ValueKey('${ws.id}:$uid'),
            workspaceId: ws.id,
            owner: uid,
          );
  }
}

class _AttachmentIndex extends ConsumerStatefulWidget {
  const _AttachmentIndex({
    super.key,
    required this.workspaceId,
    required this.owner,
  });
  final EntityId workspaceId;
  final EntityId owner;
  @override
  ConsumerState<_AttachmentIndex> createState() => _AttachmentIndexState();
}

class _AttachmentIndexState extends ConsumerState<_AttachmentIndex> {
  final _search = TextEditingController();
  final _rows = <Map<String, dynamic>>[];
  Map<String, dynamic> _filters = {};
  Object? _error;
  EntityId? _cursor;
  int _generation = 0;
  bool _loading = false;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _cursor == null)) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _rows.clear();
        _cursor = null;
      }
    });
    try {
      final result = await ref.read(workspaceApiProvider).attachments(
        widget.workspaceId,
        {
          ..._filters,
          'keyword': _search.text.trim(),
          if (more) 'cursor': _cursor,
        },
      );
      if (!mounted ||
          generation != _generation ||
          widget.owner != UserRepoLocal.to.currentUid) {
        return;
      }
      final rows = (result['items'] as List).map(
        (row) => Map<String, dynamic>.from(row as Map),
      );
      setState(() {
        _rows.addAll(rows);
        _cursor = result['next_cursor'] == null
            ? null
            : entityIdOf(result['next_cursor']);
      });
    } on Exception catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    try {
      if (row['cipher'] != null && row['scope'] == 'group') {
        await context.push(
          '/chat/${row['scope_ref']}',
          extra: {'type': 'C2G', 'title': row['source_name']},
        );
        return;
      }
      final uri = await AssetsService.workspaceAttachmentUrl(
        widget.workspaceId,
        entityIdOf(row['id']),
      );
      if (!mounted || widget.owner != UserRepoLocal.to.currentUid) return;
      if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
        throw Exception('Open failed');
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t.attachmentManager.unavailableSource),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.attachmentManager;
    return Column(
      children: [
        _header(),
        _content(),
        _boundaryNote(context, t.enterpriseBoundary),
      ],
    );
  }

  Widget _header() {
    final t = context.t.attachmentManager;
    return Padding(
      padding: AppSpacing.allRegular,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.centerHint,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosGray,
            ),
          ),
          AppSpacing.verticalSmall,
          CupertinoSearchTextField(
            controller: _search,
            placeholder: t.searchHint,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 300),
                () => _load(),
              );
            },
          ),
          AppSpacing.verticalSmall,
          WorkspaceAttachmentFilters(
            workspaceId: widget.workspaceId,
            onChanged: (filters) {
              _filters = filters;
              unawaited(_load());
            },
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final t = context.t.attachmentManager;
    final firstScreenLoading =
        _loading && _rows.isEmpty && _error == null && _cursor == null;
    final empty =
        !_loading && _error == null && _rows.isEmpty && _cursor == null;
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.regular),
          children: [
            if (_error != null && _rows.isEmpty) _errorState(t.loadFailed),
            if (firstScreenLoading)
              // 首屏骨架：图标块 + 两行文本的占位节奏，避免生硬的整页菊花。
              for (var i = 0; i < 4; i++) const _SkeletonRow(),
            if (empty) _emptyState(t.emptySearch, t.emptyHint),
            if (_rows.isNotEmpty && _error == null && _cursor == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.regular,
                  0,
                  AppSpacing.regular,
                  AppSpacing.small,
                ),
                child: Text(
                  t.resultCount(count: _rows.length),
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.iosGray,
                  ),
                ),
              ),
            ..._rows.map(_row),
            if (_error != null && _rows.isNotEmpty)
              Center(
                child: TextButton(
                  onPressed: () => _load(more: true),
                  child: Text(t.moreFailed),
                ),
              ),
            if (_loading && _rows.isNotEmpty)
              const Center(child: CupertinoActivityIndicator()),
            if (!_loading && _cursor != null)
              Center(
                child: TextButton(
                  onPressed: () => _load(more: true),
                  child: Text(t.loadMore),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 居中错误态（首屏失败）：图标 + 文案 + 显式重试按钮（pull-to-refresh
  /// 是隐藏可供件，不能是唯一重试路径）。
  Widget _errorState(String text) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.xxxLarge,
      ),
      child: Column(
        key: const ValueKey('ws-attachments-error'),
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: AppSizes.iconSizeXLarge,
            color: AppColors.getIosOrange(brightness),
          ),
          AppSpacing.verticalRegular,
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.normal,
              color: AppColors.iosGray,
            ),
          ),
          AppSpacing.verticalRegular,
          TextButton.icon(
            key: const ValueKey('ws-attachments-retry'),
            onPressed: () => unawaited(_load()),
            icon: const Icon(CupertinoIcons.refresh, size: 16),
            label: Text(context.t.attachmentManager.retryAction),
          ),
        ],
      ),
    );
  }

  /// 居中空态：图标 + 主文案 + 行动建议（调整关键词/筛选）。
  Widget _emptyState(String title, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.xxxLarge,
      ),
      child: Column(
        key: const ValueKey('ws-attachments-empty'),
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.iosGray6,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.search,
              size: AppSizes.iconSizeMedium,
              color: AppColors.iosGray,
            ),
          ),
          AppSpacing.verticalRegular,
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textStyle(FontSizeType.normal),
          ),
          AppSpacing.verticalTiny,
          Text(
            hint,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosGray,
            ),
          ),
        ],
      ),
    );
  }

  /// 附件行：类型化图标块 + 名称 + 元数据（来源 · 上传人 · 大小 · 时间）。
  Widget _row(Map<String, dynamic> row) {
    final name = '${row['name']}';
    final brightness = Theme.of(context).brightness;
    final (icon, color) = _fileVisual(name, brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        0,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.listItem,
        child: InkWell(
          borderRadius: AppRadius.listItem,
          onTap: () => _open(row),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(FontSizeType.normal),
                      ),
                      const SizedBox(height: AppSpacing.tiny),
                      Text(
                        _metadata(row),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: AppColors.iosGray,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: AppSizes.iconSizeXSmall,
                  color: AppColors.iosGray3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 文件类型视觉（扩展名 → 图标 + 语义色，皆取应用 iOS 色板）。
  static (IconData, Color) _fileVisual(String name, Brightness brightness) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    switch (ext) {
      case 'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'heic' || 'bmp':
        return (CupertinoIcons.photo, AppColors.getIosGreen(brightness));
      case 'pdf':
        return (CupertinoIcons.doc_richtext, AppColors.getIosRed(brightness));
      case 'doc' || 'docx' || 'txt' || 'md' || 'rtf' || 'pages':
        return (CupertinoIcons.doc_text, AppColors.getIosBlue(brightness));
      case 'xls' || 'xlsx' || 'csv' || 'numbers':
        return (CupertinoIcons.table, AppColors.getIosGreen(brightness));
      case 'ppt' || 'pptx' || 'key':
        return (CupertinoIcons.doc_chart, AppColors.getIosOrange(brightness));
      case 'zip' || 'rar' || '7z' || 'tar' || 'gz':
        return (CupertinoIcons.archivebox, AppColors.getIosOrange(brightness));
      case 'mp4' || 'mov' || 'avi' || 'mkv':
        return (CupertinoIcons.film, AppColors.getIosPurple(brightness));
      case 'mp3' || 'wav' || 'm4a' || 'aac':
        return (CupertinoIcons.music_note, AppColors.getIosPurple(brightness));
      default:
        return (CupertinoIcons.doc, AppColors.iosGray);
    }
  }

  /// 元数据：来源 · 上传人 · 人性化大小 · 时间（跨年带年份）；空段
  /// 丢弃后再 join，避免「来源 ·  · 时间」双分隔符。
  String _metadata(Map<String, dynamic> row) {
    final date = DateTime.tryParse('${row['created_at']}');
    final now = DateTime.now();
    final dateText = date == null
        ? ''
        : date.year == now.year
        ? DateFormat('MM/dd HH:mm').format(date.toLocal())
        : DateFormat('yyyy/MM/dd HH:mm').format(date.toLocal());
    final source = row['source_name'];
    final creator = row['creator_name'] ?? row['creator_user_id'];
    final parts = [
      if (source != null && '$source'.isNotEmpty) '$source',
      if (creator != null && '$creator'.isNotEmpty) '$creator',
      _formatSize(row['size']),
      if (dateText.isNotEmpty) dateText,
    ].where((part) => part.isNotEmpty).toList(growable: false);
    return parts.join(' · ');
  }

  /// 字节数人性化：B/KB/MB/GB（1 位小数去尾零）。
  static String _formatSize(Object? bytes) {
    final value = bytes is num ? bytes.toDouble() : double.tryParse('$bytes');
    if (value == null || value < 0) return '';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = value;
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final text = unit == 0
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    return '$text ${units[unit]}';
  }

  /// 底部边界声明：信息条容器（与列表内容区分隔，弱化但不失联）。
  Widget _boundaryNote(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        0,
        AppSpacing.regular,
        AppSpacing.regular,
      ),
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurfaceContainerLow,
        borderRadius: AppRadius.input,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.info,
            size: AppSizes.iconSizeXSmall,
            color: AppColors.iosGray,
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              text,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 首屏加载骨架行：静态占位（图标块 + 标题条 + 副文本条），无动画噪声。
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final block = AppColors.iosGray6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        0,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: block,
              borderRadius: AppRadius.borderRadiusSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.55,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: AppRadius.borderRadiusTiny,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                FractionallySizedBox(
                  widthFactor: 0.35,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: AppRadius.borderRadiusTiny,
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
}
