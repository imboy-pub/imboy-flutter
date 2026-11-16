part of 'web_login_page.dart';

/// QR 码登录状态管理
@riverpod
class QRLogin extends _$QRLogin {
  Timer? _pollTimer;
  Timer? _expireTimer;
  int _requestGeneration = 0;
  ({AuthSessionScope auth, String environment, String endpoint})?
  _pendingProfile;

  bool get hasPendingProfile => _pendingProfile != null;

  bool get canRetryProfile {
    final pending = _pendingProfile;
    return pending != null &&
        _isCurrentRequest(_requestGeneration) &&
        authSessionReader.isCurrent(pending.auth) &&
        currentEnv == pending.environment &&
        Env().apiBaseUrl == pending.endpoint;
  }

  /// PR-4δ：SSE 会话（Web 平台主路径，失败 fallback 到 _startPolling）
  QrSseSession? _sseSession;

  /// 测试可注入 SSE 客户端；默认使用对应平台的实现。
  SseClientBuilder _sseClientBuilder = createSseClient;
  // ignore: avoid_setters_without_getters
  set sseClientBuilderForTesting(SseClientBuilder builder) =>
      _sseClientBuilder = builder;

  StreamSubscription<void>? _writerFailureSub;

  @override
  QRLoginState build() {
    ref.onDispose(dispose);
    if (kIsWeb && isWebWriterReady && _writerFailureSub == null) {
      _writerFailureSub = webWriterFailures.listen((_) {
        if (!ref.mounted) return;
        _requestGeneration++;
        _stopPolling();
        _stopSseSession();
      });
    }
    return const QRLoginState();
  }

  /// 生成新的 QR 码
  Future<void> generateQRCode() async {
    if (!isWebWriterReady) return;
    if (!ref.mounted || state.status == QRLoginStatus.confirming) return;
    final anonymousScope = authSessionReader.current;
    if (anonymousScope.uid.isNotEmpty || anonymousScope.transitioning) return;
    final generation = ++_requestGeneration;
    bool currentCreate() =>
        _isCurrentRequest(generation) &&
        authSessionReader.current == anonymousScope;
    _stopPolling();
    _stopSseSession();
    // 先使旧凭据失效，避免新二维码创建期间旧的在途轮询发布登录会话。
    state = const QRLoginState();
    try {
      if (deviceId.isEmpty) {
        throw StateError('Web device identity is not initialized');
      }

      // 调用后端 API 生成登录 QR 码
      final response = await HttpClient.client.post(
        '/api/v1/passport/qr_login/create',
        data: {
          'device_id': deviceId,
          'device_name': 'Web Browser',
          'platform': 'web',
          'purpose': 'human',
        },
      );

      if (!currentCreate()) return;

      // 按创建响应合同解析二维码、领取凭据和有效期。
      switch (parseQrCreateResponse(
        ok: response.ok,
        payload: response.payload,
      )) {
        case QrCreateSuccess(
          :final qrToken,
          :final sessionToken,
          :final expiresInSeconds,
        ):
          state = QRLoginState(
            status: QRLoginStatus.waiting,
            qrData: qrToken,
            sessionToken: sessionToken,
            remainingSeconds: expiresInSeconds,
          );
          // PR-4δ: Web 平台优先 SSE 推送（实时），失败由 watcher 自动 fallback
          // 到 _startPolling；非 Web 平台直接走轮询（无 EventSource 原生支持）。
          if (kIsWeb) {
            startSseSession(sessionToken);
          } else {
            _startPolling();
          }
          _startExpireTimer();
        case QrCreateFailure():
          // 优先透出服务端中文错误消息（如频率限制/设备数上限），
          // 仅在 msg 为空时回退到兜底文案，避免吞掉真实失败原因。
          state = QRLoginState(
            status: QRLoginStatus.failed,
            errorMessage: response.msg.isNotEmpty
                ? response.msg
                : t.common.webQRGenerateFailed,
          );
      }
    } catch (e) {
      if (!currentCreate()) return;
      state = QRLoginState(
        status: QRLoginStatus.failed,
        errorMessage: '网络错误: ${e.runtimeType}',
      );
    }
  }

  /// 开始轮询扫码状态
  void _startPolling() {
    if (!isWebWriterReady) return;
    final generation = _requestGeneration;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isCurrentRequest(generation)) {
        timer.cancel();
        return;
      }
      final sessionToken = state.sessionToken;
      if (sessionToken == null || !_awaitingConfirmation) {
        timer.cancel();
        return;
      }

