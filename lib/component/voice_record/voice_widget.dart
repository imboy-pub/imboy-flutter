import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'custom_overlay.dart';

class VoiceWidget extends StatefulWidget {
  final Function? startRecord;
  final Function? stopRecord;
  final double? height;
  final EdgeInsets? margin;
  final Decoration? decoration;

  /// startRecord 开始录制回调  stopRecord回调
  const VoiceWidget({
    Key? key,
    this.startRecord,
    this.stopRecord,
    this.height,
    this.decoration,
    this.margin,
  }) : super(key: key);

  @override
  _VoiceWidgetState createState() => _VoiceWidgetState();
}

class _VoiceWidgetState extends State<VoiceWidget> {
  // 倒计时总时长
  int _countTotal = 60;
  double starty = 0.0;
  double offset = 0.0;
  bool isUp = false;
  String textShow = "按住说话".tr;
  String toastShow = "手指上滑,取消发送".tr;
  String voiceIco = "assets/images/chat/voice_volume_1.png";

  ///默认隐藏状态
  bool voiceState = true;
  // FlutterPluginRecord? recordPlugin;
  Timer? _timer;
  int _count = 0;
  OverlayEntry? overlayEntry;

  /////
  final FlutterSoundRecorder recorderModule = FlutterSoundRecorder();
  String recorderTxt = '00:00:00';

  Codec _codec = Codec.aacMP4;
  String _mPath = 'tau_file.mp4';
  bool mRecorderIsInited = false;
  StreamSubscription? recorderSubscription;
  int pos = 0;
  double dbLevel = 0;

  @override
  void initState() {
    openTheRecorder();
    super.initState();
  }

  ///显示录音悬浮布局
  buildOverLayView(BuildContext context) {
    if (overlayEntry == null) {
      overlayEntry = OverlayEntry(builder: (content) {
        return CustomOverlay(
          icon: Column(
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(top: 10),
                child: _countTotal - _count < 11
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 15.0),
                          child: Text(
                            (_countTotal - _count).toString(),
                            style: TextStyle(
                              fontSize: 70.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : new Image.asset(
                        voiceIco,
                        width: 100,
                        height: 100,
                        // package: 'flutter_plugin_record',
                      ),
              ),
              Container(
                child: Text(
                  toastShow + "\n" + recorderTxt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.normal,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              )
            ],
          ),
        );
      });
      Overlay.of(context)!.insert(overlayEntry!);
    }
  }

  showVoiceView() {
    setState(() {
      textShow = "松开结束".tr;
      voiceState = false;
    });

    ///显示录音悬浮布局
    buildOverLayView(context);

    debugPrint(">>> on record showVoiceView");
    recorderStart();
  }

  hideVoiceView() async {
    if (_timer!.isActive) {
      if (_count < 1) {
        Toast.showView(
            context: context,
            msg: '说话时间太短'.tr,
            icon: Text(
              '!',
              style: TextStyle(
                fontSize: 60,
                color: Colors.white,
              ),
            ));
        isUp = true;
      }
      _timer?.cancel();
      _count = 0;
    }

    setState(() {
      textShow = "按住说话".tr;
      voiceState = true;
    });

    String? filepath = await recorderStop(recorderModule);
    if (overlayEntry != null) {
      overlayEntry?.remove();
      overlayEntry = null;
    }
    debugPrint(
        ">>> on record hideVoiceView isUp ${isUp}, filepath: ${filepath}");
    if (isUp) {
      // print("取消发送");
    } else {
      debugPrint("进行发送");
    }
  }

  moveVoiceView() {
    // print(offset - start);
    setState(() {
      isUp = starty - offset > 100 ? true : false;
      if (isUp) {
        textShow = "松开手指,取消发送".tr;
        toastShow = textShow;
      } else {
        textShow = "松开结束".tr;
        toastShow = "手指上滑,取消发送".tr;
      }
    });
  }

  void cancelRecorderSubscriptions() {
    if (recorderSubscription != null) {
      recorderSubscription!.cancel();
      recorderSubscription = null;
    }
  }

