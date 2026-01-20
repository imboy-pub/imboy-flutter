import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'subscriber_provider.g.dart';

/// Subscriber 页面状态
class SubscriberState {
  final String stateStr;
  final String serverUrl;
  final bool isConnecting;
  final SharedPreferences? preferences;

  const SubscriberState({
    this.stateStr = 'init',
    this.serverUrl = 'https://192.168.0.144:9800/whip/subscribe/a1234/1',
    this.isConnecting = false,
    this.preferences,
  });

  SubscriberState copyWith({
    String? stateStr,
    String? serverUrl,
    bool? isConnecting,
    SharedPreferences? preferences,
  }) {
    return SubscriberState(
      stateStr: stateStr ?? this.stateStr,
      serverUrl: serverUrl ?? this.serverUrl,
      isConnecting: isConnecting ?? this.isConnecting,
      preferences: preferences ?? this.preferences,
    );
  }
}

/// Subscriber Provider
@riverpod
class SubscriberNotifier extends _$SubscriberNotifier {
  @override
  SubscriberState build() {
    _loadSettings();
    return const SubscriberState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url =
        prefs.getString('pullServer') ??
        'https://192.168.0.144:9800/whip/subscribe/a1234/1';
    state = state.copyWith(serverUrl: url, preferences: prefs);
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = state.preferences ?? await SharedPreferences.getInstance();
    await prefs.setString('pullServer', url);
    state = state.copyWith(serverUrl: url, preferences: prefs);
  }

  void updateState(String newState) {
    state = state.copyWith(stateStr: newState);
  }

  void setConnecting(bool connecting) {
    state = state.copyWith(isConnecting: connecting);
  }
}
