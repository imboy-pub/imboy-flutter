import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';
import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_cleanup_retry_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

abstract class TalkRecordCleanupRetryClient {
  Future<void> retry(
    String id,
    String etag,
    int generation,
    String key,
    void Function() requestGuard,
  );
}

class ApiTalkRecordCleanupRetryClient implements TalkRecordCleanupRetryClient {
  @override
  Future<void> retry(
    String id,
    String etag,
    int generation,
    String key,
    void Function() requestGuard,
  ) => TalkRecordApi().retryPhysicalCleanup(
    id,
    etag: etag,
    generation: generation,
    idempotencyKey: key,
    requestGuard: requestGuard,
  );
}

final talkRecordCleanupRetryClientProvider =
    Provider<TalkRecordCleanupRetryClient>(
      (ref) => ApiTalkRecordCleanupRetryClient(),
    );

/// Endpoint/account/session are captured before confirmation and final dispatch.
final talkRecordCleanupSessionProvider = Provider<Object? Function()>((ref) {
  return () {
    try {
      final user = UserRepoLocal.to;
      if (user.isAuthTransitioning || user.currentUid.isEmpty) return null;
      return (user.currentUid, user.sessionGeneration, Env().apiBaseUrl);
    } on Object {
      // Startup/shutdown can outlive local account storage. Never grant access.
      return null;
    }
  };
});

typedef _IntentBinding = (Object, String, String, int);

/// Keep unknown outcomes across a status refresh that temporarily removes the
/// widget. Intent identity never includes content and is cleared on auth change.
class TalkRecordCleanupRetryIntents {
  final _keys = <_IntentBinding, String>{};
  final _accepted = <_IntentBinding, int>{};
  int _readClock = 0;
  int beginRead() => ++_readClock;
  bool accepted(Object session, String id, String etag, int generation) =>
      _accepted.containsKey((session, id, etag, generation));
  void markAccepted(Object session, String id, String etag, int generation) =>
      _accepted[(session, id, etag, generation)] = ++_readClock;
  String? find(Object session, String id, String etag, int generation) =>
      _keys[(session, id, etag, generation)];
  String obtain(Object session, String id, String etag, int generation) {
    final binding = (session, id, etag, generation);
    return _keys.putIfAbsent(binding, TalkRecordIds.newUuidV4);
  }

  void clearIntent(Object session, String id, String etag, int generation) =>
      _clear((session, id, etag, generation));
  void _clear(_IntentBinding binding) {
    _keys.remove(binding);
    _accepted.remove(binding);
  }

  void reconcileRecord(Object session, String id, int readEpoch) {
    final confirmed = _accepted.entries
        .where(
          (entry) =>
              entry.key.$1 == session &&
              entry.key.$2 == id &&
              entry.value < readEpoch,
        )
        .map((entry) => entry.key)
        .toList();
    for (final binding in confirmed) {
      _clear(binding);
    }
  }

  void clear() {
    _keys.clear();
    _accepted.clear();
  }
}

final talkRecordCleanupRetryIntentsProvider = Provider((ref) {
  final intents = TalkRecordCleanupRetryIntents();
  final remove = ref.read(talkRecordAuthSubscribeProvider)(intents.clear);
  ref.onDispose(remove);
  return intents;
});

/// Compact shared action for owner cleanup and enterprise governance. Only the
/// server capability grants an action; a scope/role label never does.
class TalkRecordCleanupRetryControl extends ConsumerStatefulWidget {
  const TalkRecordCleanupRetryControl({
    super.key,
    required this.recordId,
    required this.etag,
    required this.capability,
    required this.onRefresh,
    this.enabled = true,
    this.requestGuard,
    this.onBusyChanged,
  });
  final String recordId;
  final String etag;
  final TalkRecordCleanupRetryCapability? capability;
  final Future<bool> Function() onRefresh;
  final bool enabled;
  final void Function()? requestGuard;
  final void Function(bool)? onBusyChanged;
  @override
  ConsumerState<TalkRecordCleanupRetryControl> createState() =>
      _RetryControlState();
}

class _RetryControlState extends ConsumerState<TalkRecordCleanupRetryControl> {
  late final void Function() _removeAuth;
  late final Object? Function() _readSession;
  Object? _session;
  int _epoch = 0;
  bool _busy = false;
  bool _invalid = false;
  bool _needsRefresh = false;
  String? _message;
  (String, String, int?) get _binding =>
      (widget.recordId, widget.etag, widget.capability?.generation);
  bool get _scopeLive =>
      mounted && !_invalid && _session != null && _readSession() == _session;
  bool get _allowed =>
      _scopeLive &&
      widget.enabled &&
      !_needsRefresh &&
      widget.capability?.canRetry == true &&
      !_intents.accepted(
        _session!,
        widget.recordId,
        widget.etag,
        widget.capability!.generation!,
      ) &&
      RegExp(r'^"[1-9][0-9]*"$').hasMatch(widget.etag);
  TalkRecordCleanupRetryIntents get _intents =>
      ref.read(talkRecordCleanupRetryIntentsProvider);

