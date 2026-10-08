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
import 'package:imboy/theme/default/app_spacing.dart';

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
        Padding(
          padding: AppSpacing.allRegular,
          child: Text(
            t.enterpriseBoundary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
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
          Text(t.centerHint),
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
    return Expanded(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_error != null)
              TextButton(
                onPressed: () => _load(more: _rows.isNotEmpty),
                child: Text(t.moreFailed),
              ),
            if (!_loading && _error == null && _rows.isEmpty && _cursor == null)
              Padding(
                padding: AppSpacing.allRegular,
                child: Text(t.emptySearch),
              ),
            ..._rows.map(
              (row) => CupertinoListTile(
                title: Text(
                  '${row['name']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_metadata(row)),
                leading: const Icon(CupertinoIcons.doc),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(row),
              ),
            ),
            if (_loading) const Center(child: CupertinoActivityIndicator()),
            if (!_loading && _cursor != null)
              TextButton(
                onPressed: () => _load(more: true),
                child: Text(t.loadMore),
              ),
          ],
        ),
      ),
    );
  }

  String _metadata(Map<String, dynamic> row) {
    final date = DateTime.tryParse('${row['created_at']}');
    return [
      row['source_name'],
      row['creator_name'] ?? row['creator_user_id'],
      '${row['size']} B',
      if (date != null) DateFormat('MM/dd HH:mm').format(date.toLocal()),
    ].join(' · ');
  }
}
