import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';

import 'live_room_state.dart';

class LiveRoomLogic extends getx.GetxController {
  final LiveRoomState state = LiveRoomState();
}

class SfuWsSample {
  late MediaStream _stream;
  late RTCPeerConnection _pc;
  late RTCDataChannel _dc;
  dynamic onLocalStream;
  dynamic onRemoteStream;
  dynamic onOpen;
  dynamic onClose;
  dynamic onError;

  SfuWsSample();

  bool _inCalling = false;

  bool get inCalling => _inCalling;

  Map<String, dynamic> configuration = iceConfiguration!;

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  /*
  Future<void> connect(String host) async {
    // if (_socket != null) {
    //   iPrint('Already connected!');
    //   return;
    // }

    try {
      Random r = new Random();
      String key = base64.encode(List<int>.generate(8, (_) => r.nextInt(255)));
      SecurityContext securityContext = new SecurityContext();
      HttpClient client = HttpClient(context: securityContext);
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        iPrint('Allow self-signed certificate => $host:$port.');
        return true;
      };
      HttpClientRequest request = await client.getUrl(
          Uri.parse('https://$host:8443/ws')); // form the correct url here
      request.headers.add('Connection', 'Upgrade');
      request.headers.add('Upgrade', 'websocket');
      request.headers.add(
          'Sec-WebSocket-Version', '13'); // insert the correct version here
      request.headers.add('Sec-WebSocket-Key', key.toLowerCase());

      HttpClientResponse response = await request.close();
      Socket socket = await response.detachSocket();
      _socket = WebSocket.fromUpgradedSocket(
        socket,
        protocol: 'pions-flutter',
        serverSide: false,
      );
      _socket.listen((data) {
        iPrint('Recivied data: ' + data);
        _onMessage(data);
      }, onDone: () {
        iPrint('Closed by server!');
        if (this.onClose != null) this.onClose();
        _socket = null;
      });
      if (this.onOpen != null) this.onOpen();
      return;
    } catch (e) {
      iPrint(e.toString());
      if (this.onError != null) this.onError(e.toString());
      _socket = null;
      return;
    }
  }
  */
  void _send(String data) {
    // if (_socket != null) _socket.add(data);
    iPrint('send: ' + data);
  }

  void _onMessage(data) {
    if (_pc == null) return;
    _pc.setRemoteDescription(new RTCSessionDescription(data, 'answer'));
  }

  void createPublisher() async {
    if (_inCalling) {
      return;
    }
    final Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth":
              '1280', // Provide your own width, height and frame rate here
          "minHeight": '720',
          "minFrameRate": '60',
        },
        "facingMode": "user",
        "optional": [],
      }
    };
    // _stream = await navigator.getUserMedia(mediaConstraints);
    _stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    if (this.onLocalStream != null) this.onLocalStream(_stream);
    iPrint("iceConfiguration ${configuration.toString()}");
    _pc = await createPeerConnection(configuration, _config);
    _dc = await _pc.createDataChannel('data', RTCDataChannelInit());
    _pc.onIceGatheringState = (state) async {
      iPrint('onIceGatheringState ');
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        iPrint('RTCIceGatheringStateComplete');
        RTCSessionDescription? sdp = await _pc.getLocalDescription();
        if (sdp != null && sdp.sdp != null) {
          _send(sdp!.sdp!);
        }
      }
    };
    // https://stackoverflow.com/questions/74873986/flutter-webrtc-rtcpeerconnection-addstream-not-working
    // _pc.addStream(_stream);
    _stream.getTracks().forEach((track) {
      _pc?.addTrack(track, _stream);
    });

    RTCSessionDescription description = await _pc.createOffer(_constraints);
    iPrint('Publisher createOffer');
    _pc.setLocalDescription(description);
    _inCalling = true;
  }

  void createSubscriber() async {
    if (_inCalling) {
      return;
    }

    _pc = await createPeerConnection(configuration, _config);
    _dc = await _pc.createDataChannel('data', RTCDataChannelInit());

    _pc.onIceGatheringState = (state) async {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        iPrint('RTCIceGatheringStateComplete');
        RTCSessionDescription? sdp = await _pc.getLocalDescription();
        if (sdp != null && sdp.sdp != null) {
          _send(sdp!.sdp!);
        }
      }
    };

    _pc.onAddStream = (stream) {
      iPrint('Got remote stream => ' + stream.id);
      _stream = stream;
      if (this.onRemoteStream != null) this.onRemoteStream(stream);
    };

    RTCSessionDescription description = await _pc.createOffer(_constraints);
    iPrint('Subscriber createOffer');
    _pc.setLocalDescription(description);
    _inCalling = true;
  }

  void close() async {
    if (_stream != null) await _stream.dispose();
    if (_pc != null) await _pc.close();
    // if (_socket != null) {
    //   await _socket.close();
    //   _socket = null;
    // }
  }
}
