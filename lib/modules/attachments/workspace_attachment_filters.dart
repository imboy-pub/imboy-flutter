import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceAttachmentFilters extends ConsumerStatefulWidget {
  const WorkspaceAttachmentFilters({
    super.key,
    required this.workspaceId,
    required this.onChanged,
  });
  final EntityId workspaceId;
  final ValueChanged<Map<String, dynamic>> onChanged;
  @override
  ConsumerState<WorkspaceAttachmentFilters> createState() => _FilterState();
}

class _FilterState extends ConsumerState<WorkspaceAttachmentFilters> {
  final _choices = <String, Map<EntityId, String>>{};
  final _selection = <String, EntityId>{};
  final _person = TextEditingController();
  Timer? _debounce;
  DateTimeRange? _dates;
  Object? _error;
  bool _loading = true;
  late final _owner = UserRepoLocal.to.currentUid;
  @override
  void initState() {
    super.initState();
    unawaited(_loadChoices());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _person.dispose();
    super.dispose();
  }

  Future<void> _loadChoices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(workspaceApiProvider);
      final groups = await api.memberGroups(widget.workspaceId);
      final channels = await api.channels(widget.workspaceId);
      if (!mounted || _owner != UserRepoLocal.to.currentUid) return;
      setState(() {
        _choices['group_id'] = {
          for (final group in groups)
            entityIdOf(group.groupId): group.displayTitle,
        };
        _choices['channel_id'] = {
          for (final channel in channels) entityIdOf(channel.id): channel.name,
        };
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _emit() {
    widget.onChanged({
      ..._selection,
      'user_keyword': _person.text.trim(),
      if (_dates != null) 'from_ms': _dates!.start.millisecondsSinceEpoch,
      if (_dates != null)
        'until_ms': DateTime(
          _dates!.end.year,
          _dates!.end.month,
          _dates!.end.day + 1,
        ).millisecondsSinceEpoch,
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.attachmentManager;
    if (_loading) return const LinearProgressIndicator();
    if (_error != null) {
      return TextButton(onPressed: _loadChoices, child: Text(t.moreFailed));
    }
    return Wrap(
      spacing: AppSpacing.small,
      children: [
        _dropdown('group_id', t.allGroups),
        _dropdown('channel_id', t.allChannels),
        TextField(
          controller: _person,
          decoration: InputDecoration(labelText: t.personSearch),
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), _emit);
          },
        ),
        TextButton(
          onPressed: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              initialDateRange: _dates,
            );
            if (range == null || !mounted) return;
            setState(() => _dates = range);
            _emit();
          },
          child: Text(
            _dates == null
                ? t.dateRange
                : '${DateFormat('MM/dd').format(_dates!.start)}–${DateFormat('MM/dd').format(_dates!.end)}',
          ),
        ),
        if (_selection.isNotEmpty || _dates != null || _person.text.isNotEmpty)
          TextButton(
            onPressed: () {
              setState(() {
                _selection.clear();
                _dates = null;
                _person.clear();
              });
              _emit();
            },
            child: Text(t.clearFilters),
          ),
      ],
    );
  }

  Widget _dropdown(String key, String label) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - AppSpacing.regular * 3) / 2,
    child: DropdownButton<EntityId>(
      isExpanded: true,
      value: _selection[key] ?? '',
      items: [
        DropdownMenuItem(value: '', child: Text(label)),
        for (final choice in _choices[key]!.entries)
          DropdownMenuItem(
            value: choice.key,
            child: Text(choice.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        setState(() {
          if (value == null || value.isEmpty) {
            _selection.remove(key);
          } else {
            _selection[key] = value;
          }
          if (key == 'group_id') _selection.remove('channel_id');
          if (key == 'channel_id') _selection.remove('group_id');
        });
        _emit();
      },
    ),
  );
}
