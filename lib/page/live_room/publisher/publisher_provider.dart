import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'publisher_provider.g.dart';

/// Publisher 页面状态
class PublisherState {
  final String stateStr;
  final String serverUrl;
  final bool isConnecting;
  final SharedPreferences? preferences;

  const PublisherState({
    this.stateStr = 'init',
    this.serverUrl = 'http://192.168.0.144:9010/whip/publish/live/stream1',
    this.isConnecting = false,
    this.preferences,
  });

  PublisherState copyWith({
    String? stateStr,
    String? serverUrl,
    bool? isConnecting,
    SharedPreferences? preferences,
  }) {
    return PublisherState(
      stateStr: stateStr ?? this.stateStr,
      serverUrl: serverUrl ?? this.serverUrl,
      isConnecting: isConnecting ?? this.isConnecting,
      preferences: preferences ?? this.preferences,
    );
  }
}

/// Publisher Provider
@riverpod
class PublisherNotifier extends _$PublisherNotifier {
  @override
  PublisherState build() {
    _loadSettings();
    return const PublisherState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url =
        prefs.getString('pushServer') ??
        'http://192.168.0.144:9010/whip/publish/live/stream1';
    state = state.copyWith(serverUrl: url, preferences: prefs);
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = state.preferences ?? await SharedPreferences.getInstance();
    await prefs.setString('pushServer', url);
    state = state.copyWith(serverUrl: url, preferences: prefs);
  }

  void updateState(String newState) {
    state = state.copyWith(stateStr: newState);
  }

  void setConnecting(bool connecting) {
    state = state.copyWith(isConnecting: connecting);
  }
}
