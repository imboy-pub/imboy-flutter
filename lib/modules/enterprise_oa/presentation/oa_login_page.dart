import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import '../data/oa_login_api.dart';
import '../domain/oa_login_attempt.dart';
import '../enterprise_oa_runtime_config.dart';

class OaLoginPage extends StatefulWidget {
  const OaLoginPage({
    super.key,
    required this.callback,
    this.config,
    this.deviceInfo,
    this.launch,
  });
  final Uri callback;
  final EnterpriseOaRuntimeConfig? config;
  final Future<Map<String, dynamic>?> Function()? deviceInfo;
  final Future<bool> Function(Uri)? launch;
  @override
  State<OaLoginPage> createState() => _OaLoginPageState();
}

class _OaLoginPageState extends State<OaLoginPage> {
  OaLoginAttempt? _attempt;
  String _boundUid = '';
  bool _busy = true;
  bool _failed = false;
  bool _restoring = false;
  OaLoginApi get _api => OaLoginApi(backend: _attempt!.backend);
  Future<Map<String, dynamic>?> _deviceInfo() =>
      widget.deviceInfo?.call() ?? DeviceExt.to.detail;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didUpdateWidget(OaLoginPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.callback != oldWidget.callback) _restore();
  }

  Future<void> _persist(int generation, String expectedUid) async {
    _requireSession(generation, expectedUid);
    await UserRepoLocal.to.writeOaLoginAttemptForSession(
      generation,
      expectedUid,
      jsonEncode({
        'backend': _attempt!.backend,
        'bound_uid': _boundUid,
        'attempt': _attempt!.toJson(),
      }),
    );
    _requireSession(generation, expectedUid);
  }

  void _requireSession(int generation, String expectedUid) {
    final repo = UserRepoLocal.to;
    if (!mounted ||
        !repo.isCurrentSession(generation) ||
        repo.isAuthTransitioning ||
        repo.currentUid != expectedUid ||
        (_boundUid.isNotEmpty && _boundUid != expectedUid)) {
      throw const FormatException('session changed');
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    _restoring = true;
    _busy = true;
    final repo = UserRepoLocal.to;
    final generation = repo.sessionGeneration;
    final expectedUid = repo.currentUid;
    try {
      _requireSession(generation, expectedUid);
      final raw = await repo.readOaLoginAttempt();
      _requireSession(generation, expectedUid);
      _attempt = null;
      _boundUid = '';
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['backend'] != Env().apiBaseUrl) {
          throw const FormatException('backend changed');
        }
        final attempt = OaLoginAttempt.fromJson(
          data['attempt'] as Map<String, dynamic>,
        );
        if (!attempt.validAt(DateTime.now())) {
          await _clearAttempt();
          return;
        }
        _attempt = attempt;
        _boundUid = data['bound_uid'] as String;
        if (!EnterpriseOaRuntimeConfig.isValidApplicationKey(
          attempt.applicationKey,
        )) {
          throw const FormatException('invalid source');
        }
      }
      if (widget.callback.queryParameters.containsKey('ticket')) {
        if (_attempt == null || _attempt!.pendingToken != null) {
          throw const FormatException('unsolicited callback');
        }
        final ticket = _attempt!.callbackTicket(
          widget.callback,
          DateTime.now(),
        );
        _requireSession(generation, expectedUid);
        final proof = await _proof(generation, expectedUid);
        _requireSession(generation, expectedUid);
        final payload = await _api.exchange(ticket, proof);
        _requireSession(generation, expectedUid);
        await _apply(payload, generation, expectedUid);
      }
    } on Object {
      _failed = true;
    } finally {
      _restoring = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _proof(
    int generation,
    String expectedUid,
  ) async {
    _requireSession(generation, expectedUid);
    final info = await _deviceInfo();
    _requireSession(generation, expectedUid);
    if (info == null || info['did'] is! String) {
      throw const FormatException('device unavailable');
    }
    _attempt!.requireContext(Env().apiBaseUrl, info['did'] as String);
    final raw = await UserRepoLocal.to.readOaLoginAttempt();
    _requireSession(generation, expectedUid);
    if (raw == null ||
        (jsonDecode(raw) as Map<String, dynamic>)['attempt']['state'] !=
            _attempt!.state) {
      throw const FormatException('OA proof revoked');
    }
    return {
      'application_key': _attempt!.applicationKey,
      'code_verifier': _attempt!.verifier,
      'did': info['did'],
      'cos': info['cos'],
      'dname': info['deviceName'],
      'dvsn': info['deviceVersion'],
    };
  }

  Future<void> _start() => _run(() async {
    final config = widget.config ?? resolveEnterpriseOaRuntimeConfig();
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !config.inboundLoginEnabled) {
      throw const FormatException('unconfigured');
    }
    final repo = UserRepoLocal.to;
    final generation = repo.sessionGeneration;
    _boundUid = repo.currentUid;
    final expectedUid = repo.currentUid;
    _requireSession(generation, expectedUid);
    final backend = Env().apiBaseUrl;
    final info = await _deviceInfo();
    _requireSession(generation, expectedUid);
    if (info == null || info['did'] is! String || backend != Env().apiBaseUrl) {
      throw const FormatException('device unavailable');
    }
    _attempt = OaLoginAttempt.create(
      _boundUid.isEmpty ? 'login' : 'link',
      backend: backend,
      deviceId: info['did'] as String,
      applicationKey: config.applicationKey,
    );
    await _persist(generation, expectedUid);
    await _proof(generation, expectedUid);
    _requireSession(generation, expectedUid);
    final launchUri = _attempt!.launchUri(Uri.parse(config.loginStartUri));
    final launched = widget.launch == null
        ? await launchUrl(launchUri, mode: LaunchMode.externalApplication)
        : await widget.launch!(launchUri);
    if (!launched) {
      throw const FormatException('launch failed');
    }
  });
  Future<void> _apply(
    Map<String, dynamic> payload,
    int generation,
    String expectedUid,
  ) async {
    await _proof(generation, expectedUid);
    _requireSession(generation, expectedUid);
    if (payload['requires_account_choice'] == true &&
        payload['pending_token'] is String) {
      final ttl = payload['expires_in'];
      if (ttl is! int ||
          ttl <= 0 ||
          ttl > 300 ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$')
              .hasMatch(payload['pending_token'] as String)) {
        throw const FormatException('invalid pending proof');
      }
      _attempt!.pendingToken = payload['pending_token'] as String;
      _attempt!.expiresAt = DateTime.now().add(Duration(seconds: ttl));
      await _persist(generation, expectedUid);
      return;
    }
    final repo = UserRepoLocal.to;
    final uid = (payload['user_id'] ?? payload['uid']).toString();
    if (repo.isLoggedIn && repo.currentUid != uid) {
      throw const FormatException('account changed');
    }
    _requireSession(generation, expectedUid);
    await repo.loginAfter((payload['account'] ?? uid).toString(), payload);
    _requireSession(generation + 1, uid);
    await repo.writeOaLoginAttemptForSession(generation + 1, uid, null);
    _attempt = null;
    if (mounted) context.go('/bottom_navigation');
  }

  Future<void> _finish(bool create) => _run(() async {
    final attempt = _attempt!;
    if (!attempt.validAt(DateTime.now()) || attempt.pendingToken == null) {
      await _clearAttempt();
      return;
    }
    final repo = UserRepoLocal.to;
    if (_boundUid.isNotEmpty && repo.currentUid != _boundUid) {
      throw const FormatException('account changed');
    }
    final generation = repo.sessionGeneration;
    final expectedUid = repo.currentUid;
    final proof = await _proof(generation, expectedUid);
    _requireSession(generation, expectedUid);
    final payload = create
        ? await _api.register(attempt.pendingToken!, proof)
        : await _api.link(attempt.pendingToken!, proof);
    _requireSession(generation, expectedUid);
    await _apply(payload, generation, expectedUid);
  });
  Future<void> _clearAttempt() async {
    final repo = UserRepoLocal.to;
    await repo.writeOaLoginAttemptForSession(
      repo.sessionGeneration,
      repo.currentUid,
      null,
    );
    _attempt = null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action();
    } on Object {
      _failed = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final pending = _attempt?.pendingToken != null;
    final loggedIn = UserRepoLocal.to.isLoggedIn;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(t.enterpriseOa.inboundTitle),
      ),
      child: SafeArea(
        child: Padding(
          padding: AppSpacing.allRegular,
          child: Column(
            children: [
              if (_busy) const CupertinoActivityIndicator(),
              if (_failed) Text(t.enterpriseOa.statusErrorHint),
              if (!_busy && pending) ...[
                Text(t.enterpriseOa.accountChoice),
                if (loggedIn)
                  CupertinoButton(
                    onPressed: () => _finish(false),
                    child: Text(t.enterpriseOa.confirmLink),
                  ),
                if (!loggedIn)
                  CupertinoButton(
                    onPressed: () => context.go('/oa/link'),
                    child: Text(t.enterpriseOa.useExistingAccount),
                  ),
                if (!loggedIn && _attempt!.intent == 'login')
                  CupertinoButton(
                    onPressed: () => _finish(true),
                    child: Text(t.enterpriseOa.confirmCreate),
                  ),
              ],
              if (!_busy && !pending)
                CupertinoButton(
                  onPressed: _start,
                  child: Text(t.enterpriseOa.startInbound),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