      try {
        final response = await HttpClient.client.get(
          '/api/v1/passport/qr_login/status',
          queryParameters: {'session_token': sessionToken},
        );
        // 已领取、正在登记所有者或已换码时，丢弃尚在途的旧轮询结果。
        if (!_isCurrentRequest(generation) ||
            sessionToken != state.sessionToken ||
            !_awaitingConfirmation) {
          return;
        }

        // 轮询与 SSE 共用响应字段和状态转换规则。
        final event = parseQrStatusResponse(
          ok: response.ok,
          code: response.code,
          payload: response.payload,
        );
        switch (derivePollingDecision(
          sessionToken: state.sessionToken,
          event: event,
        )) {
          case StopSilently():
            timer.cancel();
            return;
          case KeepPolling():
            // 未知 status 时若需诊断可在此 debugPrint，但生产路径保持静默。
            return;
          case TransitionToScanned():
            state = state.copyWith(status: QRLoginStatus.scanned);
          case RequestCompleteLogin(:final token, :final uid):
            await _completeLogin(token, uid: uid);
          case TransitionToExpired():
            state = state.copyWith(status: QRLoginStatus.expired);
            timer.cancel();
          case TransitionToCancelledThenRefresh():
            state = state.copyWith(status: QRLoginStatus.waiting);
            await generateQRCode();
          case ProtocolViolation():
            // confirmed 但 token 为空（后端契约保证不会发生，但客户端防御）。
            state = state.copyWith(
              status: QRLoginStatus.failed,
              errorMessage: t.common.webQRTokenInvalid,
            );
            timer.cancel();
        }
      } catch (e) {
        debugPrint('[web_login_page] poll error: ${e.runtimeType}');
      }
    });
  }

  /// 开始过期倒计时
  void _startExpireTimer() {
    _expireTimer?.cancel();
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isWebWriterReady) {
        timer.cancel();
        return;
      }
      switch (deriveExpireTickDecision(
        remainingSeconds: state.remainingSeconds,
      )) {
        case MarkExpired():
          state = state.copyWith(status: QRLoginStatus.expired);
          timer.cancel();
        case DecrementRemaining(:final newRemainingSeconds):
          state = state.copyWith(remainingSeconds: newRemainingSeconds);
      }
    });
  }

  /// 完成登录
  Future<void> _completeLogin(String? token, {String? uid}) async {
    if (!isWebWriterReady) return;
    if (!_awaitingConfirmation) return;
    final generation = _requestGeneration;
    // 同步关门，避免重复 confirmed 或断线回退在所有者写入等待期间重入。
    state = state.copyWith(status: QRLoginStatus.confirming);
    _stopPolling();
    _stopSseSession();
    switch (deriveCompleteLoginDecision(token: token)) {
      case RejectInvalidToken():
        state = state.copyWith(
          status: QRLoginStatus.failed,
          errorMessage: t.common.webQRTokenInvalid,
        );
        return;
      case ProceedWithToken(:final token):
        // F6/AUT01：committed 需要跨 try/catch 可见（catch 里区分
        // 「提交成功后的失败」与「提交本身失败」）。
        var committed = false;
        try {
          final environment = currentEnv;
          final endpoint = Env().apiBaseUrl;
          final expectedAuthGeneration = UserRepoLocal.to.sessionGeneration + 1;
          committed = await UserRepoLocal.to.loginAfterQr(
            uid: uid,
            token: token,
          );
          // F6/AUT01（属主裁决 2026-11-16）：committed=true 即 token/uid/设备行
          // 已落库，登录已成事实——此后不得再因 UI 侧 cancelQRCode() 导致的
          // generation 失效而静默丢弃 success/hydration/导航链（提交窗口内的
          // auth notify 会让登录页走 transitioning/cancel 分支，4 轮 live 复现
          // 导航卡死，aut-residuals-20261116）。旧判顺序
          // `_isCurrentRequest → committed` 正是该死亡窗口；提交成功后只有
          // commit 本身失败才走 failed 态。
          if (!committed) {
            if (!_isCurrentRequest(generation)) return;
            throw StateError('QR session could not be saved');
          }
          final auth = authSessionReader.current;
          if (auth.uid != uid ||
              auth.generation != expectedAuthGeneration ||
              auth.transitioning ||
              currentEnv != environment ||
              Env().apiBaseUrl != endpoint)
            return;
          _pendingProfile = (
            auth: auth,
            environment: environment,
            endpoint: endpoint,
          );
          await _hydrateProfile(generation);
        } catch (e) {
          // F6/AUT01：committed 后的成功链异常（hydrate 等）不受 UI cancel
          // 影响；未提交场景仍尊重 generation 失效（用户已切走登录方式）。
          if (committed != true && !_isCurrentRequest(generation)) return;
          state = state.copyWith(
            status: QRLoginStatus.failed,
            errorMessage: '登录失败: ${e.runtimeType}',
          );
        }
    }
  }

  Future<void> _hydrateProfile(int generation) async {
    if (!canRetryProfile) return;
    final pending = _pendingProfile!;
    bool active() =>
        _isCurrentRequest(generation) &&
        canRetryProfile &&
        _pendingProfile == pending;
    state = state.copyWith(status: QRLoginStatus.confirming);
    try {
      final response = await HttpClient.client.get('/api/v1/user/me');
      if (!active()) return;
      if (!response.ok) {
        state = state.copyWith(
          status: QRLoginStatus.failed,
          errorMessage: response.msg.isNotEmpty
              ? response.msg
              : t.common.webQRLoginFailed,
        );
        return;
      }
      final payload = IMBoyHttpResponse.payloadAsMap(response.payload);
      if (payload['uid'] != pending.auth.uid) {
        throw StateError('Profile response owner mismatch');
      }
      final profile = <String, dynamic>{
        for (final key in [
          'uid',
          'account',
          'email',
          'nickname',
          'avatar',
          'gender',
          'region',
          'sign',
        ])
          if (payload.containsKey(key)) key: payload[key],
      };
      profile['setting'] = UserProfileService.parseWebSettings(
        payload['setting'],
      );
      final saved = await UserRepoLocal.to.changeInfo(
        profile,
        expectedUid: pending.auth.uid,
        expectedGeneration: pending.auth.generation,
        expectedEnvironment: pending.environment,
        expectedEndpoint: pending.endpoint,
      );
      if (!active()) return;
      if (!saved) throw StateError('Profile could not be saved');
      _pendingProfile = null;
      state = state.copyWith(status: QRLoginStatus.success);
    } catch (error) {
      if (!active()) return;
      state = state.copyWith(
        status: QRLoginStatus.failed,
        errorMessage: t.common.webQRLoginFailed,
      );
    }
  }

  bool get _awaitingConfirmation =>
      state.status == QRLoginStatus.waiting ||
      state.status == QRLoginStatus.scanned;

  bool _isCurrentRequest(int generation) =>
      isWebWriterReady && ref.mounted && generation == _requestGeneration;

  /// 切换到其他登录方式时，失效在途创建、轮询和 SSE。
  void cancelQRCode() {
    _pendingProfile = null;
    _requestGeneration++;
    _stopPolling();
    _stopSseSession();
    state = const QRLoginState();
  }

  void failAuthTransition() {
    cancelQRCode();
    state = QRLoginState(
      status: QRLoginStatus.failed,
      errorMessage: t.common.webQRGenerateFailed,
    );
  }

  /// 刷新 QR 码
  Future<void> refresh() async {
    if (canRetryProfile) {
      await _hydrateProfile(++_requestGeneration);
      return;
    }
    await generateQRCode();
  }

  /// 停止轮询
  void _stopPolling() {
    _pollTimer?.cancel();
    _expireTimer?.cancel();
  }

  /// Web 优先使用 SSE；断线后关闭旧订阅，再回退到轮询。
  /// 两种运输共用状态机。测试可直接验证订阅和会话发布顺序。
  @visibleForTesting
  void startSseSession(String sessionToken, {int gracePeriodSeconds = 3}) {
    if (!isWebWriterReady) return;
    final generation = _requestGeneration;
    final subscribeUri = Uri(
      path: '/api/v1/passport/qr_login/subscribe',
      queryParameters: {'session_token': sessionToken},
    );
    final url = kIsWeb
        ? webHumanRequestUri(
            'GET',
            subscribeUri,
            Uri.parse(Env().apiBaseUrl),
          ).toString()
        : subscribeUri.toString();
    _sseSession?.stop(); // 防重入：旧会话先清理
    final session = QrSseSession(
      client: _sseClientBuilder(),
      onEvent: (event) {
        if (!_isCurrentRequest(generation) ||
            sessionToken != state.sessionToken ||
            !_awaitingConfirmation) {
          return;
        }
        switch (derivePollingDecision(
          sessionToken: state.sessionToken,
          event: event,
        )) {
          case StopSilently():
          case KeepPolling():
            // SSE 路径下 StopSilently 表示协议异常，等 watcher 触发 fallback
            return;
          case TransitionToScanned():
            state = state.copyWith(status: QRLoginStatus.scanned);
          case RequestCompleteLogin(:final token, :final uid):
            unawaited(_completeLogin(token, uid: uid));
          case TransitionToExpired():
            state = state.copyWith(status: QRLoginStatus.expired);
            _stopSseSession();
          case TransitionToCancelledThenRefresh():
            state = state.copyWith(status: QRLoginStatus.waiting);
            _stopSseSession();
            generateQRCode();
          case ProtocolViolation():
            state = state.copyWith(
              status: QRLoginStatus.failed,
              errorMessage: t.common.webQRTokenInvalid,
            );
            _stopSseSession();
        }
      },
      onFallback: () {
        if (!_isCurrentRequest(generation) ||
            sessionToken != state.sessionToken ||
            !_awaitingConfirmation) {
          return;
        }
        // SSE 不可用 → 启动 2 秒轮询兜底（与现有 _startPolling 完全一致）
        _stopSseSession();
        _startPolling();
      },
    );
    _sseSession = session;
    unawaited(session.start(url, gracePeriodSeconds: gracePeriodSeconds));
  }

  void _stopSseSession() {
    final s = _sseSession;
    _sseSession = null;
    if (s != null) {
      unawaited(s.stop());
    }
  }

  /// 清理资源
  void dispose() {
    _pendingProfile = null;
    _writerFailureSub?.cancel();
    _writerFailureSub = null;
    _requestGeneration++;
    _pollTimer?.cancel();
    _expireTimer?.cancel();
    _stopSseSession();
  }
}
