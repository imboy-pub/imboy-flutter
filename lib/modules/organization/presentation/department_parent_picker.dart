import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/theme/default/app_spacing.dart';

Future<EntityId?> showDepartmentParentPicker(
  BuildContext context, {
  required OrganizationDepartment moving,
  required List<OrganizationDepartment> departments,
}) {
  final children = <EntityId, List<EntityId>>{};
  for (final department in departments) {
    (children[department.parentId] ??= []).add(department.id);
  }
  final excluded = <EntityId>{moving.id};
  final pending = <EntityId>[moving.id];
  while (pending.isNotEmpty) {
    for (final id in children[pending.removeLast()] ?? const <EntityId>[]) {
      if (excluded.add(id)) {
        pending.add(id);
      }
    }
  }
  final byId = {for (final d in departments) d.id: d};
  return showModalBottomSheet<EntityId>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ParentPicker(
      moving: moving,
      byId: byId,
      candidates: departments
          .where((d) => d.status == 'active' && !excluded.contains(d.id))
          .toList(growable: false),
    ),
  );
}

class _ParentPicker extends StatelessWidget {
  const _ParentPicker({
    required this.moving,
    required this.byId,
    required this.candidates,
  });
  final OrganizationDepartment moving;
  final Map<EntityId, OrganizationDepartment> byId;
  final List<OrganizationDepartment> candidates;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _choice(
                  context,
                  '',
                  context.t.organization.departments.rootLevel,
                ),
                for (final d in candidates)
                  _choice(
                    context,
                    d.id,
                    d.name,
                    subtitle: _path(
                      d,
                      context.t.organization.departments.rootLevel,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.regular),
    child: Column(
      children: [
        Text(
          context.t.organization.departments.moveDept,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          moving.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );

  Widget _choice(
    BuildContext context,
    EntityId id,
    String name, {
    String? subtitle,
  }) => CupertinoListTile(
    key: ValueKey('department-parent-${id.isEmpty ? 'root' : id}'),
    leading: Icon(
      id.isEmpty ? CupertinoIcons.building_2_fill : CupertinoIcons.folder,
    ),
    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: subtitle == null
        ? null
        : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: moving.parentId == id
        ? const Icon(CupertinoIcons.check_mark)
        : null,
    onTap: moving.parentId == id ? null : () => Navigator.of(context).pop(id),
  );

  String _path(OrganizationDepartment department, String root) {
    final names = <String>[];
    final seen = <EntityId>{department.id};
    var parent = department.parentId;
    while (parent.isNotEmpty && seen.add(parent)) {
      final ancestor = byId[parent];
      if (ancestor == null) {
        break;
      }
      names.add(ancestor.name);
      parent = ancestor.parentId;
    }
    return [if (parent.isEmpty) root, ...names.reversed].join(' › ');
  }
}
