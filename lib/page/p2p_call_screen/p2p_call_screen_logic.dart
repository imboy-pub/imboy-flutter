import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/counter.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/signaling.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class P2pCallScreenLogic extends GetxController {
  WebRTCSignaling signaling = Get.find<WebRTCSignaling>(tag: 'p2psignaling');

  // bool callee = false;
  var connected = false.obs;
  var showTool = true.obs;

  // 最小化的
  var minimized = false.obs;
  var stateTips = "".obs;

  var switchRenderer = true.obs;
  // late Rx<RTCVideoRenderer> localRenderer;
  // late Rx<RTCVideoRenderer> remoteRenderer;
  Rx<RTCVideoRenderer> localRenderer = RTCVideoRenderer().obs;
  Rx<RTCVideoRenderer> remoteRenderer = RTCVideoRenderer().obs;

  var cameraOff = false.obs;
  var microphoneOff = false.obs;
  var speakerOn = true.obs;
  //
  Rx<double> localX = 0.0.obs;
  Rx<double> localY = 0.0.obs;

  // 计时器
  Rx<Counter> counter = Counter(count: 0).obs;
  Rx<String> sessionid = "".obs;

  // LocalStream? localStream;

  @override
  @mustCallSuper
  void onInit() async {
    super.onInit();
    initRenderers();

    invitePeer(signaling.to, signaling.media);
    // 接收到新的消息订阅
    eventBus
        .on<WebRTCSignalingModel>()
        .listen((WebRTCSignalingModel obj) async {
      // ignore: prefer_interpolation_to_compose_strings
      debugPrint("> rtc listen: " + obj.toJson().toString());
      onMessage(obj);
    });

    signaling.onSignalingStateChange = (RTCSignalingState state) {
      debugPrint("> rtc onSignalingStateChange logic ${state.toString()}");
      if (state == RTCSignalingState.RTCSignalingStateStable) {
        // counter.value.count = 0;
        // counter.value.start((Timer tm) {
        //   if (connected.isTrue) {
        //     // 秒数+1，因为一秒回调一次
        //     counter.value.count += 1;
        //     // 更新界面
        //     stateTips.value = counter.value.show();
        //     // update([
        //     //   stateTips.value = counter.value.show(),
        //     // ]);
        //   }
        // });
      } else if (state == RTCSignalingState.RTCSignalingStateClosed) {
        cleanUp();
      } else if (state == RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        //
      } else if (state == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        // accept(sessionid.value, 'video');
      }
    };

    signaling.onPeersUpdate = ((event) {
      debugPrint("> rtc _connect onPeersUpdate");
      // setState(() {
      //   peers = event['peers'];
      // });
    });

    signaling.onLocalStream = ((stream) async {
      debugPrint("> rtc onLocalStream");
      if (localRenderer.value.textureId == null) {
        localRenderer.value.initialize();
      }
      localRenderer.value.setSrcObject(stream: stream);
      localRenderer.refresh();
    });

    signaling.onAddRemoteStream = ((WebRTCSession sess, stream) async {
      debugPrint("> rtc onAddRemoteStream ${stream.toString()} , ${sess.sid}");
      sessionid.value = sess.sid;
      sessionid.refresh();
      if (remoteRenderer.value.textureId == null) {
        remoteRenderer.value.initialize();
      }
      remoteRenderer.value.setSrcObject(stream: stream);
      remoteRenderer.refresh();
    });

    signaling.onRemoveRemoteStream = ((WebRTCSession sess, stream) {
      debugPrint("> rtc _connect onRemoveRemoteStream , ${sess.sid}");
      sessionid.value = sess.sid;
      sessionid.refresh();
      remoteRenderer.value.srcObject = null;
      remoteRenderer.refresh();
    });
  }

  // 设置Renderers
  initRenderers() async {
    await localRenderer.value.initialize();
    localRenderer.refresh();
    await remoteRenderer.value.initialize();
    remoteRenderer.refresh();
  }

  void onMessage(WebRTCSignalingModel msg) async {
    var data = msg.payload;

    debugPrint("> rtc s onMessage ${msg.webrtctype}: ${data.toString()}");
    switch (msg.webrtctype) {
      case 'offer': // 收到from 发送的 offer
        {
          // sd = session description
          var description = data['sd'];
          var media = data['media'];
          var sessionId = data['sid'];
          var session = signaling.sessions[sessionId];

          var newSession = await signaling.createSession(session,
              peerId: signaling.to,
              sessionId: sessionId,
              media: media,
              screenSharing: false);
          signaling.sessions[sessionId] = newSession;
          await newSession.pc?.setRemoteDescription(RTCSessionDescription(
            description['sdp'],
            description['type'],
          ));

          await signaling.createAnswer(newSession, media);
          if (newSession.remoteCandidates.isNotEmpty) {
            for (var candidate in newSession.remoteCandidates) {
              await newSession.pc?.addCandidate(candidate);
            }
            newSession.remoteCandidates.clear();
          }
          // onCallStateChange?.call(newSession, WebRTCCallState.CallStateNew);
          signaling.onCallStateChange
              ?.call(newSession, WebRTCCallState.CallStateRinging);
        }
        break;
      case 'answer':
        {
          // sd = session description
          var description = data['sd'];
          var sessionId = data['sid'];
          var session = signaling.sessions[sessionId];
          debugPrint(
              "> rtc answer sid $sessionId; ${session.toString()}, pc ${session?.pc.toString()}; desc type: ${description['type']}");
          if (session != null) {
            session.pc?.setRemoteDescription(
                RTCSessionDescription(description['sdp'], description['type']));
            signaling.onCallStateChange?.call(
              session,
              WebRTCCallState.CallStateConnected,
            );
            // await session.pc
            //     ?.setRemoteDescription(RTCSessionDescription(
            //   description['sdp'],
            //   description['type'],
            // ))
            //     .then((value) {
            //   onCallStateChange?.call(
            //     session,
            //     WebRTCCallState.CallStateConnected,
            //   );
            // });
          }
        }
        break;
      case 'candidate':
        {
          var peerId = msg.from;
          var candidateMap = data['candidate'];
          var sessionId = data['sid'];
          var session = signaling.sessions[sessionId];
          RTCIceCandidate candidate = RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          );

          debugPrint(
              "> rtc candidate sessionId $sessionId, peerid $peerId, s ${session.toString()}");
          if (session != null) {
            debugPrint(
                "> rtc candidate sessionId $sessionId, peerid $peerId, s.pc ${session.pc.toString()}");
            if (session.pc != null) {
              await session.pc?.addCandidate(candidate);
            } else {
              session.remoteCandidates.add(candidate);
            }
          } else {
            signaling.sessions[sessionId] = WebRTCSession(
              pid: peerId,
              sid: sessionId,
            )..remoteCandidates.add(candidate);
          }
        }
        break;
      case 'leave':
        {
          var peerId = msg.from;
          signaling.closeSessionByPeerId(peerId);
        }
        break;
      case 'bye':
        {
          var sessionId = data['sid'];
          var session = signaling.sessions.remove(sessionId);
          debugPrint("> rtc bye $sessionId : $session");
          if (session != null) {
            signaling.onCallStateChange
                ?.call(session, WebRTCCallState.CallStateBye);
            signaling.closeSession(session);
          }
        }
        break;
      case 'keepalive':
        {
          debugPrint('keepalive response!');
        }
        break;
      default:
        break;
    }
  }

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
    counter.value.close();
    counter.refresh();
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

  accept(String sid, String media) async {
    debugPrint("> rtc accept $sid ${signaling.remoteStreams.length}");
    if (strEmpty(sid)) {
      return;
    }
    await signaling.accept(sid, media);
    if (signaling.remoteStreams.isNotEmpty) {
      remoteRenderer.value.setSrcObject(
        stream: signaling.remoteStreams.first,
      );
      remoteRenderer.refresh();
      connected = true.obs;
      connected.refresh();
      // localRenderer 右上角
      localX.value = Get.width - 90;
      localY.value = 30;
      localX.refresh();
      localY.refresh();
    }
  }

  /// 切换工具栏
  void switchTools() {
    update([
      showTool.value = !showTool.value,
    ]);
  }

  @override
  void onClose() {
    cleanUp();
    super.onClose();
  }
}
