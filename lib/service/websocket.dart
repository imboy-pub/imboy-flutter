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
  final Set<String> _pendingMessages = <String>{}; // 等待确认的消息ID
  WebSocketChannel? _channel;
  bool _isFlushing = false;

  // 订阅管理
  // 不走 EventSubscriptionManager —— 需在 _cancelStream() 中与 _channel.sink.close() 同步执行
  StreamSubscription<dynamic>? _wsSub;
  Timer? _reconnectTimer;
  Timer? _v2HeartbeatTimer;
  final Set<Timer> _confirmationTimers = {};
  bool _initialized = false;

  // 配置参数
  static const _pingInterval = Duration(seconds: 60);
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
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        // App 进入后台：OS 会挂起定时器，无需主动断开
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // 过渡态/不可见态，无需处理
        break;
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
      }
      // v1 模式：无法主动发探测包；pingInterval 超时后 onDone/onError 会
      // 自动触发 _onClose/_onError 进而重连，此处无需额外操作。
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

      // v2 模式下启动 IMBoy 层 heartbeat 定时器
      _v2HeartbeatTimer?.cancel();
      _v2HeartbeatTimer = null;
      if (_framing == FramingMode.v2) {
        _v2PingSeq = 0;
        _v2HeartbeatTimer = Timer.periodic(
          _pingInterval,
          (_) => _sendV2Heartbeat(),
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
      _handleConnectionFailure(e);
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
  void _handleConnectionFailure(Object error) {
    _updateStatus(SocketStatus.disconnected);
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

  /// 将待发送的字符串消息编码为 v2 frame bytes（仅在 framing=v2 时使用）
  ///
  /// 对于业务消息（JSON 字符串），从 payload 中提取 type 字段决定 FrameType：
  ///   C2C → msgC2C, C2G → msgC2G, C2S → msgC2S, 其它 → msgC2S
  /// 对于 CLIENT_ACK 纯文本 ACK，使用 msgC2S。
  Uint8List _encodeV2BusinessFrame(String message) {
    final payload = Uint8List.fromList(utf8.encode(message));
    int type = FrameType.msgC2S;
    try {
      if (message.startsWith('CLIENT_ACK')) {
        type = FrameType.msgC2S;
      } else if (message.startsWith('{')) {
        final decoded = jsonDecode(message);
        if (decoded is Map) {
          final t = (decoded['type']?.toString() ?? '').toUpperCase();
          switch (t) {
            case 'C2C':
              type = FrameType.msgC2C;
              break;
            case 'C2G':
              type = FrameType.msgC2G;
              break;
            case 'C2CH':
              type = FrameType.msgC2CH;
              break;
            case 'C2S':
              type = FrameType.msgC2S;
              break;
            case 'S2C':
              type = FrameType.msgS2C;
              break;
            default:
              type = FrameType.msgC2S;
          }
        }
      }
    } catch (_) {
      // 解析失败时回退 msgC2S
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
          if (frame.payload.length >= 8) {
            final msgId = ByteData.sublistView(
              frame.payload,
            ).getUint64(0, Endian.big);
            iPrint('✅ [WS] v2 frame ACK: msgId=$msgId');
            try {
              AckManager.to.ackConfirmed(msgId.toString());
            } catch (e) {
              iPrint('> ws: v2 ack 处理失败: $e');
            }
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
      iPrint('> ws: v2 帧解析失败（格式错误），忽略: $e');
    } catch (e, s) {
      iPrint('> ws: v2 帧处理异常: $e\n$s');
    }
  }

  /// 处理接收到的消息（优化版：非阻塞立即分发）
  /// Process received messages (optimized: non-blocking immediate dispatch)
  void _onMessage(dynamic message) {
    // v2 路径：binary 数据走 frame 解码
    if (_framing == FramingMode.v2 && message is List<int>) {
      final bytes = message is Uint8List
          ? message
          : Uint8List.fromList(message);
      _handleV2Binary(bytes);
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

    try {
      // 统一消息解析
      final msg = _parseMessage(message);
      if (msg.isEmpty) return;

      final action = msg['action']?.toString() ?? '';
      final messageType = msg['type']?.toString() ?? '';
      final messageId = msg['id']?.toString() ?? '';

      final type = messageType.toUpperCase();
      msg['type'] = type;

      // 合并日志：每条消息仅 1 次日志调用（避免 PrettyPrinter 重复格式化）
      iPrint('[WS] msg type=$type id=$messageId action=$action');

      // 【关键优化】立即发送ACK，避免服务器超时重试
      // 先处理 WEBRTC（需要独立处理）
      if (type.startsWith('WEBRTC_') && messageId.isNotEmpty) {
        try {
          AckManager.to.sendAckDirect('WEBRTC', messageId);
        } catch (e) {
          iPrint('[WS_ACK] WEBRTC ACK fail: $e');
        }
      }

      // 统一 ACK 发送入口：所有需要 ACK 的消息类型（按优先级排序）
      // 优先级：S2C(服务端指令) > C2S(服务端确认) > C2C(单聊) > C2G(群聊)
      if (['S2C', 'C2S', 'C2C', 'C2G'].contains(type) && messageId.isNotEmpty) {
        try {
          AckManager.to.sendAckDirect(type, messageId);
        } catch (e) {
          iPrint('[WS_ACK] fail: $e');
        }
      }

      // 消息确认处理（包含ACK和撤回确认）
      _handleMessageAck(action, messageId);

      // 【优化】过滤 ACK 相关消息，避免转发到 MessageService
      // 这些消息已在 WebSocket 层面处理完成，不需要进一步处理
      if (action == 'CLIENT_ACK_CONFIRM' ||
          action == 'CLIENT_ACK_ERROR' ||
          action.endsWith('_ACK')) {
        return;
      }

      // 统一分发到事件总线（非阻塞，不等待处理完成）
      try {
        // ⚡ 非阻塞处理：通过事件总线发布消息，解耦 WebSocket 和 MessageService
        AppEventBus.fire(WebSocketMessageReceivedEvent(type: type, data: msg));
      } catch (e) {
        iPrint('[WS] dispatch error: $e');
      }
    } catch (e) {
      iPrint('[WS] parse error: ${e.runtimeType}');
      // 解析失败时发送原始消息事件
      _handleRawMessage(message);
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
  void _handleMessageAck(String action, String messageId) {
    if (action.endsWith('_ACK')) {
      _handleMessageConfirmation(messageId);
    }

    // 处理撤回消息的特殊确认
    if (action.contains('REVOKE') &&
        action.endsWith('_REVOKE_ACK') &&
        messageId.isNotEmpty) {
      _handleMessageConfirmation(messageId);
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

    // 【补充】处理CLIENT_ACK的确认消息，通知AckManager停止重试
    if (action == 'CLIENT_ACK_ERROR' && messageId.isNotEmpty) {
      try {
        AckManager.to.ackConfirmed(messageId);
        iPrint('⚠️ [WS] CLIENT_ACK_ERROR收到: msgId=$messageId（ACK处理失败）');
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

        // 如果有消息ID，启动确认机制
        if (messageId != null) {
          bool isRevokeMessage = false;
          try {
            final messageData = jsonDecode(message);
            final messageType = messageData['type']?.toString() ?? '';
            isRevokeMessage = messageType.contains('REVOKE');
          } catch (e) {
            // 忽略解析错误
          }

          _startMessageConfirmation(
            messageId,
            isRevokeMessage: isRevokeMessage,
          );
        }

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

  /// 启动消息确认机制
  void _startMessageConfirmation(
    String messageId, {
    bool isRevokeMessage = false,
  }) {
    // 设置超时确认（普通消息5秒，撤回消息10秒）
    int timeoutSeconds = isRevokeMessage ? 10 : 5;

    late final Timer timer;
    timer = Timer(Duration(seconds: timeoutSeconds), () {
      _confirmationTimers.remove(timer);
      if (_pendingMessages.remove(messageId)) {
        final isConnected = _status == SocketStatus.connected;
        iPrint('> ws: 消息确认超时: $messageId (连接正常: $isConnected)');
        // 连接断开时才通知失败，连接正常可能是服务端延迟
        if (!isConnected) {
          _notifyMessageSendResult(messageId, false);
        }
      }
    });
    _confirmationTimers.add(timer);

    _pendingMessages.add(messageId);
  }

  /// 处理消息确认（当收到服务器ACK时调用）
  void _handleMessageConfirmation(String messageId) {
    if (_pendingMessages.remove(messageId)) {
      iPrint('> ws: 消息已确认: $messageId');
      _notifyMessageSendResult(messageId, true);

      // 通知消息重试队列移除（覆盖 action-ack 场景，形成发送闭环）
      AppEventBus.fire(
        RemoveFromRetryQueueRequestedEvent(
          messageId: messageId,
          messageType: 'UNKNOWN',
          reason: 'ws_action_ack',
        ),
      );
    }
  }

  /// 安全记录消息发送日志（不泄露敏感信息）
  ///
  /// 在生产环境中只输出消息类型和大小，不输出完整内容
  /// 在开发环境中可通过 'debug_log_websocket_full' 开关启用详细日志
  void _logMessageSent(String message, String? messageId) {
    final id = messageId ?? 'unknown';

    // 检查是否启用完整日志（仅开发环境）
    final enableFullLog =
        kDebugMode &&
        StorageService.to.getBool('debug_log_websocket_full') == true;

    if (enableFullLog) {
      // 开发环境且启用详细日志时输出完整内容
      iPrint('> ws: 消息已发送 ($id): $message ;');
    } else {
      // 默认只输出消息类型和大小（不包含敏感内容）
      final msgType = _getMessageTypeInfo(message);
      final size = message.length;
      iPrint('> ws: 消息已发送 ($id) [$msgType] [$size bytes]');
    }
  }

  /// 提取消息类型信息（不包含敏感内容）
  ///
  /// 返回格式：消息类型/消息子类型/加密状态
  /// 例如：C2C/text/E2EE 或 C2G/image/PLAIN
  String _getMessageTypeInfo(String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type']?.toString() ?? 'UNKNOWN';
      final msgType = data['msg_type']?.toString() ?? 'unknown';
      final hasE2ee = data['e2ee'] != null;
      final encStatus = hasE2ee ? 'E2EE' : 'PLAIN';
      return '$type/$msgType/$encStatus';
    } catch (e) {
      return 'UNKNOWN';
    }
  }

  /// 通知消息发送结果
  void _notifyMessageSendResult(String messageId, bool success) {
    // 通过事件总线通知消息发送结果
    AppEventBus.fireData({
      'type': 'MESSAGE_SEND_RESULT',
      'messageId': messageId,
      'success': success,
    });
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
    final exists = _messageQueue.messages.any((m) => m.data == message);
    if (!exists) {
      // 从消息 JSON 中提取 id 字段作为唯一标识，回退使用内容长度+哈希组合
      String msgId;
      try {
        final decoded = jsonDecode(message);
        msgId = (decoded is Map && decoded.containsKey('id'))
            ? decoded['id'].toString()
            : '${message.length}_${message.hashCode}';
      } catch (_) {
        msgId = '${message.length}_${message.hashCode}';
      }
      _messageQueue.enqueue(msgId, message, priority: 0);
      iPrint('> ws: 消息入队（当前队列长度：${_messageQueue.messages.length}）');
    }
  }

  void _cancelStream() {
    if (_wsSub != null) unawaited(_wsSub!.cancel());
    _wsSub = null;
    _channel?.sink.close();
    _channel = null;
    _v2HeartbeatTimer?.cancel();
    _v2HeartbeatTimer = null;
    _framing = FramingMode.none;
    // 清理所有消息确认 Timer 及待确认消息 ID（两者生命周期绑定同一连接）
    for (final t in _confirmationTimers) {
      t.cancel();
    }
    _confirmationTimers.clear();
    _pendingMessages.clear();
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 获取WebSocket URL
  /// Get WebSocket URL
  String? getWebSocketUrl() {
    return Env.effectiveWsUrl;
  }

  /// 获取消息队列大小
  /// Get message queue size
  int getMessageQueueSize() {
    return _messageQueue.messages.length;
  }

  /// 获取待确认消息数量
  /// Get pending message count
  int getPendingMessageCount() {
    return _pendingMessages.length;
  }

  /// 获取连接统计信息
  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'status': _status.name,
      'message_queue_size': _messageQueue.messages.length,
      'pending_messages': _pendingMessages.length,
      'connection_attempts': _backoff.attempts,
      'is_flushing': _isFlushing,
      'current_url': getWebSocketUrl(),
    };
  }

  /// 获取待确认消息列表（用于调试）
  /// Get pending messages list (for debugging)
  List<String> getPendingMessages() {
    return List<String>.from(_pendingMessages);
  }

  /// 清理过期的待确认消息
  /// Clean up expired pending messages
  void cleanupExpiredPendingMessages() {
    if (_pendingMessages.isNotEmpty) {
      iPrint('> ws: 清理过期的待确认消息，当前数量: ${_pendingMessages.length}');
      _pendingMessages.clear();
      iPrint('> ws: 已清理所有待确认消息');
    }
  }
}
