import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';

import 'web_shell_provider.dart';
import 'web_shell_route_params.dart';
import 'web_shell_state.dart';

/// Synchronizes the existing shell under its authenticated GoRouter route.
class WebShellRoute extends ConsumerStatefulWidget {
  const WebShellRoute({
    super.key,
    required this.uri,
    required this.child,
    this.sessionReader,
    this.chatFactory,
  });

  final Uri uri;
  final Widget child;
  final AuthSessionReader? sessionReader;
  final ChatNotifier Function()? chatFactory;

  @override
  ConsumerState<WebShellRoute> createState() => _WebShellRouteState();
}

class _WebShellRouteState extends ConsumerState<WebShellRoute> {
  late final _sessions = widget.sessionReader ?? authSessionReader;
  AuthSessionScope? _boundSession;
  bool _ready = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _boundSession = _sessions.current;
    _sessions.addListener(_onAuthChanged);
    ref.listenManual(webShellProvider, (_, next) {
      if (!_ready || _restoring || !mounted) return;
      final uri = widget.uri;
      if (uri.path != '/web_shell' ||
          GoRouter.of(context).routeInformationProvider.value.uri != uri ||
          parseShellRouteParams(uri.queryParameters) == next) {
        return;
      }
      context.go(
        uri.replace(queryParameters: shellStateToRouteParams(next)).toString(),
      );
    });
    _restoreAfterBuild();
  }

  @override
  void didUpdateWidget(covariant WebShellRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) _restoreAfterBuild();
  }

  void _onAuthChanged() {
    if (!mounted || _boundSession == _sessions.current) return;
    setState(() {
      _boundSession = _sessions.current;
      _ready = false;
    });
    _restoreAfterBuild(clearRoute: true);
  }

  @override
  void dispose() {
    _sessions.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _restoreAfterBuild({bool clearRoute = false}) {
    final uri = widget.uri;
    final session = _sessions.current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.uri != uri ||
          GoRouter.of(context).routeInformationProvider.value.uri != uri) {
        return;
      }
      final current = _sessions.current;
      final discard = clearRoute || session != current || current.transitioning;
      _restoring = true;
      try {
        final next = discard
            ? const WebShellState()
            : parseShellRouteParams(uri.queryParameters);
        if (ref.read(webShellProvider) != next) {
          ref.read(webShellProvider.notifier).replaceState(next);
        }
      } finally {
        _restoring = false;
      }
      if (discard && (uri.hasQuery || uri.hasFragment)) {
        context.go('/web_shell');
      }
      final ready = !current.transitioning;
      if (_ready != ready) setState(() => _ready = ready);
    });
  }

  @override
  Widget build(BuildContext context) => _ready
      ? ProviderScope(
          key: ValueKey(_boundSession),
          overrides: [
            chatProvider.overrideWith(widget.chatFactory ?? ChatNotifier.new),
          ],
          child: widget.child,
        )
      : const SizedBox.shrink();
}
