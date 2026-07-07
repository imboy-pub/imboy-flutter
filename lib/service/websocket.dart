import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, visibleForTesting;
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/event_subscription_manager.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/protocol/imboy_pb_codec.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart' show defaultHeaders;
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/component/helper/datetime.dart' show DateTimeHelper;
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/service/exponential_backoff.dart';
import 'package:imboy/config/init.dart' show navigateToSignIn;

enum SocketStatus { connecting, connected, disconnected }

/// WebSocket framing 模式
/// - none: v1 路径（JSON 文本 / 原始二进制）
/// - v2: IMBoy 分层二进制协议 v2（通过 imboy.v2 子协议协商）
enum FramingMode { none, v2 }

/// v2 子协议名称（最高优先级）
const String kSubProtocolV2 = 'imboy.v2';

class WebSocketService with WidgetsBindingObserver, EventSubscriptionManager {
  // 单例模式
  static WebSocketService? _instance;
  static WebSocketService get to => _instance ??= WebSocketService._internal();
  WebSocketService._internal();

  // 状态管理
  SocketStatus _status = SocketStatus.disconnected;
  SocketStatus get status => _status;

  // 状态变化回调
  final List<void Function(SocketStatus)> _statusCallbacks = [];

  final PersistentMessageQueue _messageQueue = PersistentMessageQueue.to;

  // 网络与连接
  // 【修复 M2】maxRetries=999999 表示无限重试（与注释一致）
  final ExponentialBackoff _backoff = ExponentialBackoff(maxRetries: 999999);
  // App 是否处于后台：后台期间暂停重连定时器，避免长期离线时按最大退避
  // 间隔（最长2分钟）持续唤醒耗电；回到前台由 _onAppResumed 立即重试。
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  WebSocketChannel? _channel;
  bool _isFlushing = false;

  // 订阅管理
  // 不走 EventSubscriptionManager —— 需在 _cancelStream() 中与 _channel.sink.close() 同步执行
  StreamSubscription<dynamic>? _wsSub;
  Timer? _reconnectTimer;
  Timer? _v2HeartbeatTimer;
  Timer? _v1HeartbeatTimer;
  Timer? _v1PongTimer;
  bool _initialized = false;

  // 配置参数
  static const _pingInterval = Duration(seconds: 60);
  // v1 模式应用层心跳的 pong 超时：必须小于 _pingInterval，确保上一轮
  // 心跳判活完成（收到 pong 或判定超时）后下一轮心跳才开始。
  static const _v1PongTimeout = Duration(seconds: 20);
  bool _connecting = false;

  /// 当前 WebSocket framing 模式（由子协议协商决定）
  FramingMode _framing = FramingMode.none;
  FramingMode get framing => _framing;

  /// v2 心跳序列号（uint16 回绕）
  int _v2PingSeq = 0;

  /// 【测试】注入可预测的 framing 状态（仅测试使用）
  @visibleForTesting
  set framingForTest(FramingMode mode) => _framing = mode;

  /// 【测试】注入 channel（仅测试使用）
  @visibleForTesting
  set channelForTest(WebSocketChannel? channel) => _channel = channel;

  /// 【测试】暴露 v2 业务帧编码
  @visibleForTesting
  Uint8List encodeV2BusinessFrameForTest(String message) =>
      _encodeV2BusinessFrame(message);

  /// 【测试】暴露 v2 二进制帧处理
  @visibleForTesting
  void handleV2BinaryForTest(Uint8List bytes) => _handleV2Binary(bytes);

