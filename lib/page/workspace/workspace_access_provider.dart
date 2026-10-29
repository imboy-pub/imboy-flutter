import 'dart:async';

import 'package:dio/dio.dart' show Options;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/feature_revision_provider.dart';
import 'package:imboy/app_core/feature_flags/feature_scope.dart';
import 'package:imboy/component/http/http_exceptions.dart' as http;
import 'package:imboy/config/env.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

const kWorkspaceAccessRecheckInterval = Duration(seconds: 20);
const kWorkspaceAccessDisplayBudget = Duration(seconds: 30);
const kWorkspaceAccessContentResource = 'conversations';

typedef WorkspaceAccessTarget = ({String workspaceId, String resource});
typedef WorkspaceAccessContext = ({
  String origin,
  String uid,
  int session,
  String? featureScope,
  int featureEpoch,
  int featureRevision,
  bool channelEnabled,
});

final workspaceAccessClockProvider = Provider<Duration Function()>((ref) {
  final clock = Stopwatch()..start();
  ref.onDispose(clock.stop);
  return () => clock.elapsed;
});

final workspaceAccessContextReaderProvider =
    Provider<WorkspaceAccessContext Function()>((ref) {
      final uid = ref.watch(
        currentUserProvider.select((user) => user?.uid ?? ''),
      );
      final revision = ref.watch(featureRevisionProvider);
      final repo = ref.watch(userRepoProvider);
      void changed() => ref.invalidateSelf();
      repo.addAuthListener(changed);
      ref.onDispose(() => repo.removeAuthListener(changed));
      return () => (
        origin: Env().apiBaseUrl,
        uid: repo.isAuthTransitioning ? '' : uid,
        session: repo.sessionGeneration,
        featureScope: FeatureScope.key,
        featureEpoch: FeatureScope.epoch,
        featureRevision: revision,
        channelEnabled: AppFeatureRegistry.isEnabled(FeatureKeys.channel),
      );
    });

final workspaceAccessProvider = NotifierProvider.autoDispose
    .family<
      WorkspaceAccessNotifier,
      WorkspaceAccessState,
      WorkspaceAccessTarget
    >(WorkspaceAccessNotifier.new);

enum WorkspaceAccessPhase { unknown, authorized, revoked }

class WorkspaceAccessState {
  const WorkspaceAccessState({
    this.phase = WorkspaceAccessPhase.unknown,
    this.rechecking = false,
    this.deadline,
    this.rows = const [],
    this.channel,
    this.error,
  });

  final WorkspaceAccessPhase phase;
  final bool rechecking;
  final Duration? deadline;
  final List<WorkspaceConversationModel> rows;
  final ChannelModel? channel;
  final Object? error;

  bool get canRenderProtectedContent =>
      phase == WorkspaceAccessPhase.authorized;
}

class WorkspaceAccessNotifier extends Notifier<WorkspaceAccessState> {
  WorkspaceAccessNotifier(this.target);

  final WorkspaceAccessTarget target;
  Timer? _recheckTimer;
  Timer? _deadlineTimer;
  Timer? _requestTimer;
  late WorkspaceAccessContext _context;
  int _generation = 0;
  int? _inFlight;
  bool _active = false;
  Object? _visibleOwner;

  @override
  WorkspaceAccessState build() {
    _context = ref.watch(workspaceAccessContextReaderProvider)();
    _cancelTimers();
    _generation++;
    _inFlight = null;
    ref.onDispose(() {
      _generation++;
      _cancelTimers();
    });
    if (_active) Future.microtask(refresh);
    return const WorkspaceAccessState();
  }

  bool get isCurrentContext =>
      ref.mounted &&
      ref.read(workspaceAccessContextReaderProvider)() == _context;

  void resume({Object? owner}) {
    if (!ref.mounted) return;
    if (owner != null && _visibleOwner != owner) {
      _visibleOwner = owner;
      _active = false;
      _invalidate();
    }
    if (_active) return;
    _active = true;
    unawaited(refresh());
  }

  void markEnvironmentSuspended({Object? owner}) {
    if (!ref.mounted ||
        (owner != null && _visibleOwner != null && _visibleOwner != owner)) {
      return;
    }
    _active = false;
    _invalidate();
  }

  void markRevoked() {
    if (ref.mounted) _invalidate(revoked: true);
  }

  void markContentUnavailable() {
    if (ref.mounted) _invalidate();
  }

  void _invalidate({bool revoked = false}) {
    if (!ref.mounted) return;
    _generation++;
    _inFlight = null;
    _cancelTimers();
    state = WorkspaceAccessState(
      phase: revoked
          ? WorkspaceAccessPhase.revoked
          : WorkspaceAccessPhase.unknown,
    );
  }

  bool _matches(int generation, WorkspaceAccessContext context) =>
      ref.mounted &&
      _active &&
      _generation == generation &&
      _context == context &&
      isCurrentContext;

  Future<void> resetForRetry() => refresh();

