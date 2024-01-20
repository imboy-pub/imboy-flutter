// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:flutter_whip/flutter_whip.dart';
// import 'package:imboy/component/helper/func.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// // import 'package:get/get.dart';
// // import 'subscriber_logic.dart';
//
// class SubscriberPage extends StatefulWidget {
//   static String tag = 'whip_subscribe_sample';
//
//   const SubscriberPage({super.key});
//
//   @override
//   // ignore: library_private_types_in_public_api
//   _SubscriberPageState createState() => _SubscriberPageState();
// }
//
// class _SubscriberPageState extends State<SubscriberPage> {
//   final _remoteRenderer = RTCVideoRenderer();
//   bool _connecting = false;
//   late WHIP _whip;
//   String stateStr = 'init';
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
//       // _serverController.text = _preferences.getString('pullServer') ??
//       //     'https://demo.cloudwebrtc.com:8080/whip/subscribe/live/stream1';
//       _serverController.text = _preferences.getString('pullServer') ??
//           'https://192.168.0.144:9800/whip/subscribe/a1234/1';
//     });
//   }
//
//   @override
//   void deactivate() {
//     super.deactivate();
//     _remoteRenderer.dispose();
//   }
//
//   void _saveSettings() {
//     _preferences.setString('pullServer', _serverController.text);
//   }
//
//   void initRenderers() async {
//     await _remoteRenderer.initialize();
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
//     try {
//       await _whip.initlize(mode: WhipMode.kReceive);
//       _whip.onTrack = (event) {
//         iPrint('_whip.onTrack => ${event.track.toString()}');
//         if (event.track.kind == 'video') {
//           // print('_whip.onTrack => ${event.streams[0].id.toString()}');
//           _remoteRenderer.srcObject = event.streams[0];
//         }
//       };
//       await _whip.connect();
//     } catch (e) {
//       iPrint('connect: error => ${e.toString()}');
//       return;
//     }
//     if (!mounted) return;
//     _connecting = true;
//
//     setState(() {});
//   }
//
//   void _disconnect() async {
//     try {
//       _remoteRenderer.srcObject = null;
//       _whip.close();
//       setState(() {
//         _connecting = false;
//       });
//     } catch (e) {
//       iPrint(e.toString());
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar:
//           AppBar(title: const Text('WHIP Subscribe Sample'), actions: <Widget>[
//         if (!_connecting)
//           IconButton(
//             icon: const Icon(Icons.qr_code_scanner_sharp),
//             onPressed: () async {
//               if (!WebRTC.platformIsDesktop) {
//                 /// only support mobile for now
//                 // Future future = Navigator.of(context).push(
//                 //     MaterialPageRoute(builder: (context) => QRViewExample()));
//                 // future.then((value) {
//                 //   print('QR code result: $value');
//                 //   this.setState(() {
//                 //     _serverController.text = value;
//                 //   });
//                 // });
//               }
//             },
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
//                   child: RTCVideoView(_remoteRenderer,
//                       mirror: false,
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
//         child: Icon(_connecting ? Icons.stop : Icons.play_arrow_sharp),
//       ),
//     );
//   }
// }
