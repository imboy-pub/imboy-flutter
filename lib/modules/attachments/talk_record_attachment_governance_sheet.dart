import 'dart:async';
import 'dart:convert';

import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_app/public.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_result_views.dart'
    show talkRecordCleanupTitle;
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'talk_record_attachment_governance_api.dart';

class TalkAttachmentGovernanceSheet extends ConsumerStatefulWidget {
  const TalkAttachmentGovernanceSheet({
    super.key,
    required this.organizationId,
    required this.recordId,
    required this.attachmentId,
    this.workspaceId,
  });
  final String organizationId;
  final String recordId;
  final String attachmentId;
  final String? workspaceId;
  @override
  ConsumerState<TalkAttachmentGovernanceSheet> createState() =>
      _GovernanceState();
}

class _GovernanceState extends ConsumerState<TalkAttachmentGovernanceSheet> {
  final _reason = TextEditingController();
  final _until = TextEditingController();
  TalkAttachmentGovernanceSnapshot? _snapshot;
  late final String _uid;
  late final int _epoch;
  late final String _endpoint;
  late final (String, String, String, String?) _identity;
  DateTime? _selectedUntil;
  late final VoidCallback _removeAuth;
  ProviderSubscription<WorkspaceShellState>? _contextSubscription;
  int _generation = 0;
  bool _busy = true;
  bool _conflict = false;
  String? _error;
  String? _intentKey;
  String? _intent;
  Route<dynamic>? _confirmation;

  bool _live(int generation) {
    if (!mounted || generation != _generation) return false;
    return (
              widget.organizationId,
              widget.recordId,
              widget.attachmentId,
              widget.workspaceId,
            ) ==
            _identity &&
        mounted &&
        generation == _generation &&
        UserRepoLocal.to.currentUid == _uid &&
        UserRepoLocal.to.isCurrentSession(_epoch) &&
        !UserRepoLocal.to.isAuthTransitioning &&
        Env().apiBaseUrl == _endpoint &&
        (widget.workspaceId == null ||
            ref.read(workspaceShellProvider).currentWorkspaceId ==
                widget.workspaceId);
  }

  @override
  void initState() {
    super.initState();
    _identity = (
      widget.organizationId,
      widget.recordId,
      widget.attachmentId,
      widget.workspaceId,
    );
    _uid = UserRepoLocal.to.currentUid;
    _epoch = UserRepoLocal.to.sessionGeneration;
    _endpoint = Env().apiBaseUrl;
    _removeAuth = ref.read(talkRecordAuthSubscribeProvider)(_invalidate);
    if (widget.workspaceId != null) {
      _contextSubscription = ref.listenManual(workspaceShellProvider, (
        _,
        next,
      ) {
        if (next.currentWorkspaceId != widget.workspaceId) _invalidate();
      });
    }
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant TalkAttachmentGovernanceSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((
          widget.organizationId,
          widget.recordId,
          widget.attachmentId,
          widget.workspaceId,
        ) !=
        _identity) {
      _invalidate();
    }
  }