  @override
  void initState() {
    super.initState();
    _readSession = ref.read(talkRecordCleanupSessionProvider);
    _session = _readSession();
    _removeAuth = ref.read(talkRecordAuthSubscribeProvider)(() {
      _epoch++;
      if (mounted) {
        setState(() {
          _invalid = true;
          _busy = false;
          _message = null;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant TalkRecordCleanupRetryControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((
          oldWidget.recordId,
          oldWidget.etag,
          oldWidget.capability?.generation,
        ) !=
        _binding) {
      _epoch++;
      _busy = false;
      _message = null;
      _needsRefresh = false;
    }
  }

  @override
  void dispose() {
    _epoch++;
    _removeAuth();
    super.dispose();
  }

  bool _live(int epoch, (String, String, int?) binding) =>
      _scopeLive && epoch == _epoch && binding == _binding;
  void _guard(int epoch, (String, String, int?) binding) {
    if (!_live(epoch, binding) ||
        !widget.enabled ||
        widget.capability?.canRetry != true) {
      throw StateError('Cleanup request no longer belongs to this session');
    }
    widget.requestGuard?.call();
  }

  void _forgetIntent((String, String, int?) binding) =>
      _intents.clearIntent(_session!, binding.$1, binding.$2, binding.$3!);

  Future<void> _refresh(
    int epoch,
    (String, String, int?) binding, {
    bool allowRetryAfterRefresh = false,
  }) async {
    try {
      final refreshed = await widget.onRefresh();
      if (_live(epoch, binding)) {
        setState(() {
          if (!refreshed) _message = t.talkRecord.cleanupRetryRefreshFailed;
          if (refreshed && allowRetryAfterRefresh) _needsRefresh = false;
        });
      }
    } on Object {
      if (_live(epoch, binding)) {
        setState(() => _message = t.talkRecord.cleanupRetryRefreshFailed);
      }
    }
  }

  Future<void> _submit() async {
    if (!_allowed || _busy) return;
    final epoch = _epoch;
    final binding = _binding;
    final key = _intents.obtain(_session!, binding.$1, binding.$2, binding.$3!);
    widget.onBusyChanged?.call(true);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref
          .read(talkRecordCleanupRetryClientProvider)
          .retry(
            binding.$1,
            binding.$2,
            binding.$3!,
            key,
            () => _guard(epoch, binding),
          );
      if (!_live(epoch, binding)) return;
      _intents.markAccepted(_session!, binding.$1, binding.$2, binding.$3!);
      setState(() {
        _needsRefresh = true;
        _message = t.talkRecord.cleanupRetryAccepted;
      });
      await _refresh(epoch, binding);
    } on TalkRecordApiException catch (error) {
      if (!_live(epoch, binding)) return;
      await _handleFailure(error, epoch, binding);
    } on Object {
      if (_live(epoch, binding)) {
        setState(() => _message = t.talkRecord.cleanupRetryUnknown);
      }
    } finally {
      if (_live(epoch, binding)) {
        widget.onBusyChanged?.call(false);
        setState(() => _busy = false);
      } else if (mounted && epoch == _epoch) {
        // Rebuild to hide the expired scope without applying its response.
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleFailure(
    TalkRecordApiException error,
    int epoch,
    (String, String, int?) binding,
  ) async {
    if (const [401, 403, 404, 410].contains(error.code)) {
      _forgetIntent(binding);
      setState(() {
        _invalid = true;
        _message = null;
      });
      await _refresh(epoch, binding);
    } else if (error.isConflict || error.isRevisionStale) {
      _forgetIntent(binding);
      setState(() {
        _needsRefresh = true;
        _message = t.talkRecord.deleteConflictHint;
      });
      await _refresh(epoch, binding, allowRetryAfterRefresh: true);
    } else {
      // A timeout/5xx may follow a successful commit. Keep the exact request key.
      setState(() => _message = t.talkRecord.cleanupRetryUnknown);
    }
  }

  String? _permissionHint() => switch (widget.capability?.reason) {
    'partial_protection' => t.talkRecord.cleanupRetryPartial,
    'protected' => t.talkRecord.cleanupRetryProtected,
    'not_exhausted' => t.talkRecord.cleanupRetryWaiting,
    'not_deleted' || 'permission_denied' => null,
    'eligible' => null,
    _ => t.talkRecord.cleanupRetryUnavailable,
  };

  @override
  Widget build(BuildContext context) {
    if (!_scopeLive) return const SizedBox.shrink();
    final binding = _binding;
    final unknown =
        binding.$3 != null &&
        _intents.find(_session!, binding.$1, binding.$2, binding.$3!) != null;
    final accepted =
        binding.$3 != null &&
        _intents.accepted(_session!, binding.$1, binding.$2, binding.$3!);
    final hint =
        _message ??
        (accepted
            ? t.talkRecord.cleanupRetryAccepted
            : unknown
            ? t.talkRecord.cleanupRetryUnknown
            : _permissionHint());
    if (!_allowed && hint == null) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hint != null)
            Text(
              hint,
              key: const ValueKey('cleanup-retry-message'),
              style: context.textStyle(
                FontSizeType.footnote,
                color: brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          if (_allowed)
            CupertinoButton(
              key: const ValueKey('cleanup-retry-action'),
              minimumSize: const Size.fromHeight(AppSpacing.xxxLarge),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : Text(
                      unknown
                          ? t.talkRecord.cleanupRetryReconcile
                          : t.talkRecord.cleanupRetryAction,
                      style: context.textStyle(
                        FontSizeType.body,
                        color: AppColors.getIosBlue(brightness),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
