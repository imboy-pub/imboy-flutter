import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import '../domain/organization_models.dart';
import '../infrastructure/organization_api.dart';

/// 企业切换底部弹层：mine() 真源列表 + 当前行 + 切换失败就地展示错误。
class HumanDirectoryOrgSwitchSheet extends ConsumerStatefulWidget {
  const HumanDirectoryOrgSwitchSheet({
    super.key,
    required this.orgApi,
    required this.accountKey,
    required this.currentOrgId,
    required this.onPick,
  });

  final OrganizationApi orgApi;
  final String accountKey;
  final EntityId currentOrgId;

  /// 执行两阶段切换；返回错误文案（null = 成功，弹层关闭）。
  final Future<String?> Function(Organization target) onPick;

  @override
  ConsumerState<HumanDirectoryOrgSwitchSheet> createState() =>
      HumanDirectoryOrgSwitchSheetState();
}

class HumanDirectoryOrgSwitchSheetState
    extends ConsumerState<HumanDirectoryOrgSwitchSheet> {
  List<Organization>? _orgs;
  bool _loading = false;
  String? _error;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(currentUserProvider.select((user) => user?.uid ?? ''), (
      _,
      uid,
    ) {
      if (uid == widget.accountKey) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).pop();
        }
      });
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final organizations = await widget.orgApi.allMine();
      if (!mounted || ref.read(currentUserProvider)?.uid != widget.accountKey) {
        return;
      }
      setState(() {
        _orgs = organizations;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is OrganizationApiException
            ? '${e.message} (code=${e.code})'
            : '$e';
      });
    }
  }

  Future<void> _pick(Organization target) async {
    if (_switching || ref.read(currentUserProvider)?.uid != widget.accountKey) {
      return;
    }
    if (target.id == widget.currentOrgId) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _switching = true;
      _error = null;
    });
    final err = await widget.onPick(target);
    if (!mounted) return;
    if (err != null) {
      // 两阶段任一步失败：弹层保留，就地展示可重试错误（旧 Org 未动）。
      setState(() {
        _switching = false;
        _error = err;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    if (uid != widget.accountKey) return const SizedBox.shrink();
    final t = context.t;
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.regular),
              child: Text(
                t.organization.picker.switchEnterprise,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xLarge),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.regular),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: _load,
                      child: Text(t.common.buttonRetry),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in _orgs ?? const <Organization>[])
                      ListTile(
                        key: ValueKey('org-switch-sheet-${o.id}'),
                        dense: true,
                        leading: const Icon(CupertinoIcons.building_2_fill),
                        title: Text(
                          o.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: o.id == widget.currentOrgId
                            ? const Icon(
                                CupertinoIcons.check_mark,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: _switching ? null : () => _pick(o),
                      ),
                  ],
                ),
              ),
            if (_switching)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.small),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}
