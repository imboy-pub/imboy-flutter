import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/signaling.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class P2pCallScreenLogic extends GetxController {
  WebRTCSignaling signaling = Get.find(tag: 'p2psignaling');

  // bool callee = false;
  var connected = false.obs;
  var showTool = true.obs;

  // 最小化的
  var minimized = false.obs;
  var stateTips = "".obs;

  var switchRenderer = true.obs;
  late Rx<RTCVideoRenderer> localRenderer;
  late Rx<RTCVideoRenderer> remoteRenderer;
  // Rx<RTCVideoRenderer> localRenderer = RTCVideoRenderer().obs;
  // Rx<RTCVideoRenderer> remoteRenderer = RTCVideoRenderer().obs;

  var cameraOff = false.obs;
  var microphoneOff = false.obs;
  var speakerOn = true.obs;
  //
  Rx<double> localX = 0.0.obs;
  Rx<double> localY = 0.0.obs;

  // LocalStream? localStream;

  @override
  @mustCallSuper
  void onInit() async {
    super.onInit();

    // 接收到新的消息订阅
    eventBus
        .on<WebRTCSignalingModel>()
        .listen((WebRTCSignalingModel obj) async {
      // ignore: prefer_interpolation_to_compose_strings
      debugPrint(">>> on rtc listen: " + obj.toJson().toString());
      signaling.onMessage(obj);
    });
  }

  /// 设置Renderers
  initRenderers() {
    localRenderer = RTCVideoRenderer().obs;
    remoteRenderer = RTCVideoRenderer().obs;
  }

  // initRenderers() async {
  //   await localRenderer.value.initialize();
  //   await remoteRenderer.value.initialize();
  // }

  /// 切换本地相机
  /// Switch local camera
  switchCamera() {
    signaling.switchCamera();
  }

  /// 开关扬声器/耳机
  /// Switch speaker/earpiece
  switchSpeaker() {
    if (signaling.localStream != null) {
      speakerOn.value = !speakerOn.value;
      MediaStreamTrack audioTrack = signaling.localStream!.getAudioTracks()[0];
      audioTrack.enableSpeakerphone(speakerOn.value);
      _debug(
          ":::Switch to " + (speakerOn.value ? "speaker" : "earpiece") + ":::");
    }
  }

  /// 打开或关闭本地视频
  /// Open or close local video
  turnCamera() {
    if (signaling.localStream!.getVideoTracks().isNotEmpty) {
      var muted = !cameraOff.value;
      cameraOff.value = muted;
      signaling.localStream!.getVideoTracks()[0].enabled = !muted;
    } else {
      _debug(":::Unable to operate the camera:::");
    }
  }

  /// 打开或关闭本地麦克风
  /// Open or close local microphone
  turnMicrophone() {
    debugPrint("> rtc turnMicrophone");
    if (signaling.localStream!.getAudioTracks().isNotEmpty) {
      var muted = !microphoneOff.value;
      microphoneOff.value = muted;
      signaling.localStream!.getAudioTracks()[0].enabled = !muted;
      _debug(":::The microphone is ${muted ? 'muted' : 'unmuted'}:::");
    } else {}
  }

  /// 退出之前清理打开的资源
  cleanUp() async {
    if (localRenderer.value.srcObject != null) {
      localRenderer.value.srcObject = null;
      await localRenderer.value.dispose();
      localRenderer.refresh();
    }
    if (remoteRenderer.value.srcObject != null) {
      remoteRenderer.value.srcObject = null;
      await remoteRenderer.value.dispose();
      remoteRenderer.refresh();
    }
    await signaling.close();
    Get.delete<WebRTCSignaling>(force: true);

    connected = false.obs;
    connected.refresh();
    refresh();
  }

  _debug(String message) {
    debugPrint(message);
  }

  hangUp() {
    // if (signaling.value != null) {
    //   bye(session.value!.sid);
    // }
    Get.dialog(AlertDialog(
        title: const Text("Hangup"),
        content: const Text("Are you sure to leave the room?"),
        actions: <Widget>[
          TextButton(
            child: const Text("Cancel"),
            onPressed: () {
              Get.back();
            },
          ),
          TextButton(
            child: const Text(
              "Hangup",
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () {
              // Get.toNamed("/login");
              cleanUp();
            },
          )
        ]));
  }

  /// 邀请对端通话
  void invitePeer(String peerId, String media) async {
    debugPrint("> rtc invitePeer ${signaling.toString()} ");
    if (peerId != UserRepoLocal.to.currentUid) {
      signaling.invite(peerId, media);
    }
  }

  accept(String sid) async {
    if (strNoEmpty(sid)) {
      debugPrint("> rtc accept $sid");
      await signaling.accept(sid);

      if (signaling.remoteStreams.isNotEmpty) {
        await remoteRenderer.value.initialize();
        remoteRenderer.value.setSrcObject(
          stream: signaling.remoteStreams.first,
        );
        remoteRenderer.refresh();
      }
      connected = true.obs;
      connected.refresh();
      // localRenderer 右上角
      localX.value = Get.width - 90;
      localY.value = 30;
      localX.refresh();
      localY.refresh();
      // setState(() {
      //   localRenderer;
      //   remoteRenderer;
      //   // localRenderer 右上角
      //   localX = Get.width - 90;
      //   localY = 30;
      //   connected = true;
      // });
    }
  }

  /// 切换工具栏
  void switchTools() {
    update([
      showTool.value = !showTool.value,
    ]);
  }
}
