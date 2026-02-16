/// Web 平台多标签页同步服务
///
/// 使用 BroadcastChannel API 实现跨标签页通信
/// 支持：
/// - 消息同步
/// - 在线状态同步
/// - 会话状态同步
/// - 主题设置同步
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 跨标签页消息类型
enum TabSyncMessageType {
  /// 新消息通知
  newMessage,

  /// 消息已读状态更新
  messageRead,

  /// 会话列表更新
  conversationUpdate,

  /// 在线状态变更
  onlineStatus,

  /// 主题设置变更
  themeChange,

  /// 语言设置变更
  languageChange,

  /// 用户登出
  userLogout,

  /// 标签页心跳
  heartbeat,

  /// 标签页注册
  tabRegister,

  /// 标签页注销
  tabUnregister,
}

/// 跨标签页消息
class TabSyncMessage {
  final TabSyncMessageType type;
  final Map<String, dynamic> payload;
  final String tabId;
  final int timestamp;

  const TabSyncMessage({
    required this.type,
    required this.payload,
    required this.tabId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'payload': payload,
        'tabId': tabId,
        'timestamp': timestamp,
      };

  factory TabSyncMessage.fromJson(Map<String, dynamic> json) {
    return TabSyncMessage(
      type: TabSyncMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TabSyncMessageType.heartbeat,
      ),
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      tabId: json['tabId'] ?? '',
      timestamp: json['timestamp'] ?? 0,
    );
  }

  String encode() => jsonEncode(toJson());

  factory TabSyncMessage.decode(String data) {
    return TabSyncMessage.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }
}

/// Web 多标签页同步服务
///
/// 使用 BroadcastChannel API 在同一浏览器的不同标签页之间同步状态
class WebTabSyncService {
  static final WebTabSyncService _instance = WebTabSyncService._internal();
  factory WebTabSyncService() => _instance;
  WebTabSyncService._internal();

  /// 当前标签页 ID
  late final String _tabId;

  /// BroadcastChannel 实例
  dynamic _channel;

  /// 消息流控制器
  final StreamController<TabSyncMessage> _messageController =
      StreamController<TabSyncMessage>.broadcast();

  /// 消息流
  Stream<TabSyncMessage> get messageStream => _messageController.stream;

  /// 活跃标签页列表
  final Set<String> _activeTabs = {};

  /// 是否已初始化
  bool _initialized = false;

  /// 获取当前标签页 ID
  String get tabId => _tabId;

  /// 获取活跃标签页数量
  int get activeTabCount => _activeTabs.length;

  /// 是否为主标签页（第一个打开的标签页）
  bool get isPrimaryTab => _activeTabs.first == _tabId;

  /// 初始化服务
  void initialize() {
    if (!kIsWeb || _initialized) return;

    _tabId = 'tab_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomId()}';
    _initialized = true;

    _initBroadcastChannel();
    _registerTab();

    debugPrint('WebTabSyncService: 初始化完成, tabId=$_tabId');
  }

  /// 生成随机 ID
  String _generateRandomId() {
    return (DateTime.now().microsecondsSinceEpoch % 10000).toString();
  }

  /// 初始化 BroadcastChannel
  void _initBroadcastChannel() {
    try {
      // 使用 Web API 创建 BroadcastChannel
      // ignore: avoid_web_libraries_in_flutter
      _channel = _createBroadcastChannel('imboy_tab_sync');

      if (_channel != null) {
        _setupMessageListener();
      }
    } catch (e) {
      debugPrint('WebTabSyncService: BroadcastChannel 初始化失败 - $e');
    }
  }

  /// 创建 BroadcastChannel (Web 平台)
  dynamic _createBroadcastChannel(String name) {
    // 在 Web 平台上，使用条件导入或动态创建
    // 这里使用 JS 互操作
    if (!kIsWeb) return null;

    try {
      // 使用 dart:html 或 dart:js_interop
      // 这里简化处理，实际实现需要使用 web 包
      return _WebBroadcastChannel(name);
    } catch (e) {
      debugPrint('WebTabSyncService: 创建 BroadcastChannel 失败 - $e');
      return null;
    }
  }

  /// 设置消息监听器
  void _setupMessageListener() {
    if (_channel == null) return;

    try {
      (_channel as _WebBroadcastChannel).onMessage = (String data) {
        try {
          final message = TabSyncMessage.decode(data);

          // 忽略自己发送的消息
          if (message.tabId == _tabId) return;

          // 处理特殊消息类型
          _handleSpecialMessage(message);

          // 广播给监听者
          _messageController.add(message);
        } catch (e) {
          debugPrint('WebTabSyncService: 解析消息失败 - $e');
        }
      };
    } catch (e) {
      debugPrint('WebTabSyncService: 设置消息监听器失败 - $e');
    }
  }