  Future<void> refresh() async {
    if (!_active || !ref.mounted) return;
    if (!isCurrentContext) {
      _context = ref.read(workspaceAccessContextReaderProvider)();
      _invalidate();
    }
    if (_inFlight != null) return;
    if (_context.uid.isEmpty ||
        target.workspaceId.isEmpty ||
        (target.resource.startsWith('channel:') && !_context.channelEnabled)) {
      _invalidate();
      return;
    }
    final generation = ++_generation;
    final context = _context;
    _inFlight = generation;
    _requestTimer = Timer(kWorkspaceAccessDisplayBudget, () {
      if (_matches(generation, context)) _invalidate();
    });
    state = WorkspaceAccessState(
      phase: state.phase,
      deadline: state.deadline,
      rows: state.rows,
      channel: state.channel,
      rechecking: true,
    );
    try {
      final result = await _loadContent(generation, context);
      if (!_matches(generation, context)) return;
      if (_deadlineReached) {
        _invalidate();
        return;
      }
      _inFlight = null;
      _requestTimer?.cancel();
      _accept(result.rows, result.channel);
    } catch (error) {
      _handleFailure(generation, context, error);
    }
  }

  bool get _deadlineReached =>
      state.deadline != null &&
      ref.read(workspaceAccessClockProvider)() >= state.deadline!;

  void _handleFailure(
    int generation,
    WorkspaceAccessContext context,
    Object error,
  ) {
    if (!_matches(generation, context)) return;
    _inFlight = null;
    _requestTimer?.cancel();
    final code = error is WorkspaceApiException
        ? error.code
        : error is http.HttpException
        ? error.code
        : null;
    if (code == 401 ||
        code == 403 ||
        code == 404 ||
        code == 410 ||
        code == 980) {
      markRevoked();
    } else if (_deadlineReached) {
      _invalidate();
    } else {
      state = WorkspaceAccessState(
        phase: state.phase,
        deadline: state.deadline,
        rows: state.rows,
        channel: state.channel,
        error: WorkspaceApiException(
          code ?? -1,
          'Workspace content unavailable',
        ),
      );
    }
  }

  Future<({List<WorkspaceConversationModel> rows, ChannelModel? channel})>
  _loadContent(int generation, WorkspaceAccessContext context) async {
    if (target.resource == kWorkspaceAccessContentResource) {
      final rows = await ref
          .read(workspaceApiProvider)
          .conversations(target.workspaceId);
      return (rows: rows, channel: null);
    }
    if (!target.resource.startsWith('channel:')) {
      throw const FormatException('Not a workspace content resource');
    }
    final id = target.resource.substring('channel:'.length);
    final api = ref.read(channelApiProvider);
    final channel = await api.getChannelChecked(id);
    if (!_matches(generation, context)) {
      throw StateError('Stale workspace channel request');
    }
    if (channel.id.toString() != id ||
        channel.scope != 'workspace' ||
        channel.workspaceId != target.workspaceId) {
      throw WorkspaceApiException(403, 'Workspace channel mismatch');
    }
    final response = await api.get(
      '/api/v1/channel/$id/messages',
      options: Options(
        responseDecoder: channelIdResponseDecoder(
          ChannelResponseShape.subscribed,
        ),
      ),
      queryParameters: {'limit': 1},
    );
    if (!response.ok) {
      throw WorkspaceApiException(response.code, response.msg);
    }
    final payload = response.payload;
    if (payload is! Map || payload['list'] is! List) {
      throw const FormatException('Invalid workspace channel content');
    }
    for (final row in payload['list'] as List) {
      if (row is! Map<String, dynamic> ||
          ChannelMessageModel.fromJson(row).channelId.toString() != id) {
        throw const FormatException('Workspace channel message mismatch');
      }
    }
    return (rows: const <WorkspaceConversationModel>[], channel: channel);
  }

  void _accept(List<WorkspaceConversationModel> rows, ChannelModel? channel) {
    final deadline =
        ref.read(workspaceAccessClockProvider)() +
        kWorkspaceAccessDisplayBudget;
    state = WorkspaceAccessState(
      phase: WorkspaceAccessPhase.authorized,
      deadline: deadline,
      rows: List.unmodifiable(rows),
      channel: channel,
    );
    _cancelTimers();
    _recheckTimer = Timer(kWorkspaceAccessRecheckInterval, () {
      if (!ref.mounted) return;
      if (!isCurrentContext) {
        _invalidate();
      } else {
        unawaited(refresh());
      }
    });
    _deadlineTimer = Timer(kWorkspaceAccessDisplayBudget, () {
      if (ref.mounted &&
          state.deadline == deadline &&
          ref.read(workspaceAccessClockProvider)() >= deadline) {
        _invalidate();
      }
    });
  }

  void _cancelTimers() {
    _recheckTimer?.cancel();
    _deadlineTimer?.cancel();
    _requestTimer?.cancel();
  }
}
