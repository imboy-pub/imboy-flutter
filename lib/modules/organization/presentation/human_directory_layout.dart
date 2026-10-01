import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_breakpoint.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 展示当前可验证的组织路径与子部门，不猜测尚未加载的全树。
class HumanDirectoryLayout extends StatelessWidget {
  const HumanDirectoryLayout({
    super.key,
    required this.ancestors,
    required this.onAncestor,
    required this.departments,
    required this.members,
  });
  final List<String> ancestors;
  final ValueChanged<int> onAncestor;
  final List<Widget> departments;
  final List<Widget> members;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          resolveWorkspaceShellLayout(constraints.maxWidth) ==
          WorkspaceShellLayout.desktop;
      if (!wide) {
        return _pane('org-directory-mobile-list', [
          if (ancestors.length > 1) _path(context),
          ...departments,
          ...members,
        ]);
      }
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _pane('org-directory-departments-pane', [
              _path(context),
              ...departments,
            ]),
          ),
          const VerticalDivider(width: AppSpacing.tiny),
          Expanded(
            flex: 3,
            child: _pane('org-directory-members-pane', members),
          ),
        ],
      );
    },
  );

  Widget _pane(String key, List<Widget> children) => ListView(
    key: ValueKey(key),
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
    children: children,
  );

  Widget _path(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
    child: LayoutBuilder(
      builder: (context, constraints) => Wrap(
        children: [
          for (var i = 0; i < ancestors.length; i++)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: _pathNode(context, i),
            ),
        ],
      ),
    ),
  );

  Widget _pathNode(BuildContext context, int index) {
    final current = index == ancestors.length - 1;
    return CupertinoButton(
      key: ValueKey('org-directory-path-$index'),
      padding: const EdgeInsets.all(AppSpacing.small),
      minimumSize: const Size(44, 44),
      onPressed: current ? null : () => onAncestor(index),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index > 0) ...[
            const Icon(CupertinoIcons.chevron_right, color: AppColors.iosGray),
            AppSpacing.horizontalTiny,
          ],
          Flexible(
            child: Text(
              ancestors[index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: current
                    ? Theme.of(context).colorScheme.onSurface
                    : AppColors.iosBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