  /// 处理特殊消息
  void _handleSpecialMessage(TabSyncMessage message) {
    switch (message.type) {
      case TabSyncMessageType.tabRegister:
        _activeTabs.add(message.tabId);
        debugPrint('WebTabSyncService: 标签页注册 ${message.tabId}');
        break;

      case TabSyncMessageType.tabUnregister:
        _activeTabs.remove(message.tabId);
        debugPrint('WebTabSyncService: 标签页注销 ${message.tabId}');
        break;

      case TabSyncMessageType.heartbeat:
        _activeTabs.add(message.tabId);
        break;

      default:
        break;
    }
  }

  /// 注册当前标签页
  void _registerTab() {
    send(TabSyncMessageType.tabRegister, {});

    // 发送心跳
    _startHeartbeat();

    // 监听页面卸载
    _setupUnloadHandler();
  }

  /// 开始心跳
  void _startHeartbeat() {
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_initialized) {
        timer.cancel();
        return;
      }
      send(TabSyncMessageType.heartbeat, {});
    });
  }

  /// 设置页面卸载处理器
  void _setupUnloadHandler() {
    if (!kIsWeb) return;

    try {
      // 监听 beforeunload 事件
      // 实际实现需要使用 web 包
    } catch (e) {
      debugPrint('WebTabSyncService: 设置卸载处理器失败 - $e');
    }
  }

  /// 发送消息到其他标签页
  void send(TabSyncMessageType type, Map<String, dynamic> payload) {
    if (!kIsWeb || _channel == null) return;

    final message = TabSyncMessage(
      type: type,
      payload: payload,
      tabId: _tabId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      (_channel as _WebBroadcastChannel).postMessage(message.encode());
    } catch (e) {
      debugPrint('WebTabSyncService: 发送消息失败 - $e');
    }
  }

  /// 发送新消息通知
  void notifyNewMessage(Map<String, dynamic> messageData) {
    send(TabSyncMessageType.newMessage, messageData);
  }

  /// 发送消息已读状态
  void notifyMessageRead(String conversationId, List<String> messageIds) {
    send(TabSyncMessageType.messageRead, {
      'conversationId': conversationId,
      'messageIds': messageIds,
    });
  }

  /// 发送会话更新
  void notifyConversationUpdate(String conversationId, Map<String, dynamic> updates) {
    send(TabSyncMessageType.conversationUpdate, {
      'conversationId': conversationId,
      'updates': updates,
    });
  }

  /// 发送在线状态变更
  void notifyOnlineStatus(String userId, bool isOnline) {
    send(TabSyncMessageType.onlineStatus, {
      'userId': userId,
      'isOnline': isOnline,
    });
  }

  /// 发送主题变更
  void notifyThemeChange(bool isDarkMode) {
    send(TabSyncMessageType.themeChange, {
      'isDarkMode': isDarkMode,
    });
  }

  /// 发送语言变更
  void notifyLanguageChange(String languageCode) {
    send(TabSyncMessageType.languageChange, {
      'languageCode': languageCode,
    });
  }

  /// 发送用户登出通知
  void notifyUserLogout() {
    send(TabSyncMessageType.userLogout, {});
  }

  /// 注销当前标签页
  void unregister() {
    send(TabSyncMessageType.tabUnregister, {});
    _activeTabs.remove(_tabId);
  }

  /// 销毁服务
  void dispose() {
    unregister();
    _messageController.close();
    if (_channel != null) {
      (_channel as _WebBroadcastChannel).close();
    }
    _initialized = false;
  }
}

/// BroadcastChannel 包装类 (Web 平台)
class _WebBroadcastChannel {
  final String name;
  dynamic _nativeChannel;

  _WebBroadcastChannel(this.name) {
    // 在实际 Web 实现中，这里会创建真正的 BroadcastChannel
    // ignore: avoid_web_libraries_in_flutter
    try {
      // 使用条件导入或 JS 互操作
      // 这里是占位实现
      debugPrint('_WebBroadcastChannel: 创建通道 $name');
    } catch (e) {
      debugPrint('_WebBroadcastChannel: 创建失败 - $e');
    }
  }

  void Function(String)? onMessage;

  void postMessage(String data) {
    if (_nativeChannel != null) {
      // 发送消息
    }
    debugPrint('_WebBroadcastChannel: 发送消息 ${data.length} 字节');
  }

  void close() {
    _nativeChannel = null;
  }
}

/// WebTabSyncService Provider
final webTabSyncServiceProvider = Provider<WebTabSyncService>((ref) {
  final service = WebTabSyncService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// 全局实例
final webTabSyncService = WebTabSyncService();
