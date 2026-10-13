import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_actions.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class CsActionRisks {
  final bool draft, sending, uploading, unconfirmed;
  const CsActionRisks({
    this.draft = false,
    this.sending = false,
    this.uploading = false,
    this.unconfirmed = false,
  });
  bool get blocksWrite => sending || uploading || unconfirmed;
}

typedef CsActionResult = ({CsSeatFailureKind? failure});

/// One action intent, including target discovery and every owned confirmation route.
class CsSessionActionConfirmation extends ChangeNotifier {
  CsSessionActionConfirmation({CsApi? api}) : _api = api ?? CsApi();
  final CsApi _api;
  final Set<DialogRoute<dynamic>> _routes = {};
  bool _busy = false, _disposed = false;
  int _generation = 0;
  bool Function()? _current;
  CsSessionFlow? _flow;
  CsSessionActionSnapshot? _intent;
  bool get busy => _busy;
  bool get _valid =>
      !_disposed &&
      _busy &&
      (_current?.call() ?? false) &&
      _flow != null &&
      !_flow!.readRevoked &&
      _flow!.machine.canSend &&
      (_intent?.matches(_flow!.detail) ?? false);

  int? _begin(CsSessionFlow flow, bool Function() current, bool transfer) {
    if (_busy || _disposed || !current() || flow.detail == null) return null;
    final intent = CsSessionActionSnapshot(flow.detail!);
    if (!intent.matches(flow.detail) ||
        flow.readRevoked ||
        !flow.machine.canSend ||
        (transfer
            ? intent.status != 'active'
            : !['queued', 'active'].contains(intent.status))) {
      return null;
    }
    _flow = flow;
    _current = current;
    _intent = intent;
    _busy = true;
    notifyListeners();
    return ++_generation;
  }

  void _finish(int generation) {
    if (_disposed || generation != _generation) return;
    _busy = false;
    _intent = null;
    _flow = null;
    _current = null;
    notifyListeners();
  }

  void refresh() {
    if (_disposed) return;
    if (_busy && !_valid) {
      invalidate();
      return;
    }
    notifyListeners();
  }

  void invalidate() {
    _generation++;
    _busy = false;
    _intent = null;
    _flow = null;
    _current = null;
    _remove(_routes.toList());
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    invalidate();
    super.dispose();
  }

