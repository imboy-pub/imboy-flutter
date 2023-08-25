import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:haishin_kit/audio_settings.dart';
import 'package:haishin_kit/audio_source.dart';
import 'package:haishin_kit/net_stream_drawable_texture.dart';
import 'package:haishin_kit/rtmp_connection.dart';
import 'package:haishin_kit/rtmp_stream.dart';
import 'package:haishin_kit/video_settings.dart';
import 'package:haishin_kit/video_source.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:niku/namespace.dart' as n;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/live_room/live_room/live_room_view.dart';
import 'package:imboy/store/model/live_room_model.dart';

import 'live_room_logic.dart';

class LiveRoomPage extends StatefulWidget {
  LiveRoomModel room;

  LiveRoomPage({super.key, required this.room});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  RtmpConnection? _connection;
  RtmpStream? _stream;
  bool _recording = false;

  String _mode = "publish";
  CameraPosition currentPosition = CameraPosition.back;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    _stream?.dispose();
    _connection?.dispose();
    super.dispose();
  }

  Future<void> initPlatformState() async {
    await Permission.camera.request();
    await Permission.microphone.request();

    // Set up AVAudioSession for iOS.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth,
    ));

    RtmpConnection connection = await RtmpConnection.create();
    connection.eventChannel.receiveBroadcastStream().listen((event) {
      iPrint("receiveBroadcastStream listen ${event.toString()}");
      // listen {data: {description: , level: error, code: NetConnection.Connect.Failed}, type: rtmpStatus}
      // listen {type: rtmpStatus, data: {description: Connection succeeded., code: NetConnection.Connect.Success, data: [null], objectEncoding: 0.0, level: status}}
      switch (event["data"]["code"]) {
        case 'NetConnection.Connect.Success':
          if (_mode == "publish") {
            _stream?.publish("live");
          } else {
            _stream?.play("live");
          }
          setState(() {
            _recording = true;
          });
          break;
      }
    });

    RtmpStream stream = await RtmpStream.create(connection);
    stream.audioSettings = AudioSettings(bitrate: 64 * 1000);
    stream.videoSettings = VideoSettings(
      width: 480,
      height: 272,
      bitrate: 512 * 1000,
    );
    stream.attachAudio(AudioSource());
    stream.attachVideo(VideoSource(position: currentPosition));

    if (!mounted) return;

    setState(() {
      _connection = connection;
      _stream = stream;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('HaishinKit'), actions: [
          IconButton(
            icon: _mode == "publish"
                ? Icon(Icons.publish)
                : Icon(Icons.play_arrow),
            onPressed: () {
              if (_mode == "publish") {
                _mode = "playback";
                _stream?.attachVideo(null);
                _stream?.attachAudio(null);
              } else {
                _mode = "publish";
                _stream?.attachAudio(AudioSource());
                _stream?.attachVideo(VideoSource(position: currentPosition));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () {
              if (currentPosition == CameraPosition.front) {
                currentPosition = CameraPosition.back;
              } else {
                currentPosition = CameraPosition.front;
              }
              _stream?.attachVideo(VideoSource(position: currentPosition));
            },
          )
        ]),
        body: Center(
          child: _stream == null
              ? const Text("")
              : NetStreamDrawableTexture(_stream),
        ),
        floatingActionButton: FloatingActionButton(
          child: _recording
              ? const Icon(Icons.fiber_smart_record)
              : const Icon(Icons.not_started),
          onPressed: () {
            if (_recording) {
              _connection?.close();
              setState(() {
                _recording = false;
              });
            } else {
              // _connection?.connect("rtmp://192.168.1.9/live");
              iPrint("do_connect");
              _connection?.connect("rtmp://192.168.0.144:3936/cameras/cam1");

              // _stream?.publish("live");
            }
          },
        ),
      ),
    );
  }
}