  Future<void> openTheRecorder() async {
    if (!kIsWeb) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException('Microphone permission not granted');
      }
    }
    await recorderModule.openRecorder();
    if (!await recorderModule.isEncoderSupported(_codec) && kIsWeb) {
      _codec = Codec.opusWebM;
      _mPath = 'tau_file.webm';
      if (!await recorderModule.isEncoderSupported(_codec) && kIsWeb) {
        mRecorderIsInited = true;
        return;
      }
    }

    setSubscriptionDuration(40);

    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    mRecorderIsInited = true;
  }

  Future<Uint8List> getAssetData(String path) async {
    var asset = await rootBundle.load(path);
    return asset.buffer.asUint8List();
  }

  // -------  Here is the code to playback  -----------------------
  /// 开始录音
  void recorderStart() async {
    debugPrint(">>> on record start");
    try {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        Get.snackbar("", "未获取到麦克风权限");
        throw RecordingPermissionException("未获取到麦克风权限");
      }
      print('===>  获取了权限');
      Directory tempDir = await getTemporaryDirectory();
      var time = DateTime.now().millisecondsSinceEpoch ~/ 100;

      String path =
          // '${tempDir.path}/${recorderModule.slotNo}-$time${ext[Codec.aacADTS.index]}';
          '${tempDir.path}/${recorderModule.hashCode}-$time${ext[Codec.aacADTS.index]}';
      print('===>  准备开始录音');
      await recorderModule.startRecorder(
        toFile: path,
        codec: Codec.aacADTS,
        bitRate: 8000,
        sampleRate: 8000,
      );
      print('===>  监听录音');

      /// 监听录音
      recorderSubscription = recorderModule.onProgress!.listen((e) {
        debugPrint(">>> on record listen e ${e.toString()}");
        setState(() {
          pos = e.duration.inMilliseconds;
        });
        debugPrint(">>> on record listen pos: ${pos}, dbLevel: ${e.decibels};");
        if (e != null && e.duration != null) {
          DateTime date = new DateTime.fromMillisecondsSinceEpoch(
              e.duration.inMilliseconds,
              isUtc: true);
          String txt = DateFormat('mm:ss.SSS', 'en_GB').format(date);
          if (date.second >= _countTotal) {
            recorderStop(recorderModule);
          }
          if (e.decibels != null) {
            setState(() {
              recorderTxt = txt.substring(0, 9);
              dbLevel = e.decibels!.toDouble();
              print(">>> on record 当前振幅：$dbLevel");
            });
          }
        }

        if (e.decibels != null) {
          dbLevel = e.decibels as double;
          double voiceData = ((dbLevel * 100.0).floor()) / 10000;
          if (voiceData > 0 && voiceData < 0.1) {
            voiceIco = "assets/images/chat/voice_volume_2.png";
          } else if (voiceData > 0.2 && voiceData < 0.3) {
            voiceIco = "assets/images/chat/voice_volume_3.png";
          } else if (voiceData > 0.3 && voiceData < 0.4) {
            voiceIco = "assets/images/chat/voice_volume_4.png";
          } else if (voiceData > 0.4 && voiceData < 0.5) {
            voiceIco = "assets/images/chat/voice_volume_5.png";
          } else if (voiceData > 0.5 && voiceData < 0.6) {
            voiceIco = "assets/images/chat/voice_volume_6.png";
          } else if (voiceData > 0.6 && voiceData < 0.7) {
            voiceIco = "assets/images/chat/voice_volume_7.png";
          } else if (voiceData > 0.7 && voiceData < 1) {
            voiceIco = "assets/images/chat/voice_volume_7.png";
          } else {
            voiceIco = "assets/images/chat/voice_volume_1.png";
          }
          if (overlayEntry != null) {
            overlayEntry!.markNeedsBuild();
          }
          debugPrint(
              ">>> on record 振幅大小   " + voiceData.toString() + "  " + voiceIco);
          setState(() {
            dbLevel = dbLevel;
            voiceIco = voiceIco;
          });
        }
      });
      this.setState(() {
        // _state = RecordPlayState.recording;
        _mPath = path;
        print("path == $path");
      });
    } catch (err) {
      setState(() {
        recorderStop(recorderModule);
        // _state = RecordPlayState.record;
        cancelRecorderSubscriptions();
      });
    }
  }

  /// 结束录音
  Future<String?> recorderStop(FlutterSoundRecorder recorder) async {
    try {
      print('stopRecorder _mPath ${_mPath}');
      String? filepath = await recorder.stopRecorder();
      cancelRecorderSubscriptions();
      setState(() {
        dbLevel = 0.0;
        pos = 0;
        // _state = RecordPlayState.play;
      });
      // _getDuration();
      return filepath;
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  /// 获取录音文件秒数
  // Future<void> _getDuration() async {
  //   Duration d = await flutterSoundHelper.duration(_mPath);
  //   _duration = d != null ? d.inMilliseconds / 1000.0 : 0.00;
  //   print("_duration == $_duration");
  //   var minutes = d.inMinutes;
  //   var seconds = d.inSeconds % 60;
  //   var millSecond = d.inMilliseconds % 1000 ~/ 10;
  //   recorderTxt = "";
  //   if (minutes > 9) {
  //     recorderTxt = recorderTxt + "$minutes";
  //   } else {
  //     recorderTxt = recorderTxt + "0$minutes";
  //   }
  //
  //   if (seconds > 9) {
  //     recorderTxt = recorderTxt + ":$seconds";
  //   } else {
  //     recorderTxt = recorderTxt + ":0$seconds";
  //   }
  //   if (millSecond > 9) {
  //     recorderTxt = recorderTxt + ":$millSecond";
  //   } else {
  //     recorderTxt = recorderTxt + ":0$millSecond";
  //   }
  //   print(recorderTxt);
  //   setState(() {});
  // }

  Future<void> setSubscriptionDuration(
      double d) async // d is between 0.0 and 2000 (milliseconds)
  {
    setState(() {});
    await recorderModule.setSubscriptionDuration(
      Duration(milliseconds: d.floor()),
    );
  }
  // --------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      child: GestureDetector(
        onLongPressStart: (details) {
          starty = details.globalPosition.dy;
          _timer = Timer.periodic(Duration(milliseconds: 1000), (t) {
            _count++;
            if (_count == _countTotal) {
              hideVoiceView();
            }
          });
          showVoiceView();
        },
        onLongPressEnd: (details) {
          hideVoiceView();
        },
        onLongPressMoveUpdate: (details) {
          offset = details.globalPosition.dy;
          moveVoiceView();
        },
        child: Container(
          height: widget.height ?? 60,
          decoration: widget.decoration ??
              BoxDecoration(
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(
                  width: 1.0,
                  color: Colors.white70,
                ),
                color: Colors.white70,
              ),
          margin: widget.margin ?? EdgeInsets.fromLTRB(50, 0, 50, 20),
          child: Center(
            child: Text(
              textShow,
              // '${textShow}(pos: ${pos})',
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    recorderStop(recorderModule);
    cancelRecorderSubscriptions();

    // Be careful : you must `close` the audio session when you have finished with it.
    recorderModule.closeRecorder();

    // recordPlugin?.dispose();
    _timer?.cancel();
    super.dispose();
  }
}

class Toast {
  static showView({
    BuildContext? context,
    String? msg,
    TextStyle? style,
    Widget? icon,
    Duration duration = const Duration(seconds: 1),
    int count = 3,
    Function? onTap,
  }) {
    OverlayEntry? overlayEntry;
    int _count = 0;

    void removeOverlay() {
      overlayEntry?.remove();
      overlayEntry = null;
    }

    if (overlayEntry == null) {
      overlayEntry = OverlayEntry(builder: (content) {
        return Container(
          child: GestureDetector(
            onTap: () {
              if (onTap != null) {
                removeOverlay();
                onTap();
              }
            },
            child: CustomOverlay(
              icon: Column(
                children: [
                  Padding(
                    child: icon,
                    padding: const EdgeInsets.only(
                      bottom: 10.0,
                    ),
                  ),
                  Container(
                    child: Text(
                      msg ?? '',
                      style: style ??
                          TextStyle(
                            fontStyle: FontStyle.normal,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      });
      Overlay.of(context!)!.insert(overlayEntry!);
      if (onTap != null) return;
      Timer.periodic(duration, (timer) {
        _count++;
        if (_count == count) {
          _count = 0;
          timer.cancel();
          removeOverlay();
        }
      });
    }
  }
}
