import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:imboy/component/webrtc/signaling.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class CallScreenPage extends StatefulWidget {
  static String tag = 'call_sample';
  final String to;
  final String title;
  final String avatar;
  final String sign;
  // final String host;

  const CallScreenPage({
    Key? key,
    required this.to,
    required this.title,
    required this.avatar,
    this.sign = "",
    // this.host,
  }) : super(key: key);

  @override
  _CallScreenPageState createState() => _CallScreenPageState();
}

class _CallScreenPageState extends State<CallScreenPage> {
  Signaling? _signaling;
  List<dynamic> _peers = [];
  String? _selfId;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  Session? _session;

  bool _waitAccept = false;

  // ignore: unused_element
  _CallScreenPageState();

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();

    // 接收到新的消息订阅
    eventBus.on<Map>().listen((Map data) async {
      debugPrint(">>> ws rtc CallScreenPage initState: " + data.toString());
      _signaling?.onMessage(data);
    });
    // _selfId = UserRepoLocal.to.currentUid;
    _invitePeer(context, widget.to, false);
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    if (_signaling != null) {
      _signaling?.close();
    }
  }

  void _connect() async {
    String host = "192.168.3.1";
    debugPrint(">>> ws rtc _connect 78");
    String from = UserRepoLocal.to.currentUid;
    _signaling ??= Signaling(host, from, widget.to)..connect();
    _signaling?.onSignalingStateChange = (SignalingState state) {
      debugPrint(
          ">>> ws rtc _connect onSignalingStateChange state ${state.toString()}");
      switch (state) {
        case SignalingState.ConnectionClosed:
        case SignalingState.ConnectionError:
        case SignalingState.ConnectionOpen:
          break;
      }
    };

    _signaling?.onCallStateChange = (Session session, CallState state) async {
      debugPrint(
          ">>> ws rtc _connect onCallStateChange state ${state.toString()}; session: ${session.sid} ${session.pid}");
      switch (state) {
        case CallState.CallStateNew:
          setState(() {
            _session = session;
          });
          break;
        case CallState.CallStateRinging:
          bool? accept = await _showAcceptDialog();
          if (accept!) {
            _accept();
            setState(() {
              _inCalling = true;
            });
          } else {
            _reject();
          }
          break;
        case CallState.CallStateBye:
          if (_waitAccept) {
            debugPrint('peer reject');
            _waitAccept = false;
            Navigator.of(context).pop(false);
          }
          setState(() {
            _localRenderer.srcObject = null;
            _remoteRenderer.srcObject = null;
            _inCalling = false;
            _session = null;
          });
          break;
        case CallState.CallStateInvite:
          _waitAccept = true;
          _showInvateDialog();
          break;
        case CallState.CallStateConnected:
          if (_waitAccept) {
            _waitAccept = false;
            Navigator.of(context).pop(false);
          }
          setState(() {
            _inCalling = true;
          });

          break;
        case CallState.CallStateRinging:
      }
    };

    _signaling?.onPeersUpdate = ((event) {
      debugPrint(">>> ws rtc _connect onPeersUpdate");
      setState(() {
        _selfId = event['self'];
        _peers = event['peers'];
      });
    });

    _signaling?.onLocalStream = ((stream) {
      debugPrint(">>> ws rtc _connect onLocalStream");
      _localRenderer.srcObject = stream;
      setState(() {});
    });

    _signaling?.onAddRemoteStream = ((_, stream) {
      debugPrint(">>> ws rtc _connect onAddRemoteStream");
      _remoteRenderer.srcObject = stream;
      setState(() {});
    });

    _signaling?.onRemoveRemoteStream = ((_, stream) {
      debugPrint(">>> ws rtc _connect onRemoveRemoteStream");
      _remoteRenderer.srcObject = null;
    });
  }

  Future<bool?> _showAcceptDialog() {
    return showDialog<bool?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("title"),
          content: const Text("accept?"),
          actions: <Widget>[
            TextButton(
              child: const Text("reject"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text("accept"),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showInvateDialog() {
    return showDialog<bool?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("title"),
          content: const Text("waiting"),
          actions: <Widget>[
            TextButton(
              child: const Text("cancel"),
              onPressed: () {
                Navigator.of(context).pop(false);
                _hangUp();
              },
            ),
          ],
        );
      },
    );
  }

  _invitePeer(BuildContext context, String peerId, bool useScreen) async {
    if (_signaling != null && peerId != _selfId) {
      // if (_signaling != null) {
      _signaling?.invite(peerId, 'video', useScreen);
    }
  }

  _accept() {
    if (_session != null) {
      _signaling?.accept(_session!.sid);
    }
  }

  _reject() {
    if (_session != null) {
      _signaling?.reject(_session!.sid);
    }
  }

  _hangUp() {
    if (_session != null) {
      _signaling?.bye(_session!.sid);
    }
  }

  _switchCamera() {
    _signaling?.switchCamera();
  }

  _muteMic() {
    _signaling?.muteMic();
  }

  _buildRow(context, peer) {
    var self = (peer['id'] == _selfId);
    return ListBody(children: <Widget>[
      ListTile(
        title: Text(self
            ? peer['name'] + ', ID: ${peer['id']} ' + ' [Your self]'
            : peer['name'] + ', ID: ${peer['id']} '),
        onTap: null,
        trailing: SizedBox(
            width: 100.0,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    icon: Icon(self ? Icons.close : Icons.videocam,
                        color: self ? Colors.grey : Colors.black),
                    onPressed: () => _invitePeer(context, peer['id'], false),
                    tooltip: 'Video calling',
                  ),
                  IconButton(
                    icon: Icon(self ? Icons.close : Icons.screen_share,
                        color: self ? Colors.grey : Colors.black),
                    onPressed: () => _invitePeer(context, peer['id'], true),
                    tooltip: 'Screen sharing',
                  )
                ])),
        subtitle: Text('[' + peer['user_agent'] + ']'),
      ),
      const Divider()
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('P2P Call ${widget.title}'),
        // actions: const <Widget>[
        //   IconButton(
        //     icon: Icon(Icons.settings),
        //     onPressed: null,
        //     tooltip: 'setup',
        //   ),
        // ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling
          ? SizedBox(
              width: 200.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  FloatingActionButton(
                    heroTag: "switch_camera",
                    child: const Icon(Icons.switch_camera),
                    onPressed: _switchCamera,
                  ),
                  FloatingActionButton(
                    heroTag: "call_end",
                    onPressed: _hangUp,
                    tooltip: 'Hangup',
                    child: const Icon(Icons.call_end),
                    backgroundColor: Colors.pink,
                  ),
                  FloatingActionButton(
                    heroTag: "mic_off",
                    child: const Icon(Icons.mic_off),
                    onPressed: _muteMic,
                  )
                ],
              ),
            )
          : null,
      body: _inCalling
          ? OrientationBuilder(
              builder: (context, orientation) {
                return Stack(
                  children: <Widget>[
                    Positioned(
                      left: 0.0,
                      right: 0.0,
                      top: 0.0,
                      bottom: 0.0,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                        width: Get.width,
                        height: Get.height,
                        child: RTCVideoView(_remoteRenderer),
                        decoration: const BoxDecoration(color: Colors.black54),
                      ),
                    ),
                    Positioned(
                      left: 20.0,
                      top: 20.0,
                      child: Container(
                        width:
                            orientation == Orientation.portrait ? 90.0 : 120.0,
                        height:
                            orientation == Orientation.portrait ? 120.0 : 90.0,
                        child: RTCVideoView(_localRenderer, mirror: true),
                        decoration: const BoxDecoration(color: Colors.black54),
                      ),
                    ),
                  ],
                );
              },
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(0.0),
              itemCount: (_peers != null ? _peers.length : 0),
              itemBuilder: (context, i) {
                return _buildRow(context, _peers[i]);
              },
            ),
    );
  }
}