  void _invalidate() {
    if (!mounted) return;
    _generation++;
    _reason.clear();
    _until.clear();
    _selectedUntil = null;
    setState(() {
      _forgetGovernance();
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final confirmation = _confirmation;
    if (confirmation?.isActive == true) navigator.removeRoute(confirmation!);
    final route = ModalRoute.of(context);
    if (route?.isActive == true) navigator.removeRoute(route!);
  }

  bool _denied(Object error) =>
      error is WorkspaceApiException &&
      const [401, 403, 404, 410].contains(error.code);

  void _forgetGovernance() {
    _snapshot = null;
    _intentKey = null;
    _intent = null;
    _conflict = false;
    _reason.clear();
    _until.clear();
    _selectedUntil = null;
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await ref
          .read(talkAttachmentGovernanceApiProvider)
          .read(widget.organizationId, widget.recordId, widget.attachmentId);
      if (!_live(generation)) return;
      setState(() {
        _snapshot = value;
        _conflict = false;
        _intentKey = null;
        _intent = null;
      });
    } catch (error) {
      if (_live(generation)) {
        setState(() {
          if (_denied(error)) _forgetGovernance();
          _error = t.attachmentManager.loadFailed;
        });
      }
    } finally {
      if (_live(generation)) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String label, String op) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            _confirmation = ModalRoute.of(ctx);
            return AlertDialog(
              title: Text(label),
              content: op == 'purge'
                  ? Text(t.attachmentManager.governancePurgeConfirm)
                  : null,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(t.common.buttonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(t.common.buttonConfirm),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Map<String, dynamic>? _body(String op) {
    if (op == 'hold') {
      final reason = _reason.text.trim();
      if (reason.isEmpty || reason.runes.length > 200) {
        return null;
      }
      return {'op': op, 'reason': reason};
    }
    if (op == 'extend_retention') {
      final until = _selectedUntil;
      final old = DateTime.tryParse(_snapshot!.retention.retentionUntil);
      if (until == null ||
          !until.isAfter(DateTime.now()) ||
          (old != null && !until.isAfter(old))) {
        return null;
      }
      return {'op': op, 'retention_until': until.toUtc().toIso8601String()};
    }
    return {'op': op};
  }

  Future<void> _pickUntil() async {
    if (_busy) return;
    final generation = _generation;
    final now = DateTime.now();
    final old = DateTime.tryParse(_snapshot!.retention.retentionUntil)
        ?.toLocal();
    final first = old != null && old.isAfter(now) ? old : now;
    final last = now.add(const Duration(days: 3650));
    if (first.isAfter(last)) {
      setState(() => _error = t.attachmentManager.governanceExtendUntil);
      return;
    }
    setState(() => _busy = true);
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedUntil != null && _selectedUntil!.isAfter(first)
          ? _selectedUntil!
          : first,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) {
        _confirmation = ModalRoute.of(ctx);
        return child!;
      },
    );
    _confirmation = null;
    if (!_live(generation)) return;
    if (date == null) {
      setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedUntil ?? first),
      builder: (ctx, child) {
        _confirmation = ModalRoute.of(ctx);
        return child!;
      },
    );
    _confirmation = null;
    if (!_live(generation)) return;
    setState(() {
      _busy = false;
      if (time != null) {
        _selectedUntil = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        _until.text =
            '${DateFormat.yMd().add_jm().format(_selectedUntil!)} '
            '(${_selectedUntil!.timeZoneName})';
      }
    });
  }

  Future<void> _submit(String op, String label) async {
    if (_busy || _snapshot == null || _conflict) return;
    final body = _body(op);
    if (body == null) {
      setState(
        () => _error = op == 'hold'
            ? t.attachmentManager.governanceHoldReason
            : t.attachmentManager.governanceExtendUntil,
      );
      return;
    }
    final generation = _generation;
    // Lock before confirmation, so repeated taps cannot enqueue multiple operations.
    setState(() => _busy = true);
    final confirmed = await _confirm(label, op);
    _confirmation = null;
    if (!_live(generation)) return;
    if (!confirmed) {
      setState(() {
        _busy = false;
        _intentKey = null;
        _intent = null;
      });
      return;
    }
    final etag = _snapshot!.etag;
    final key = '$etag:${jsonEncode(body)}';
    if (_intentKey != key) {
      _intentKey = key;
      _intent = TalkRecordIds.newUuidV4();
    }
    try {
      final value = await ref
          .read(talkAttachmentGovernanceApiProvider)
          .mutate(
            widget.organizationId,
            widget.recordId,
            widget.attachmentId,
            etag: etag,
            intent: _intent!,
            body: body,
          );
      if (!_live(generation)) return;
      setState(() {
        _snapshot = value;
        _intentKey = null;
        _intent = null;
        _error = null;
      });
    } catch (error) {
      if (!_live(generation)) return;
      setState(() {
        if (error is WorkspaceApiException && error.code == 412) {
          _conflict = true;
          _error = t.attachmentManager.governanceRefreshConflict;
        } else {
          if (_denied(error)) _forgetGovernance();
          _error = t.attachmentManager.loadFailed;
        }
      });
    } finally {
      if (_live(generation)) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _removeAuth();
    _contextSubscription?.close();
    _reason.dispose();
    _until.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.t.attachmentManager;
    final snapshot = _snapshot;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.regular),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr.governanceAction,
                  style: context.textStyle(FontSizeType.large),
                ),
                if (snapshot != null) ..._details(snapshot),
                if (_error != null)
                  Text(_error!, key: const ValueKey('governance-error')),
                if (_busy) const Center(child: CircularProgressIndicator()),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: Text(tr.retryAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _details(TalkAttachmentGovernanceSnapshot snapshot) {
    final tr = context.t.attachmentManager;
    return [
      AssetRetentionPanel(
        record: snapshot.retention,
        purgedLabel: tr.governancePurgeApproved,
        alreadyPurgedReasonLabel: tr.governancePurgeApproved,
      ),
      Text(tr.governancePhysicalPending),
      Text(
        talkRecordCleanupTitle(
          TalkRecordCleanupStatus.parse(snapshot.data['cleanup_status']),
        ),
      ),
      AppSpacing.verticalSmall,
      TextField(
        controller: _reason,
        enabled: !_busy,
        maxLength: 200,
        decoration: InputDecoration(labelText: tr.governanceHoldReason),
      ),
      TextField(
        controller: _until,
        enabled: !_busy,
        readOnly: true,
        onTap: _pickUntil,
        decoration: InputDecoration(
          labelText: tr.governanceExtendUntil,
          suffixIcon: const Icon(Icons.schedule),
        ),
      ),
      AppSpacing.verticalSmall,
      _operations(snapshot),
    ];
  }

  Widget _operations(TalkAttachmentGovernanceSnapshot snapshot) {
    final tr = context.t.attachmentManager;
    final record = snapshot.retention;
    return Wrap(
      spacing: AppSpacing.small,
      children: [
        _action('hold', tr.governanceHoldAction, !record.isPurged),
        _action(
          'release_hold',
          tr.governanceReleaseHoldAction,
          record.isHeld && !record.isPurged,
        ),
        _action(
          'extend_retention',
          tr.governanceExtendAction,
          !record.isPurged,
        ),
        _action(
          'purge',
          tr.governancePurgeAction,
          record.purgeBlockedReason == PurgeBlockedReason.none,
        ),
      ],
    );
  }

  Widget _action(String op, String label, bool eligible) => OutlinedButton(
    key: ValueKey('governance-$op'),
    onPressed: !_busy && !_conflict && eligible
        ? () => _submit(op, label)
        : null,
    child: Text(label),
  );
}