/*
webrtc 需要 服务端也作为webrtc客户端才行
class LiveRoomPage extends StatefulWidget {
  LiveRoomModel room;

  LiveRoomPage({super.key, required this.room});

  @override
  _LiveRoomPageState createState() => _LiveRoomPageState();
}

enum PeerType {
  kPublisher,
  kSubscriber,
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  final _renderer = RTCVideoRenderer();
  SfuWsSample? _sfuSample;
  late SharedPreferences prefs;
  String _serverAddress = '';
  PeerType _type = PeerType.kPublisher;

  @override
  initState() {
    super.initState();
    init();
  }

  init() async {
    await _renderer.initialize();
    prefs = await SharedPreferences.getInstance();
    setState(() {
      // _serverAddress = prefs.getString('server')!;
    });
    // _makeCall();
  }

  @override
  deactivate() {
    super.deactivate();
    if (_sfuSample != null) {
      _hangUp();
    }
    _renderer.dispose();
  }

  _makeCall() async {
    if (_sfuSample != null) {
      print('Already in calling!');
      return;
    }

    _sfuSample = SfuWsSample();

    _sfuSample?.onError = (error) {
      print(error);
      _sfuSample?.close();
      setState(() {
        // _sfuSample = null;
      });
    };

    _sfuSample?.onOpen = () {
      if (_type == PeerType.kPublisher)
        _sfuSample?.createPublisher();
      else if (_type == PeerType.kSubscriber) {
        _sfuSample?.createSubscriber();
      }
    };

    _sfuSample?.onLocalStream = (stream) {
      this.setState(() {
        _renderer.srcObject = stream;
      });
    };

    _sfuSample?.onRemoteStream = (stream) {
      this.setState(() {
        _renderer.srcObject = stream;
      });
    };
    if (_type == PeerType.kPublisher)
      _sfuSample?.createPublisher();
    else if (_type == PeerType.kSubscriber) {
      _sfuSample?.createSubscriber();
    }
    // await _sfuSample.connect(_serverAddress);
  }

  _hangUp() async {
    try {
      if (_sfuSample != null) {
        _sfuSample!.close();
        _renderer.srcObject = null;
      }
    } catch (e) {
      print(e.toString());
    }
    setState(() {
      // _sfuSample = null;
    });
  }

  _buildSetupWidgets(context) {
    return Align(
        alignment: Alignment(0, 0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                  width: 260.0,
                  child: TextField(
                    keyboardType: TextInputType.text,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(10.0),
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12)),
                      hintText: _serverAddress ?? 'Enter Pion-SFU address.',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _serverAddress = value;
                      });
                    },
                  )),
              SizedBox(width: 260.0, height: 48.0),
              SizedBox(
                  width: 260.0,
                  height: 48.0,
                  child: Row(
                    children: <Widget>[
                      Radio<PeerType>(
                          value: PeerType.kPublisher,
                          groupValue: _type,
                          onChanged: (value) {
                            setState(() {
                              _type = value!;
                            });
                          }),
                      Text('Publisher'),
                      Radio<PeerType>(
                          value: PeerType.kSubscriber,
                          groupValue: _type,
                          onChanged: (value) {
                            setState(() {
                              _type = value!;
                            });
                          }),
                      Text('Subscriber'),
                    ],
                  )),
              SizedBox(width: 260.0, height: 48.0),
              SizedBox(
                  width: 220.0,
                  height: 48.0,
                  child: MaterialButton(
                    child: Text(
                      'Connect',
                      style: TextStyle(fontSize: 16.0, color: Colors.white),
                    ),
                    color: Colors.blue,
                    textColor: Colors.white,
                    onPressed: () {
                      if (_serverAddress != null) {
                        _makeCall();
                        prefs.setString('server', _serverAddress);
                        return;
                      }
                      showDialog<Null>(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Server is empty'),
                            content: Text('Please enter Pion-SFU address!'),
                            actions: <Widget>[
                              TextButton(
                                child: Text('Ok'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ))
            ]));
  }

  _buildCallWidgets(context) {
    return Center(
      child: Container(
        margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: RTCVideoView(_renderer),
        decoration: BoxDecoration(color: Colors.black54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Pions SFU Test'),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Container(
              color: Colors.white,
              child: _sfuSample == null
                  ? _buildSetupWidgets(context)
                  : _buildCallWidgets(context));
        },
      ),
      floatingActionButton: _sfuSample == null
          ? null
          : FloatingActionButton(
              onPressed: _hangUp,
              tooltip: 'Hangup',
              child: Icon(
                Icons.call_end,
              ),
              backgroundColor: Colors.red,
            ),
    );
  }
}
*/

/*
class LiveRoomPage extends StatelessWidget {
  LiveRoomModel room;

  final logic = Get.put(LiveRoomLogic());
  final state = Get.find<LiveRoomLogic>().state;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();

  LiveRoomPage({super.key, required this.room});

  void initData() async {}

  @override
  Widget build(BuildContext context) {
    //
    initData();

    return Scaffold(
      appBar: PageAppBar(
        title: '直播间'.tr,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: AppColors.primaryBackground,
          child: n.Column([], mainAxisSize: MainAxisSize.min),
        ),
      ),
    );
  }
}
*/