  /// 【测试】重置单例（仅测试使用）
  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }

  /// 用于防止快速重连竞态：同一时刻只有一个连接请求在进行
  /// 后续的连接请求会等待当前连接完成，而不是创建重复连接
  Completer<void>? _connectCompleter;

  /// 初始化服务
  void init() {
    // 防止重复初始化导致多次订阅
    if (_initialized) return;
    _initialized = true;

    // 注册 App 生命周期观察者（检测前后台切换）
    WidgetsBinding.instance.addObserver(this);

    // 订阅消息发送请求事件（解耦：MessageService 通过事件请求发送消息）
    subscribeTo(
      AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(
        _handleMessageSendRequest,
      ),
    );

    // 订阅强制关闭事件（解耦：MessageS2C 通过事件强制关闭连接）
    subscribeTo(
      AppEventBus.on<WebSocketForceCloseEvent>().listen(_handleForceClose),
    );

    // 订阅重连请求事件（解耦：NetworkMonitor 通过事件请求重连）
    subscribeTo(
      AppEventBus.on<WebSocketReconnectRequestEvent>().listen(
        _handleReconnectRequest,
      ),
    );

    // 初始化连接（应用启动时调用）
    if (_shouldReconnect()) {
      openSocket(from: 'init');
    }
  }

  /// 处理消息发送请求事件
  void _handleMessageSendRequest(WebSocketMessageSendRequestEvent event) {
    sendMessage(event.message, event.messageId);
  }

  /// 处理强制关闭事件
  void _handleForceClose(WebSocketForceCloseEvent event) {
    iPrint('> ws: 收到强制关闭请求，permanent=${event.permanent}');
    closeSocket(permanent: event.permanent);
  }

  /// 处理重连请求事件
  void _handleReconnectRequest(WebSocketReconnectRequestEvent event) {
    iPrint('> ws: 收到重连请求，source=${event.source}');
    if (event.force || _shouldReconnect()) {
      // 延迟重连以避免频繁重连
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          if (_shouldReconnect()) {
            unawaited(openSocket(from: event.source));
          }
        }).catchError((Object e) {
          iPrint('> ws: 重连请求处理失败: $e');
        }),
      );
    }
  }

  /// 释放资源
  void dispose() {
    _cleanupResources(); // 先取消 _wsSub 并置空 _channel，使后续流回调成 no-op
    _teardown(); // 再解注册 observer 和 EventBus，清空回调表，重置 _initialized
  }

  /// 永久销毁：必须先调 _cleanupResources() 取消 _wsSub 并关闭 _channel，
  /// 再调此方法；否则 _wsSub 仍活跃，连接关闭事件（_onClose/_onError）会触发
  /// _scheduleReconnection()，在已析构的实例上调度重连。
  /// （removeObserver 是同步操作，移除即生效，无延迟窗口。）
  void _teardown() {
    WidgetsBinding.instance.removeObserver(this);
    cancelAllSubscriptions();
    _statusCallbacks.clear();
    _initialized = false;
  }

  /// App 生命周期回调：检测前后台切换
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      // 进入后台：取消已调度的重连定时器，避免按最大退避间隔持续唤醒耗电。
      // 回到前台时 _onAppResumed 会立即重连（若仍处于 disconnected）。
      if (_reconnectTimer != null) {
        iPrint('> ws: App 进入后台，暂停重连定时器');
        _cancelReconnectTimer();
      }
    }
  }

  /// App 回到前台时的处理
  void _onAppResumed() {
    if (!_initialized || !UserRepoLocal.to.isLoggedIn) return;

    if (_status == SocketStatus.disconnected) {
      iPrint('> ws: App 回到前台 — 连接已断开，立即重连');
      _backoff.reset();
      _cancelReconnectTimer();
      unawaited(openSocket(from: 'app_resumed'));
    } else if (_status == SocketStatus.connected) {
      // 连接可能已死但未检测到，发送探测包验证
      _probeConnection();
    }
  }

  /// 发送探测包验证连接是否仍然存活
  void _probeConnection() {
    if (_channel == null) return;
    try {
      if (_framing == FramingMode.v2) {
        _sendV2Heartbeat();
      } else {
        // v1 模式：主动发送应用层心跳（详见 _sendV1Heartbeat），
        // pong 超时会触发 _cancelStream + 重连，不再被动等待 onDone/onError。
        _sendV1Heartbeat();
      }
    } catch (e) {
      iPrint('> ws: probe failed, connection likely dead: $e');
      _cancelStream();
      _updateStatus(SocketStatus.disconnected);
      _backoff.reset();
      unawaited(openSocket(from: 'app_resumed_probe'));
    }
  }

  /// 统一状态更新方法
  void _updateStatus(SocketStatus newStatus) {
    if (_status != newStatus) {
      final oldStatus = _status;
      _status = newStatus;

      // 发布状态变化事件（解耦：MessageService 等通过事件监听状态）
      AppEventBus.fire(WebSocketStatusChangedEvent(status: newStatus.name));

      // 通知所有监听器
      for (final callback in _statusCallbacks) {
        try {
          callback(newStatus);
        } catch (e) {
          iPrint('> ws: 状态回调执行失败: $e');
        }
      }

      iPrint('> ws: 状态变化: ${oldStatus.name} -> ${newStatus.name}');
    }
  }

  /// 添加状态监听器
  void addStatusListener(void Function(SocketStatus) callback) {
    if (!_statusCallbacks.contains(callback)) {
      _statusCallbacks.add(callback);
    }
  }

  /// 移除状态监听器
  void removeStatusListener(void Function(SocketStatus) callback) {
    _statusCallbacks.remove(callback);
  }

  /// 判断是否需要建立连接
  bool _shouldReconnect() {
    return UserRepoLocal.to.isLoggedIn && !_connecting;
  }

  /// 对外接口：建立连接
  Future<void> openSocket({String from = ''}) async {
    if (!_preConnectionCheck()) return;
    await _establishConnection(from);
  }

  /// 连接前置检查
  bool _preConnectionCheck() {
    if (_connecting || _status == SocketStatus.connected) return false;
    if (!_checkLoginStatus()) return false;
    return true;
  }

  /// 检查用户登录状态
  bool _checkLoginStatus() {
    if (UserRepoLocal.to.isLoggedIn) return true;
    iPrint('> ws: 取消连接（用户未登录）');
    return false;
  }

  /// 建立WebSocket连接核心逻辑
  ///
  /// 使用 Completer 确保同一时刻只有一个连接请求在进行。
  /// 如果已有连接正在建立，后续请求会等待其完成，避免重复连接。
  Future<void> _establishConnection(String from) async {
    // 如果已有连接正在进行中，等待其完成而不是创建新连接
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      iPrint('> ws: 连接已在进行中，等待完成 (from: $from)');
      await _connectCompleter!.future;
      return;
    }

    _connectCompleter = Completer<void>();
    _connecting = true;
    _updateStatus(SocketStatus.connecting);
    iPrint('> ws: 开始连接 (from: $from)');

    try {
      // 增强的网络连通性检查
      if (!await _checkNetworkConnectivity()) {
        iPrint('> ws: 网络连通性检查失败，取消连接');
        return;
      }

      final token = await _getValidToken();
      if (token.isEmpty) {
        iPrint('> ws: 无效的访问令牌，取消连接');
        return;
      }

      // 根据 platform 选择连接方式
      final wsUrl = Env.effectiveWsUrl;
      if (wsUrl == null || wsUrl.isEmpty) {
        iPrint('> ws: WebSocket URL 未配置，取消连接');
        return;
      }

      // 子协议协商：imboy.v2 优先，回退到现有 text/sip
      const protocols = <String>[
        kSubProtocolV2,
        'imboy-protobuf',
        'imboy-json',
        'text',
        'sip',
      ];

      if (kIsWeb) {
        // Web 平台使用 WebSocketChannel.connect (protocols 作为位置参数)
        _channel = WebSocketChannel.connect(
          Uri.parse(wsUrl),
          protocols: protocols,
        );
      } else {
        // 移动端/桌面端使用 IOWebSocketChannel
        _channel = IOWebSocketChannel.connect(
          wsUrl,
          headers: {...await defaultHeaders(), Keys.tokenKey: token},
          protocols: protocols,
          pingInterval: _pingInterval,
        );
      }

      await _channel!.ready;

      // 检测服务端选中的子协议，设置 framing 模式
      _framing = _detectFraming(_channel);
      AppLogger.info(
        'WebSocket framing 模式: ${_framing.name} '
        '(selected protocol: ${_selectedProtocol(_channel)})',
      );

      // 心跳定时器：v2 走二进制帧，v1 走应用层文本 "ping"/"pong"
      // （之前 v1 完全依赖 IOWebSocketChannel 底层 ping/pong，Web 平台
      // 甚至没有该机制；现在两种模式都有主动探测 + 超时重连）。
      _v2HeartbeatTimer?.cancel();
      _v2HeartbeatTimer = null;
      _v1HeartbeatTimer?.cancel();
      _v1HeartbeatTimer = null;
      if (_framing == FramingMode.v2) {
        _v2PingSeq = 0;
        _v2HeartbeatTimer = Timer.periodic(
          _pingInterval,
          (_) => _sendV2Heartbeat(),
        );
      } else {
        _v1HeartbeatTimer = Timer.periodic(
          _pingInterval,
          (_) => _sendV1Heartbeat(),
        );
      }

      _updateStatus(SocketStatus.connected);
      _backoff.reset();
      _cancelReconnectTimer();
      await _flushMessageQueue();

      await _wsSub?.cancel();
      final start = DateTime.now();

      _wsSub = _channel?.stream.listen(
        (data) => _onMessage(data),
        onError: _onError,
        onDone: () {
          final end = DateTime.now();
          iPrint(
            'Connection closed after ${end.difference(start).inSeconds} seconds',
          );
          _onClose();
        },
        cancelOnError: true,
      );
      AppLogger.info('WebSocket 连接成功: ${Env.effectiveWsUrl}');
    } catch (e, s) {
      AppLogger.error('WebSocket 连接失败: ${Env.effectiveWsUrl}', e, s);
      await _handleConnectionFailure(e);
      // 【修复】异常发生时确保清理 WebSocket 资源
      _cancelStream();
    } finally {
      _connecting = false;
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete();
      }
    }
  }

  /// 处理连接失败后的操作
  Future<void> _handleConnectionFailure(Object error) async {
    // 在调度重连前必须先清零 _connecting，否则 _shouldReconnect() 因 !_connecting==false 而提前终止
    _connecting = false;
    _updateStatus(SocketStatus.disconnected);

    final String errorStr = error.toString();
    if (errorStr.contains('401')) {
      AppLogger.error('> ws: WebSocket 认证失败 (HTTP 401)，正在执行登出并重定向至登录页...');
      _cancelStream();
      await UserRepoLocal.to.quitLogin();
      navigateToSignIn(source: 'websocket_unauthorized_401');
      return;
    }

    _scheduleReconnection();
  }

  /// 从 channel 提取选中的子协议名称（跨平台安全访问）
  String? _selectedProtocol(WebSocketChannel? channel) {
    if (channel == null) return null;
    try {
      return channel.protocol;
    } catch (_) {
      return null;
    }
  }

  /// 根据选中的子协议判断 framing 模式
  FramingMode _detectFraming(WebSocketChannel? channel) {
    final proto = _selectedProtocol(channel);
    if (proto == kSubProtocolV2) return FramingMode.v2;
    return FramingMode.none;
  }

  static const Map<String, int> _msgTypeMap = {
    'C2C': FrameType.msgC2C,
    'C2G': FrameType.msgC2G,
    'C2CH': FrameType.msgC2CH,
    'C2S': FrameType.msgC2S,
    'S2C': FrameType.msgS2C,
  };

  /// 将待发送的字符串消息编码为 v2 frame bytes（仅在 framing=v2 时使用）
  ///
  /// 对于业务消息（JSON 字符串），从 payload 中提取 type 字段决定 FrameType：
  ///   C2C → msgC2C, C2G → msgC2G, C2S → msgC2S, 其它 → msgC2S
  /// 对于 CLIENT_ACK 纯文本 ACK，使用 msgC2S。
  Uint8List _encodeV2BusinessFrame(String message) {
    final payload = Uint8List.fromList(utf8.encode(message));
    int type = FrameType.msgC2S;
    if (message.startsWith('{')) {
      try {
        final decoded = jsonDecode(message);
        if (decoded is Map) {
          final t = (decoded['type']?.toString() ?? '').toUpperCase();
          type = _msgTypeMap[t] ?? FrameType.msgC2S;
        }
      } catch (_) {}
    }
    return ImboyFrame.encode(type: type, flags: 0, payload: payload);
  }

  /// v2 心跳：发送 heartbeatPing frame
  void _sendV2Heartbeat() {
    if (_framing != FramingMode.v2 || _channel == null) return;
    final seq = _v2PingSeq;
    _v2PingSeq = (_v2PingSeq + 1) & 0xFFFF;
    try {
      final bytes = ImboyFrame.heartbeatPing(seq);
      _channel!.sink.add(bytes);
    } catch (e) {
      iPrint('> ws: v2 heartbeat 发送失败: $e');
    }
  }

  /// v1 模式应用层心跳：发送纯文本 "ping"，后端 websocket_handler.erl
  /// 已原生支持（收到 "ping" 直接回 "pong"，无需改后端）。
  /// 若上一轮 pong 一直未到（_v1PongTimer 仍在跑），说明连接早已死透，
  /// 直接判定失败并重连，不再等待这一轮的探测结果。
  void _sendV1Heartbeat() {
    if (_framing == FramingMode.v2 || _channel == null) return;
    if (_v1PongTimer != null) {
      iPrint('> ws: v1 heartbeat 上一轮 pong 仍未到，判定连接已死');
      _handleV1HeartbeatTimeout();
      return;
    }
    try {
      _channel!.sink.add('ping');
      _v1PongTimer = Timer(_v1PongTimeout, _handleV1HeartbeatTimeout);
    } catch (e) {
      iPrint('> ws: v1 heartbeat 发送失败: $e');
    }
  }

  void _handleV1HeartbeatTimeout() {
    iPrint('> ws: v1 heartbeat pong 超时，判定连接已死，主动重连');
    _v1PongTimer?.cancel();
    _v1PongTimer = null;
    _cancelStream();
    _updateStatus(SocketStatus.disconnected);
    _scheduleReconnection();
  }

  /// 处理收到的 v2 二进制帧（不抛出）
  void _handleV2Binary(Uint8List bytes) {
    try {
      final result = ImboyFrame.tryDecode(bytes);
      if (result == null) {
        iPrint('> ws: v2 帧不完整，忽略 (${bytes.length} bytes)');
        return;
      }
      final frame = result.frame;
      switch (frame.type) {
        case FrameType.heartbeatPong:
          // 心跳 pong 静默处理，避免每 120s 触发一次 PrettyPrinter
          break;
        case FrameType.heartbeatPing:
          // 服务端主动 ping，回 pong
          if (frame.payload.length >= 2) {
            final seq = ByteData.sublistView(
              frame.payload,
            ).getUint16(0, Endian.big);
            try {
              _channel?.sink.add(ImboyFrame.heartbeatPong(seq));
            } catch (e) {
              iPrint('> ws: v2 pong 回包失败: $e');
            }
          }
          break;
        case FrameType.ack:
          // 【契约】0x03 ACK 帧载荷为定长 8 字节 uint64，装不下 Xid 字符串 id，
          // 服务端也从不下发该帧；Xid 体系的确认一律走 JSON *_SERVER_ACK /
          // CLIENT_ACK_CONFIRM（MSG_S2C 帧）。此处仅日志，禁止拿数字串去
          // ackConfirmed——数字串与 Xid 永不相等，且会误清机制C。
          if (frame.payload.length >= 8) {
            final msgId = ByteData.sublistView(
              frame.payload,
            ).getUint64(0, Endian.big);
            iPrint('⚠️ [WS] v2 frame ACK(0x03) 收到意外帧, msgId=$msgId, 忽略');
          }
          break;
        case FrameType.nack:
          if (frame.payload.length >= 8) {
            final msgId = ByteData.sublistView(
              frame.payload,
            ).getUint64(0, Endian.big);
            iPrint('⚠️ [WS] v2 frame NACK: msgId=$msgId');
          }
          break;
        case FrameType.msgRead:
          // 已读状态帧
          if (frame.payload.length >= 8) {
            final msgId = ByteData.sublistView(
              frame.payload,
            ).getUint64(0, Endian.big);
            iPrint('📖 [WS] v2 frame msgRead: msgId=$msgId');
            // 通过事件总线发布已读状态更新
            AppEventBus.fire(
              WebSocketMessageReceivedEvent(
                type: 'MSG_READ',
                data: {'id': msgId.toString(), 'action': 'MSG_READ'},
              ),
            );
          }
          break;
        case FrameType.msgTyping:
          if (frame.payload.length >= 9) {
            final bd = ByteData.sublistView(frame.payload);
            final convId = bd.getUint64(0, Endian.big);
            final status = bd.getUint8(8);
            iPrint(
              '⌨️ [WS] v2 frame msgTyping: convId=$convId, status=$status',
            );
            AppEventBus.fire(
              WebSocketMessageReceivedEvent(
                type: 'S2C',
                data: {
                  'action': status == 1 ? 'typing' : 'stop_typing',
                  'from': convId.toString(), // 简化处理
                },
              ),
            );
          }
          break;
        case FrameType.msgRecall:
          if (frame.payload.length >= 8) {
            final msgId = ByteData.sublistView(
              frame.payload,
            ).getUint64(0, Endian.big);
            iPrint('↩️ [WS] v2 frame msgRecall: msgId=$msgId');
            AppEventBus.fire(
              WebSocketMessageReceivedEvent(
                type: 'S2C',
                data: {
                  'action': 'c2c_revoke',
                  'payload': {'old_msg_id': msgId.toString()},
                },
              ),
            );
          }
          break;
        case FrameType.msgS2C:
        case FrameType.msgC2C:
        case FrameType.msgC2G:
        case FrameType.msgC2S:
          // 业务消息：先尝试 protobuf 解码，失败则 JSON 回退
          final pbMap = ImboyPbCodec.tryDecode(frame.payload);
          if (pbMap != null) {
            // Protobuf decoded successfully → re-encode as JSON for downstream
            _onMessage(jsonEncode(pbMap));
          } else {
            final text = utf8.decode(frame.payload, allowMalformed: true);
            _onMessage(text);
          }
          break;
        default:
          iPrint('> ws: v2 未知 frame type=0x${frame.type.toRadixString(16)}');
      }
    } on FormatException catch (e) {
      // 服务端在 v2 连接上偶发以「裸 protobuf / JSON」旁路投递业务消息
      // （无 IB 帧头，根因见后端 user_server:online → encode_delivery_frame
      // 命中 {protobuf,_} 分支，State.framing 非 v2）。此处不丢弃，退回按
      // 无封包的业务 payload 解析——与下方 msgC2C/S2C 分支同款逻辑，下游
      // contentHash 去重保证重复投递安全。
      if (_tryDecodeUnframedPayload(bytes)) return;
      iPrint('> ws: v2 帧解析失败（格式错误且非 protobuf/JSON），忽略: $e');
    } catch (e, s) {
      iPrint('> ws: v2 帧处理异常: $e\n$s');
    }
  }

  /// 尝试把「无 v2 帧头」的字节按裸 protobuf / JSON 业务消息解析并分发。
  /// 成功返回 true（已交给 _onMessage 走正常 S2C/C2C 管道），否则 false。
  bool _tryDecodeUnframedPayload(Uint8List bytes) {
    try {
      final pbMap = ImboyPbCodec.tryDecode(bytes);
      if (pbMap != null) {
        _onMessage(jsonEncode(pbMap));
        return true;
      }
      final text = utf8.decode(bytes, allowMalformed: false);
      final trimmed = text.trimLeft();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        _onMessage(text);
        return true;
      }
    } on FormatException {
      // 非合法 UTF-8/JSON，落到调用方的忽略分支
    }
    return false;
  }

  /// 处理接收到的消息（优化版：非阻塞立即分发）
  /// Process received messages (optimized: non-blocking immediate dispatch)
  void _onMessage(dynamic message) {
    // v2 路径：binary 数据走 frame 解码
    if (_framing == FramingMode.v2 && message is List<int>) {
      _handleV2Binary(
        message is Uint8List ? message : Uint8List.fromList(message),
      );
      return;
    }

    // v2 模式下收到 text frame（协议不匹配 / 服务端 bug）：
    // 记录警告，但仍尝试 JSON 解析作为降级
    if (_framing == FramingMode.v2 && message is String) {
      iPrint('[WS] v2 收到 text frame (${message.length} chars)，降级 JSON');
    }

    // 快速空值检查
    if (message == null || (message is String && message.trim().isEmpty)) {
      return;
    }

    // v1 心跳 pong 快速路径：避免走 JSON 解析报错 + RAW_MESSAGE 事件噪音
    if (message is String) {
      final trimmed = message.trim();
      if (trimmed == 'pong' || trimmed == 'PONG') {
        _v1PongTimer?.cancel();
        _v1PongTimer = null;
        return;
      }
    }

    try {
      // 统一消息解析
      final msg = _parseMessage(message);
      if (msg.isEmpty) return;

      final action = msg['action']?.toString() ?? '';
      final messageType = (msg['type']?.toString() ?? '').toUpperCase();
      var messageId = msg['id']?.toString() ?? '';
      msg['type'] = messageType;

      // 服务端 ACK/错误帧偶发不把 msgId 放在 id 字段（无帧头降级 JSON），
      // 跨常见字段名兜底提取，否则 CLIENT_ACK_ERROR 无法关联 → 确认超时重发死循环
      if (messageId.isEmpty) {
        for (final k in const [
          'msg_id',
          'msgId',
          'ack_id',
          'ackId',
          'message_id',
        ]) {
          final v = msg[k]?.toString() ?? '';
          if (v.isNotEmpty) {
            messageId = v;
            break;
          }
        }
        // 仍为空且是 ACK 类响应：打印原始帧以定位服务端真实字段名
        if (messageId.isEmpty &&
            (action == 'CLIENT_ACK_ERROR' || action == 'CLIENT_ACK_CONFIRM')) {
          iPrint('⚠️ [WS] $action 缺 msgId，原始帧: $message');
        }
      }

      // 合并日志：每条消息仅 1 次日志调用（避免 PrettyPrinter 重复格式化）
      iPrint('[WS] msg type=$messageType id=$messageId action=$action');

      if (messageId.isNotEmpty) {
        // *_SERVER_ACK 是服务端对出站消息的回执：确认统一由下游
        // MessageService._receiveServerAck 走单一清除入口
        // RemoveFromRetryQueueRequestedEvent（停重发 + DB status→sent），
        // 此处不做本地簿记；分支存在只为避免回执落入下方回 ACK 的分支
        // （WEBRTC_SERVER_ACK 若中 startsWith('WEBRTC_') 会反向发 CLIENT_ACK）。
        if (messageType.endsWith('_SERVER_ACK')) {
          // no-op：见上方注释
        } else if (messageType.startsWith('WEBRTC_')) {
          _sendAckDirectSafe('WEBRTC', messageId);
        } else if (['S2C', 'C2S', 'C2C', 'C2G'].contains(messageType)) {
          _sendAckSafe(messageType, messageId);
        }
        _handleMessageAck(action, messageId, reason: msg['reason']?.toString());
      }

      // 【优化】过滤 ACK 相关消息，避免转发到 MessageService
      if (action == 'CLIENT_ACK_CONFIRM' ||
          action == 'CLIENT_ACK_ERROR' ||
          action.endsWith('_ACK')) {
        return;
      }

      // 统一分发到事件总线（非阻塞，不等待处理完成）
      try {
        AppEventBus.fire(
          WebSocketMessageReceivedEvent(type: messageType, data: msg),
        );
      } catch (e) {
        iPrint('[WS] dispatch error: $e');
      }
    } catch (e) {
      iPrint('[WS] parse error: ${e.runtimeType}');
      _handleRawMessage(message);
    }
  }

  void _sendAckDirectSafe(String type, String messageId) {
    try {
      AckManager.to.sendAckDirect(type, messageId);
    } catch (e) {
      iPrint('[WS_ACK] $type ACK fail: $e');
    }
  }

  void _sendAckSafe(String type, String messageId) {
    try {
      AckManager.to.sendAck(type, messageId);
    } catch (e) {
      iPrint('[WS_ACK] fail: $e');
    }
  }

  /// 统一消息解析方法
  Map<String, dynamic> _parseMessage(dynamic message) {
    if (message is String) {
      return jsonDecode(message) as Map<String, dynamic>;
    } else if (message is Map<String, dynamic>) {
      return message;
    } else if (message is Map) {
      return Map<String, dynamic>.from(message);
    }
    throw FormatException('不支持的消息格式: ${message.runtimeType}');
  }

  /// 统一处理消息确认（包含ACK和撤回确认）
  void _handleMessageAck(String action, String messageId, {String? reason}) {
    // action-ACK（撤回/编辑/表情回应等无 *_SERVER_ACK 的操作确认）：
    // 汇入出站确认状态机的单一清除入口（MessageRetry 停重发）。
    // CLIENT_ACK_CONFIRM/ERROR 属机制C（入站收据），不在此列。
    if (action.endsWith('_ACK') &&
        action != 'CLIENT_ACK' &&
        messageId.isNotEmpty) {
      AppEventBus.fire(
        RemoveFromRetryQueueRequestedEvent(
          messageId: messageId,
          messageType: 'UNKNOWN',
          reason: 'ws_action_ack',
        ),
      );
    }

    // 【改进】处理CLIENT_ACK的确认消息，通知AckManager停止重试
    if (action == 'CLIENT_ACK_CONFIRM' && messageId.isNotEmpty) {
      try {
        AckManager.to.ackConfirmed(messageId);
        iPrint('✅ [WS] CLIENT_ACK确认收到: msgId=$messageId');
      } catch (e) {
        iPrint('⚠️ [WS] AckManager处理失败: $e');
      }
    }

    // #4: CLIENT_ACK_ERROR 语义是「我方收据被服务端判无效」，不能当成功确认。
    // 用 ackRejected（停重试但不记成功 RTT）替代 ackConfirmed，避免把失败当已确认。
    if (action == 'CLIENT_ACK_ERROR' && messageId.isNotEmpty) {
      try {
        AckManager.to.ackRejected(messageId, reason: reason);
        iPrint(
          '⚠️ [WS] CLIENT_ACK_ERROR收到: msgId=$messageId（收据被拒 reason=$reason）',
        );
      } catch (e) {
        iPrint('⚠️ [WS] AckManager处理失败: $e');
      }
    }
  }

  /// 处理原始消息（当JSON解析失败时）
  void _handleRawMessage(dynamic rawMessage) {
    try {
      AppEventBus.fireData({
        'type': 'RAW_MESSAGE',
        'data': rawMessage,
        'timestamp': DateTimeHelper.millisecond(),
      });
    } catch (e) {
      iPrint('> ws: 原始消息处理失败: $e');
    }
  }

  void _cleanupResources() {
    _cancelStream(); // null _channel → _flushMessageQueue 循环 break → finally 自行重置 _isFlushing
    _cancelReconnectTimer();
    // 不在此重置 _isFlushing：若旧 flush 仍挂起，finally 会在其 await 恢复后自行置 false；
    // 在此提前重置会与新 flush 设置的 true 发生竞态，导致互斥锁失效。
  }

  /// 发送积压消息（优化版：加边界、异常、速率限制、并发防护）
  Future<void> _flushMessageQueue() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      const int maxBatch = 10;
      const Duration minDelay = Duration(milliseconds: 30);

      int sentCount = 0;

      while (!_messageQueue.isEmpty && _status == SocketStatus.connected) {
        if (_channel == null) break;
        final queued = _messageQueue.dequeueByPriority();
        if (queued == null) continue;

        try {
          final payload = _framing == FramingMode.v2
              ? _encodeV2BusinessFrame(queued.data)
              : queued.data;
          _channel!.sink.add(payload);
          sentCount++;
          if (sentCount >= maxBatch) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            sentCount = 0;
          } else {
            await Future<void>.delayed(minDelay);
          }
        } catch (e, s) {
          iPrint('> ws: flushMessageQueue failed: $e\n$s');
          _messageQueue.enqueue(
            queued.id,
            queued.data,
            priority: queued.priority,
          );
          // sink.add 失败通常意味着 channel 已死（而非单条消息本身的问题），
          // 继续发送其余消息大概率会重复失败。主动清理并调度重连，而不是
          // 被动等待 onError/onDone（可能迟迟不触发，导致 _status 停留在
          // connected 但实际发不出消息的"僵尸连接"，队列永久卡住）。
          _cancelStream();
          _updateStatus(SocketStatus.disconnected);
          _scheduleReconnection();
          break;
        }
        if (_status != SocketStatus.connected) break;
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// 获取有效Token（含自动刷新）
  Future<String> _getValidToken() async {
    try {
      if (!UserRepoLocal.to.isLoggedIn) return '';
      String token = await UserRepoLocal.to.accessToken;
      if (!tokenExpired(token)) return token;
      return await _refreshAccessToken();
    } catch (e, s) {
      iPrint("$e; $s");
      UserRepoLocal.to.quitLogin();
      navigateToSignIn(source: 'websocket_relogin');
      return '';
    }
  }

  /// 刷新访问令牌
  Future<String> _refreshAccessToken() async {
    final newToken = await UserApi.to.refreshAccessTokenApi(
      await UserRepoLocal.to.refreshToken,
      checkNewToken: false,
    );
    return newToken;
  }

  /// 处理连接丢失
  void _onError(Object e) {
    iPrint("_onError $e;");
    if (_status == SocketStatus.disconnected) return;
    iPrint('> ws_onError: 连接丢失');
    _updateStatus(SocketStatus.disconnected);
    _cancelStream();
    _scheduleReconnection();
  }

  void _onClose() {
    if (_status == SocketStatus.disconnected) return;
    final int closeCode = _channel?.closeCode ?? 0;
    final String closeReason = _channel?.closeReason ?? '';
    iPrint('> ws_onClose: 连接丢失 $closeCode: $closeReason;');

    _updateStatus(SocketStatus.disconnected);

    switch (closeCode) {
      case 4006:
        _cancelStream(); // 先清理资源，再执行登出跳转
        UserRepoLocal.to.quitLogin();
        navigateToSignIn(source: 'websocket_relogin');
        break;
      default:
        _cancelStream();
        _scheduleReconnection();
    }
  }

  /// 调度重连任务
  void _scheduleReconnection() {
    if (!_shouldScheduleReconnect()) {
      AppLogger.warning(
        'WebSocket 停止重试（已尝试 ${_backoff.attempts}/${_backoff.maxRetries} 次）',
      );
      return;
    }

    if (_lifecycleState == AppLifecycleState.paused) {
      // App 在后台：不调度新的重连定时器，等 _onAppResumed 回前台时立即重试，
      // 避免长期离线时按最大退避间隔（最长2分钟）持续唤醒耗电。
      iPrint('> ws: App 处于后台，跳过本次重连调度');
      return;
    }

    final delay = _backoff.nextDelay();
    final nextAttempt = _backoff.attempts;

    AppLogger.info(
      'WebSocket 将在 ${delay.inSeconds} 秒后重连 (第 $nextAttempt/${_backoff.maxRetries} 次尝试)',
    );

    _cancelReconnectTimer();
    _reconnectTimer = Timer(delay, () {
      AppLogger.debug('WebSocket 重连定时器触发');
      openSocket(from: 'reconnectattempt_$nextAttempt');
    });
  }

  /// 判断是否需要调度重连
  bool _shouldScheduleReconnect() {
    return _shouldReconnect() &&
        _backoff.attempts < _backoff.maxRetries &&
        _status != SocketStatus.connected;
  }

  /// 网络连通性检查（使用网络监控服务，无 HTTP 开销）
  Future<bool> _checkNetworkConnectivity() async {
    try {
      // 使用网络监控服务检查网络状态（轻量，无 HTTP 请求）
      final hasNetwork = NetworkMonitorService.to.hasNetwork;

      if (!hasNetwork) {
        iPrint('> ws: 设备无网络连接');
        _updateStatus(SocketStatus.disconnected);
        _connecting = false;
        return false;
      }

      return true;
    } catch (e) {
      iPrint('> ws: 网络连通性检查异常: $e');
      return true;
    }
  }

  /// 手动关闭连接
  ///
  /// [permanent]=false（默认）：临时断开，保留 observer 和 EventBus 订阅，允许重连。
  /// [permanent]=true：永久销毁实例，单例置空，重连请求将创建新实例。
  Future<void> closeSocket({bool permanent = false}) async {
    iPrint('> ws: 手动关闭连接');
    _updateStatus(SocketStatus.disconnected);
    _cleanupResources();
    if (permanent) {
      _teardown();
      _instance = null;
    }
  }

  /// 发送消息核心方法（优化版：简化确认机制）
  Future<bool> sendMessage(String message, String? messageId) async {
    if (!_preMessageCheck(message)) return false;

    if (_status == SocketStatus.connected) {
      try {
        final payload = _framing == FramingMode.v2
            ? _encodeV2BusinessFrame(message)
            : message;
        _channel?.sink.add(payload);
        _logMessageSent(message, messageId);
        // 出站确认/重发由 MessageRetry 状态机负责（调用方 addToRetryQueue），
        // 此处不再做本地待确认簿记。
        return true;
      } catch (e) {
        iPrint('> ws: 消息发送失败: $e');
        await _handleSendFailure(message, messageId);
        return false;
      }
    }

    // 连接断开时，消息入队等待重连
    iPrint('> ws: 连接断开，消息入队');
    _enqueueMessage(message);

    // 尝试重新连接
    await openSocket(from: 'sendMessage');
    return false;
  }

  /// 同步发送消息（用于 ACK 等需要立即发送的场景）
  /// 不经过消息队列，直接通过 WebSocket 发送
  bool sendDirect(dynamic message) {
    if (_status == SocketStatus.connected && _channel != null) {
      try {
        dynamic payload;
        if (message is String) {
          payload = _framing == FramingMode.v2
              ? _encodeV2BusinessFrame(message)
              : message;
        } else {
          // 二进制数据直接发送
          payload = message;
        }
        _channel!.sink.add(payload);
        return true;
      } catch (e) {
        iPrint('> ws: 直接发送消息失败: $e');
        return false;
      }
    }
    return false;
  }

  /// 处理消息发送失败
  Future<void> _handleSendFailure(String message, String? messageId) async {
    iPrint('> ws: 处理消息发送失败 (${messageId ?? 'unknown'})');

    // 将消息加入重试队列
    _enqueueMessage(message);

    // 如果是网络问题，尝试重新连接
    if (_status != SocketStatus.connected) {
      await openSocket(from: 'retryAfterFailure');
    }
  }

  /// 安全记录消息发送日志（不泄露敏感信息）
  ///
  /// 在生产环境中只输出消息类型和大小，不输出完整内容
  /// 在开发环境中可通过 'debug_log_websocket_full' 开关启用详细日志
  void _logMessageSent(String message, String? messageId) {
    final id = messageId ?? 'unknown';
    if (kDebugMode &&
        StorageService.to.getBool('debug_log_websocket_full') == true) {
      // 开发环境且启用详细日志时输出完整内容
      iPrint('> ws: 消息已发送 ($id): $message ;');
    } else {
      // 默认只输出消息类型和大小（不包含敏感内容）
      final msgType = _getMessageTypeInfo(message);
      iPrint('> ws: 消息已发送 ($id) [$msgType] [${message.length} bytes]');
    }
  }

  /// 提取消息类型信息（不包含敏感内容）
  ///
  /// 返回格式：消息类型/消息子类型/加密状态
  /// 例如：C2C/text/E2EE 或 C2G/image/PLAIN
  String _getMessageTypeInfo(String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'] ?? 'UNKNOWN';
      final msgType = data['msg_type'] ?? 'unknown';
      final encStatus = data['e2ee'] != null ? 'E2EE' : 'PLAIN';
      return '$type/$msgType/$encStatus';
    } catch (_) {
      return 'UNKNOWN';
    }
  }

  /// 消息发送前检查
  bool _preMessageCheck(String message) {
    if (!UserRepoLocal.to.isLoggedIn) {
      iPrint('> ws: 消息丢弃（用户未登录）');
      return false;
    }
    if (message.isEmpty) {
      iPrint('> ws: 空消息被过滤');
      return false;
    }
    return true;
  }

  /// 消息入队处理
  /// 使用消息内容的 SHA-1 摘要作为队列 ID，避免 hashCode 碰撞
  void _enqueueMessage(String message) {
    if (_messageQueue.messages.any((m) => m.data == message)) return;
    String msgId = '${message.length}_${message.hashCode}';
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map && decoded.containsKey('id')) {
        msgId = decoded['id'].toString();
      }
    } catch (_) {}
    _messageQueue.enqueue(msgId, message, priority: 0);
    iPrint('> ws: 消息入队（当前队列长度：${_messageQueue.messages.length}）');
  }

  void _cancelStream() {
    if (_wsSub != null) unawaited(_wsSub!.cancel());
    _wsSub = null;
    _channel?.sink.close();
    _channel = null;
    _v2HeartbeatTimer?.cancel();
    _v2HeartbeatTimer = null;
    _v1HeartbeatTimer?.cancel();
    _v1HeartbeatTimer = null;
    _v1PongTimer?.cancel();
    _v1PongTimer = null;
    _framing = FramingMode.none;
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 获取WebSocket URL
  /// Get WebSocket URL
  String? getWebSocketUrl() => Env.effectiveWsUrl;

  /// 获取消息队列大小
  /// Get message queue size
  int getMessageQueueSize() => _messageQueue.messages.length;

  /// 获取连接统计信息
  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'status': _status.name,
      'message_queue_size': _messageQueue.messages.length,
      'connection_attempts': _backoff.attempts,
      'is_flushing': _isFlushing,
      'current_url': getWebSocketUrl(),
    };
  }
}
