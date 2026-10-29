import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/button.dart' show RoundedCupertinoButton;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_access_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/theme/default/app_spacing.dart';

final workspaceAccessNetworkProvider = StreamProvider.autoDispose<bool>((ref) {
  final connectivity = Connectivity();
  final output = StreamController<bool>();
  var changed = false;
  var disposed = false;
  bool online(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.contains(ConnectivityResult.none);
  final subscription = connectivity.onConnectivityChanged.listen(
    (results) {
      changed = true;
      if (!disposed) output.add(online(results));
    },
    onError: (Object error, StackTrace stack) {
      changed = true;
      if (!disposed) output.add(false);
    },
  );
  unawaited(
    connectivity.checkConnectivity().then(
      (results) {
        if (!disposed && !changed) output.add(online(results));
      },
      onError: (Object error, StackTrace stack) {
        if (!disposed && !changed) output.add(false);
      },
    ),
  );
  ref.onDispose(() {
    disposed = true;
    unawaited(subscription.cancel());
    unawaited(output.close());
  });
  return output.stream;
});

class WorkspaceAccessGuard extends ConsumerStatefulWidget {
  const WorkspaceAccessGuard({
    super.key,
    required this.target,
    required this.builder,
    this.active = true,
  });

  final WorkspaceAccessTarget target;
  final Widget Function(BuildContext, WorkspaceAccessState) builder;
  final bool active;

  @override
  ConsumerState<WorkspaceAccessGuard> createState() =>
      _WorkspaceAccessGuardState();
}

class _WorkspaceAccessGuardState extends ConsumerState<WorkspaceAccessGuard>
    with WidgetsBindingObserver {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _owner = Object();
  bool _foreground = true;
  bool _online = false;
  bool _connectionAvailable = true;
  bool _visible = false;
  bool _hasBuilt = false;
  WorkspaceAccessNotifier? _lastAccess;

  WorkspaceAccessNotifier get _access =>
      ref.read(workspaceAccessProvider(widget.target).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    ref.listenManual(workspaceAccessNetworkProvider, (previous, next) {
      final online =
          !next.hasError && !next.isLoading && next.asData?.value == true;
      final changed = online != _online || (online && !_connectionAvailable);
      _online = online;
      if (online) _connectionAvailable = true;
      if (!changed) return;
      if (_hasBuilt) {
        _syncVisibility();
      } else {
        Future.microtask(() {
          if (mounted) _syncVisibility();
        });
      }
    }, fireImmediately: true);
    _subscriptions.add(
      AppEventBus.on<WebSocketStatusChangedEvent>().listen((event) {
        if (event.status.toLowerCase() == 'connected') {
          _access.markEnvironmentSuspended();
          _syncVisibility();
        }
      }),
    );
    _subscriptions.add(AppEventBus.on<ChatExtendEvent>().listen(_onGroupEvent));
    _subscriptions.add(
      AppEventBus.on<NetworkConnectionEvent>().listen((event) {
        _connectionAvailable = event.isConnected;
        _syncVisibility();
      }),
    );
    _subscriptions.add(
      AppEventBus.on<ChannelStateChangedEvent>().listen((event) {
        if (widget.target.resource == 'channel:${event.channelId}' &&
            {
              'channel_deleted',
              'channel_unsubscribed',
            }.contains(event.action)) {
          _access.markRevoked();
        }
      }),
    );
  }

  void _onGroupEvent(ChatExtendEvent event) {
    if (event.type != 'leave_group' ||
        widget.target.resource != kWorkspaceAccessContentResource) {
      return;
    }
    final state = ref.read(workspaceAccessProvider(widget.target));
    final context = ref.read(workspaceAccessContextReaderProvider)();
    if ('${event.payload['userId']}' != context.uid) return;
    if (state.rows.any(
      (row) => row.group.groupId == '${event.payload['groupId']}',
    )) {
      _access.markRevoked();
    } else if (state.phase == WorkspaceAccessPhase.unknown &&
        state.rechecking) {
      _access.markContentUnavailable();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = ModalRoute.isCurrentOf(context) ?? true;
    Future.microtask(() {
      if (mounted) _syncVisibility();
    });
  }

  @override
  void didUpdateWidget(covariant WorkspaceAccessGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      ref
          .read(workspaceAccessProvider(oldWidget.target).notifier)
          .markEnvironmentSuspended(owner: _owner);
    }
    Future.microtask(() {
      if (mounted) _syncVisibility();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncVisibility();
  }

  void _syncVisibility() {
    if (!mounted) return;
    if (widget.active &&
        _visible &&
        _foreground &&
        _online &&
        _connectionAvailable) {
      _access.resume(owner: _owner);
    } else {
      _access.markEnvironmentSuspended(owner: _owner);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final access = _lastAccess;
    Future.microtask(() => access?.markEnvironmentSuspended(owner: _owner));
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(workspaceAccessProvider(widget.target));
    _lastAccess = _access;
    _hasBuilt = true;
    if (widget.active &&
        _visible &&
        _foreground &&
        _online &&
        _connectionAvailable &&
        access.canRenderProtectedContent &&
        _access.isCurrentContext) {
      return widget.builder(context, access);
    }
    final revoked = access.phase == WorkspaceAccessPhase.revoked;
    final shield = Center(
      child: Padding(
        padding: AppSpacing.allRegular,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              revoked
                  ? context.t.workspace.contentRevoked
                  : context.t.workspace.contentProtectedPending,
              key: const ValueKey('workspace-access-shield'),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalRegular,
            RoundedCupertinoButton(
              key: const ValueKey('workspace-access-retry'),
              text: context.t.workspace.contentProtectedRetry,
              highlighted: false,
              icon: CupertinoIcons.arrow_clockwise,
              onPressed:
                  access.rechecking ||
                      !_foreground ||
                      !_online ||
                      !_connectionAvailable ||
                      !widget.active ||
                      !_visible
                  ? null
                  : _access.resetForRetry,
            ),
          ],
        ),
      ),
    );
    return widget.target.resource.startsWith('channel:')
        ? Scaffold(
            appBar: AppBar(title: Text(context.t.workspace.channelDetailTitle)),
            body: shield,
          )
        : shield;
  }
}
