// import 'dart:core';
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:flutter_whip/flutter_whip.dart';
// import 'package:imboy/component/helper/func.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// // import 'publisher_logic.dart';
//
// // class PublisherPage extends StatelessWidget {
// class PublisherPage extends StatefulWidget {
//   static String tag = 'whip_publish_sample';
//
//   const PublisherPage({super.key});
//
//   @override
//   // ignore: library_private_types_in_public_api
//   _PublisherPageState createState() => _PublisherPageState();
// }
//
// class _PublisherPageState extends State<PublisherPage> {
//   MediaStream? _localStream;
//   final _localRenderer = RTCVideoRenderer();
//   String stateStr = 'init';
//   bool _connecting = false;
//   late WHIP _whip;
//
//   final TextEditingController _serverController = TextEditingController();
//   late SharedPreferences _preferences;
//
//   @override
//   void initState() {
//     super.initState();
//     initRenderers();
//     _loadSettings();
//   }
//
//   void _loadSettings() async {
//     _preferences = await SharedPreferences.getInstance();
//     setState(() {
//       // _serverController.text = _preferences.getString('pushServer') ??
//       //     'https://192.168.0.144:9800/whip/publish/a1234/1';
//
//       _serverController.text = _preferences.getString('pushServer') ??
//           'http://192.168.0.144:9010/whip/publish/live/stream1';
//     });
//   }
//
//   @override
//   void deactivate() {
//     super.deactivate();
//     if (_localRenderer.textureId != null) {
//       _localRenderer.srcObject = null;
//       _localRenderer.dispose();
//     }
//   }
//
//   void _saveSettings() {
//     _preferences.setString('pushServer', _serverController.text);
//   }
//
//   void initRenderers() async {
//     await _localRenderer.initialize();
//   }
//
//   // Platform messages are asynchronous, so we initialize in an async method.
//   void _connect() async {
//     final url = _serverController.text;
//
//     if (url.isEmpty) {
//       return;
//     }
//
//     _saveSettings();
//
//     _whip = WHIP(url: url);
//
//     _whip.onState = (WhipState state) {
//       setState(() {
//         switch (state) {
//           case WhipState.kNew:
//             stateStr = 'New';
//             break;
//           case WhipState.kInitialized:
//             stateStr = 'Initialized';
//             break;
//           case WhipState.kConnecting:
//             stateStr = 'Connecting';
//             break;
//           case WhipState.kConnected:
//             stateStr = 'Connected';
//             break;
//           case WhipState.kDisconnected:
//             stateStr = 'Closed';
//             break;
//           case WhipState.kFailure:
//             stateStr = 'Failure: \n${_whip.lastError.toString()}';
//             break;
//         }
//       });
//     };
//
//     final mediaConstraints = <String, dynamic>{
//       'audio': true,
//       'video': {
//         'mandatory': {
//           'minWidth': '1280',
//           'minHeight': '720',
//           'minFrameRate': '30',
//         },
//         'facingMode': 'user',
//         'optional': [],
//       }
//     };
//
//     try {
//       var stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
//       _localStream = stream;
//       _localRenderer.srcObject = _localStream;
//       await _whip.initlize(mode: WhipMode.kSend, stream: _localStream);
//       await _whip.connect();
//     } catch (e) {
//       iPrint('connect: error => ${e.toString()}');
//       _localRenderer.srcObject = null;
//       _localStream?.dispose();
//       return;
//     }
//     if (!mounted) return;
//
//     setState(() {
//       _connecting = true;
//     });
//   }
//
//   void _disconnect() async {
//     try {
//       if (kIsWeb) {
//         _localStream?.getTracks().forEach((track) => track.stop());
//       }
//       await _localStream?.dispose();
//       _localRenderer.srcObject = null;
//       _whip.close();
//       setState(() {
//         _connecting = false;
//       });
//     } catch (e) {
//       iPrint(e.toString());
//     }
//   }
//
//   void _toggleCamera() async {
//     if (_localStream == null) throw Exception('Stream is not initialized');
//     final videoTrack = _localStream!
//         .getVideoTracks()
//         .firstWhere((track) => track.kind == 'video');
//     await Helper.switchCamera(videoTrack);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar:
//           AppBar(title: const Text('WHIP Publisher Sample'), actions: <Widget>[
//         if (_connecting)
//           IconButton(
//             icon: const Icon(Icons.switch_video),
//             onPressed: _toggleCamera,
//           ),
//       ]),
//       body: OrientationBuilder(
//         builder: (context, orientation) {
//           return Column(children: <Widget>[
//             Column(children: <Widget>[
//               FittedBox(
//                 child: Text(
//                   stateStr,
//                   textAlign: TextAlign.left,
//                 ),
//               ),
//               if (!_connecting)
//                 const Padding(
//                   padding: EdgeInsets.fromLTRB(10.0, 18.0, 10.0, 0),
//                   child: Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text('WHIP URI:'),
//                   ),
//                 ),
//               if (!_connecting)
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 0),
//                   child: TextFormField(
//                     controller: _serverController,
//                     keyboardType: TextInputType.text,
//                     textAlign: TextAlign.center,
//                     decoration: const InputDecoration(
//                       contentPadding: EdgeInsets.all(10.0),
//                       border: UnderlineInputBorder(
//                           borderSide: BorderSide(color: Colors.black12)),
//                     ),
//                   ),
//                 )
//             ]),
//             if (_connecting)
//               Center(
//                 child: Container(
//                   margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
//                   width: MediaQuery.of(context).size.width,
//                   height: MediaQuery.of(context).size.height - 110,
//                   decoration: const BoxDecoration(color: Colors.black54),
//                   child: RTCVideoView(_localRenderer,
//                       mirror: true,
//                       objectFit:
//                           RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
//                 ),
//               )
//           ]);
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _connecting ? _disconnect : _connect,
//         tooltip: _connecting ? 'Hangup' : 'Call',
//         child: Icon(_connecting ? Icons.call_end : Icons.phone),
//       ),
//     );
//   }
// }
