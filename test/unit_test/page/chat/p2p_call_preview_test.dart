/// LK-APP-02：接通前本地预览（响铃等待期自视图）单测
///
/// 验收点：
///   - startLocalPreview 成功 → localPreviewReady=true，previewTrack 非空
///   - connect() 前预览轨已被停掉（避免与 Room 相机采集抢设备）
///   - 预览创建失败（权限/设备）→ errorMessage + camera permissionTarget，
///     且不影响信令流程（joinRoom 照常）
///   - 接通前 turnCamera：无 Room 时直接开/关预览轨
///   - releaseMedia（挂断释放）会停预览轨
///   - 音频通话不创建预览
///
/// 相机轨通过 previewTrackFactory 注入 noSuchMethod 替身，单测不触碰
/// 平台相机通道。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/webrtc/media_permission.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/rtc_room_api.dart';

/// noSuchMethod 替身：仅记录 stop 调用，其余成员一律 no-op。
class _FakeVideoTrackImpl implements VideoTrack {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakePreviewTrack implements LocalPreviewTrack {
  int stopCalls = 0;

  @override
  VideoTrack? get videoTrack => _FakeVideoTrackImpl();

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> setCameraPosition(CameraPosition position) async {}
}

class _FakeRtcRoomApi extends RtcRoomApi {
  int joinCalls = 0;

  @override
  Future<Map<String, String>?> joinRoom({
    required String kind,
    required String targetId,
    String? did,
  }) async {
    joinCalls++;
    return const {
      'wsUrl': 'wss://rtc.example.com/room',
      'token': 'fake-jwt',
      'roomName': 'c2c_117_52278',
    };
  }
}

void main() {
  const peerId = '52278';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  ProviderContainer setupContainer(
    _FakeRtcRoomApi api, {
    String media = 'video',
  }) {
    final container = ProviderContainer();
    // 持有监听：p2pCallScreenProvider 是 autoDispose，无监听时会在
    // await 间隙被回收，断言将读到重建后的全新状态。
    container.listen(p2pCallScreenProvider, (_, _) {});
    final notifier = container.read(p2pCallScreenProvider.notifier);
    notifier.rtcApiOverride = api;
    notifier.roomConnectOverride = (wsUrl, token) async => true;
    notifier.initSession(
      newSession: WebRTCSession(peerId: peerId, sid: '117-$peerId'),
      newMedia: media,
      isCaller: true,
      newMsgId: 'mid-lk-pv-1',
    );
    return container;
  }

  test('localPreviewReady copyWith 契约', () {
    const s = P2pCallScreenState();
    expect(s.localPreviewReady, isFalse);
    expect(s.copyWith().localPreviewReady, isFalse);
    expect(s.copyWith(localPreviewReady: true).localPreviewReady, isTrue);
  });

  test('音频通话不创建预览', () async {
    final api = _FakeRtcRoomApi();
    final container = setupContainer(api, media: 'audio');
    addTearDown(container.dispose);

    final notifier = container.read(p2pCallScreenProvider.notifier);
    var factoryCalls = 0;
    notifier.previewTrackFactory = (options) async {
      factoryCalls++;
      return _FakePreviewTrack();
    };

    notifier.startLocalPreview();
    await pumpEventQueue();

    expect(factoryCalls, 0, reason: '音频通话无摄像头，不得创建预览轨');
    expect(notifier.previewTrack, isNull);
    expect(container.read(p2pCallScreenProvider).localPreviewReady, isFalse);
  });

  test('startLocalPreview 成功 → localPreviewReady，轨道可取', () async {
    final api = _FakeRtcRoomApi();
    final container = setupContainer(api);
    addTearDown(container.dispose);

    final notifier = container.read(p2pCallScreenProvider.notifier);
    final preview = _FakePreviewTrack();
    notifier.previewTrackFactory = (options) async => preview;

    notifier.startLocalPreview();
    await pumpEventQueue();

    expect(container.read(p2pCallScreenProvider).localPreviewReady, isTrue);
    expect(notifier.previewTrack, same(preview));

    await notifier.stopLocalPreview();
    expect(preview.stopCalls, 1);
    expect(notifier.previewTrack, isNull);
    expect(container.read(p2pCallScreenProvider).localPreviewReady, isFalse);
  });

  test('connect() 前预览轨已停（避免与 Room 相机采集抢设备）', () async {
    final api = _FakeRtcRoomApi();
    final container = setupContainer(api);
    addTearDown(container.dispose);

    final notifier = container.read(p2pCallScreenProvider.notifier);
    final preview = _FakePreviewTrack();
    notifier.previewTrackFactory = (options) async => preview;
    notifier.startLocalPreview();
    await pumpEventQueue();
    expect(notifier.previewTrack, isNotNull);

    final ok = await notifier.connect(peerId: peerId);

    expect(ok, isTrue);
    expect(api.joinCalls, 1);
    expect(preview.stopCalls, 1, reason: 'connect 必须先停房外预览轨');
    expect(notifier.previewTrack, isNull);
  });

  test('预览创建失败 → 错误提示 + camera 权限目标，信令不受影响', () async {
    final api = _FakeRtcRoomApi();
    final container = setupContainer(api);
    addTearDown(container.dispose);

    final notifier = container.read(p2pCallScreenProvider.notifier);
    notifier.previewTrackFactory = (options) async => throw Exception('denied');

    notifier.startLocalPreview();
    await notifier.stopLocalPreview();

    final s = container.read(p2pCallScreenProvider);
    expect(s.localPreviewReady, isFalse);
    expect(s.errorMessage, isNotEmpty);
    expect(s.permissionTarget, MediaPermissionTarget.camera);

    // 预览失败不判死通话：joinRoom 照常
    final ok = await notifier.connect(peerId: peerId);
    expect(ok, isTrue);
    expect(api.joinCalls, 1);
  });

  test('接通前 turnCamera：无 Room 时直接开/关预览轨', () async {
    final api = _FakeRtcRoomApi();
    final container = setupContainer(api);
    addTearDown(container.dispose);

    final notifier = container.read(p2pCallScreenProvider.notifier);
    final preview = _FakePreviewTrack();
    notifier.previewTrackFactory = (options) async => preview;

    // 关
    await notifier.turnCamera();
    expect(container.read(p2pCallScreenProvider).cameraOff, isTrue);
    expect(notifier.previewTrack, isNull);

    // 开
    await notifier.turnCamera();
    expect(container.read(p2pCallScreenProvider).cameraOff, isFalse);
    await pumpEventQueue();
    expect(notifier.previewTrack, isNotNull);
  });

  test('releaseMedia（挂断释放）会停预览轨', () async {
    final api = _FakeRtcRoomApi();
    final container = setupContainer(api);
    addTearDown(container.dispose);

    final notifier = container.read(p2pCallScreenProvider.notifier);
    final preview = _FakePreviewTrack();
    notifier.previewTrackFactory = (options) async => preview;
    notifier.startLocalPreview();
    await pumpEventQueue();
    expect(notifier.previewTrack, isNotNull);

    await notifier.releaseMedia();

    expect(preview.stopCalls, 1);
    expect(notifier.previewTrack, isNull);
    expect(container.read(p2pCallScreenProvider).localPreviewReady, isFalse);
  });
}