  void _remove(List<DialogRoute<dynamic>> routes) {
    if (routes.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        final nav = route.navigator;
        if (route.isActive && nav != null && nav.mounted) {
          nav.removeRoute(route);
        }
        _routes.remove(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _currentDialog(BuildContext context) =>
      context.mounted && ModalRoute.of(context)?.isCurrent == true;

  Future<T?> _open<T>(BuildContext context, WidgetBuilder builder) async {
    if (!_valid || !context.mounted) return null;
    final route = DialogRoute<T>(context: context, builder: builder);
    _routes.add(route);
    try {
      final result = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      await route.completed;
      return result;
    } finally {
      _routes.remove(route);
    }
  }

  Future<CsActionResult?> transfer({
    required BuildContext context,
    required CsSessionFlow flow,
    required bool Function() isCurrent,
    required CsActionRisks Function() risks,
  }) async {
    final generation = _begin(flow, isCurrent, true);
    if (generation == null) return null;
    try {
      final page = await _api.transferTargets(flow.orgId, limit: 50);
      if (!_valid || generation != _generation || !context.mounted) return null;
      final target = await _pick(
        context,
        csTransferTargetOptions(page.items, excludeIdentityId: flow.identityId),
      );
      if (target == null ||
          !_valid ||
          generation != _generation ||
          !context.mounted) {
        return null;
      }
      final yes = await _confirm(context, risks, transfer: target);
      if (yes != true || generation != _generation) return null;
      if (!_valid || risks().blocksWrite) {
        return (failure: CsSeatFailureKind.conflict);
      }
      return (
        failure: await flow.transferTo(target.identityId, snapshot: _intent),
      );
    } on CsApiException catch (e) {
      if (generation != _generation || !isCurrent()) return null;
      return (failure: flow.applyActionFailure(e));
    } finally {
      _finish(generation);
    }
  }

  Future<CsActionResult?> close({
    required BuildContext context,
    required CsSessionFlow flow,
    required bool Function() isCurrent,
    required CsActionRisks Function() risks,
  }) async {
    final generation = _begin(flow, isCurrent, false);
    if (generation == null) return null;
    final reason = TextEditingController();
    try {
      final yes = await _confirm(context, risks, reason: reason);
      if (yes != true || generation != _generation) return null;
      if (!_valid || risks().blocksWrite) {
        return (failure: CsSeatFailureKind.conflict);
      }
      return (
        failure: await flow.closeSession(
          reason: csSanitizeCloseReason(reason.text),
          snapshot: _intent,
        ),
      );
    } finally {
      reason.dispose();
      _finish(generation);
    }
  }

  Future<CsTransferTarget?> _pick(
    BuildContext context,
    List<CsTransferTarget> targets,
  ) {
    final t = context.t.customerService;
    return _open(
      context,
      (dialogContext) => SimpleDialog(
        title: Text(targets.isEmpty ? t.transferEmpty : t.transferTitle),
        children: [
          for (final target in targets)
            SimpleDialogOption(
              onPressed: () {
                if (!_currentDialog(dialogContext)) return;
                if (!_valid) {
                  invalidate();
                  return;
                }
                Navigator.of(dialogContext).pop(target);
              },
              child: ListTile(
                title: Text(
                  target.displayName.isEmpty
                      ? target.identityId
                      : target.displayName,
                ),
                subtitle: Text(
                  target.available ? t.targetAvailable : t.targetBusy,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(
    BuildContext context,
    CsActionRisks Function() risks, {
    CsTransferTarget? transfer,
    TextEditingController? reason,
  }) {
    final labels = _ConfirmationLabels(context, transfer);
    var submitted = false;
    void submit(BuildContext dialogContext) {
      if (!_currentDialog(dialogContext) || submitted || risks().blocksWrite) {
        return;
      }
      if (!_valid) {
        invalidate();
        return;
      }
      submitted = true;
      Navigator.of(dialogContext).pop(true);
    }

    return _open(
      context,
      (dialogContext) => AnimatedBuilder(
        animation: this,
        builder: (_, _) => AlertDialog(
          title: Text(labels.title),
          content: _confirmationContent(labels, risks(), reason),
          actions: [
            TextButton(
              onPressed: () {
                if (_currentDialog(dialogContext)) {
                  Navigator.of(dialogContext).pop(false);
                }
              },
              child: Text(labels.cancel),
            ),
            FilledButton(
              onPressed: risks().blocksWrite || !_valid
                  ? null
                  : () => submit(dialogContext),
              child: Text(labels.submit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmationContent(
    _ConfirmationLabels labels,
    CsActionRisks risks,
    TextEditingController? reason,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(labels.body),
      ..._warnings(risks, labels.warnings),
      if (reason != null)
        TextField(
          controller: reason,
          maxLength: 200,
          decoration: InputDecoration(hintText: labels.hint, counterText: ''),
        ),
    ],
  );

  List<Widget> _warnings(CsActionRisks risks, List<String> messages) => [
    for (final index in [
      if (risks.draft) 0,
      if (risks.sending) 1,
      if (risks.uploading) 2,
      if (risks.unconfirmed) 3,
    ])
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.small),
        child: Text(messages[index]),
      ),
  ];
}

class _ConfirmationLabels {
  late final String title, body, submit, cancel, hint;
  late final List<String> warnings;
  _ConfirmationLabels(BuildContext context, CsTransferTarget? target) {
    final t = context.t.customerService;
    title = target == null ? t.closeTitle : t.transferConfirmTitle;
    body = target == null
        ? t.closeBody
        : t.transferConfirmBody(
            name: target.displayName.isEmpty
                ? target.identityId
                : target.displayName,
          );
    submit = target == null ? t.closeAction : t.transferAction;
    cancel = context.t.common.buttonCancel;
    hint = t.closeReasonLabel;
    warnings = [
      t.actionDraftWarning,
      t.actionSendingWarning,
      t.actionUploadingWarning,
      t.actionUnconfirmedWarning,
    ];
  }
}
