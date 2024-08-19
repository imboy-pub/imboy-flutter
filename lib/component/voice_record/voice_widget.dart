import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:logger/logger.dart';
import 'package:niku/namespace.dart' as n;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'custom_overlay.dart';

class AudioFile {
  const AudioFile({
    required this.file,
    required this.duration,
    required this.mimeType,
    required this.waveform,
  });

  final File file;
  final Duration duration;
  final String mimeType;
  final List<double> waveform;
}

class VoiceWidget extends StatefulWidget {
  final Function()? startRecord;
  final Function(AudioFile? obj)? stopRecord;

  final double? height;
  final EdgeInsets? margin;
  final Decoration? decoration;

  /// startRecord 开始录制回调  stopRecord回调
  const VoiceWidget({
    super.key,
    this.startRecord,
    this.stopRecord,
    this.height,
    this.decoration,
    this.margin,
  });

  @override
  // ignore: library_private_types_in_public_api
  _VoiceWidgetState createState() => _VoiceWidgetState();
}

class _VoiceWidgetState extends State<VoiceWidget> {
  // 倒计时总时长
  final _countTotal = const Duration(minutes: 3);
  double start = 0.0;
  double offset = 0.0;
  bool isUp = false;
  String textShow = 'chat_hold_down_talk'.tr;
  String toastShow = 'slide_up_cancel_sending'.tr;
  String voiceIco = "assets/images/chat/voice_volume_1.png";

  final List<double> waveform = [];
  String recordingMimeType = 'audio/aac';
  late Codec recordCodec;

  OverlayEntry? overlayEntry;

  final recorder = FlutterSoundRecorder(logLevel: Level.error);
  String recorderTxt = '00:00.000';
  Duration recordingDuration = const Duration();

  String filePath = '';
  StreamSubscription? recordStream;

  @override
  void initState() {
    super.initState();
    debugPrint("> on _VoiceWidgetState initState");
    init();
  }

  /// 在iOS真机上面依赖该方法
  /// https://github.com/Canardoux/flutter_sound/issues/868
  Future<void> init() async {
    if (!kIsWeb) {
      try {
        var status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          Get.snackbar("", 'microphone_permission_not_obtained'.tr);
          throw RecordingPermissionException(
              'microphone_permission_not_obtained'.tr);
        }

        //判断如果还没拥有读写权限就申请获取权限
        if (await Permission.storage.request().isDenied) {
          await Permission.storage.request();
          if ((await Permission.storage.status) != PermissionStatus.granted) {
            Get.snackbar("", 'microphone_permission_not_obtained'.tr);
            throw RecordingPermissionException(
                'storage_permission_not_obtained'.tr);
          }
        }
      } catch (e, stack) {
        // 也可以使用 print 语句打印异常信息
        iPrint('init_login_error: $e');
        iPrint('init_Stack trace:\n${stack.toString()}');
        // return e.toString();
      }
    }
    await recorder.openRecorder();

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
  }

  ///显示录音悬浮布局
  buildOverLayView(BuildContext context) {
    overlayEntry ??= OverlayEntry(builder: (content) {
      return CustomOverlay(
        height: 200,
        icon: n.Column([
          Container(
            margin: const EdgeInsets.only(top: 10),
            child: Image.asset(
              voiceIco,
              width: 100,
              height: 100,
              // package: 'flutter_plugin_record',
            ),
          ),
          Text(
            "$toastShow\n$recorderTxt",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontStyle: FontStyle.normal,
              color: Colors.white,
              fontSize: 14,
            ),
          )
        ]),
      );
    });
    Overlay.of(context).insert(overlayEntry!);
  }

  /// 设置订阅周期
  Future<void> setSubscriptionDuration(
      double d) async // d is between 0.0 and 2000 (milliseconds)
  {
    setState(() {});
    await recorder.setSubscriptionDuration(
      Duration(milliseconds: d.floor()),
    );
  }

  showVoiceView(BuildContext ctx) {
    setState(() {
      textShow = 'release_end'.tr;
    });

    if (recordingDuration.inMilliseconds > _countTotal.inMilliseconds) {
      hideVoiceView(ctx);
    }

    ///显示录音悬浮布局
    buildOverLayView(ctx);
    // debugPrint("> on record showVoiceView");
    recorderStart(ctx);
  }

  Future<void> hideVoiceView(BuildContext ctx) async {
    iPrint("hideVoiceView ${DateTime.now()}");
    filePath = (await recorderStop(recorder))!;
    if (recordingDuration.inMilliseconds < 1000) {
      EasyLoading.showToast('speaking_too_short'.tr);
      isUp = true;
    }

    setState(() {
      textShow = 'chat_hold_down_talk'.tr;
    });

    if (overlayEntry != null) {
      overlayEntry?.remove();
      overlayEntry = null;
    }
    if (isUp) {
      // print("取消发送");
    } else if (strNoEmpty(filePath)) {
      debugPrint("进行发送 $filePath waveform ${waveform.toString()}");
      await widget.stopRecord!.call(
        AudioFile(
          file: File(filePath),
          duration: recordingDuration,
          waveform: waveform,
          mimeType: recordingMimeType,
        ),
      );
      setState(() {
        recordingDuration = const Duration();
        waveform.clear();
      });
    }
  }

  moveVoiceView() {
    iPrint("moveVoiceView ${DateTime.now()}");
    setState(() {
      isUp = start - offset > 120 ? true : false;
      if (isUp) {
        textShow = 'release_finger_cancel_sending'.tr;
        toastShow = textShow;
      } else {
        textShow = 'release_end'.tr;
        toastShow = 'slide_up_cancel_sending'.tr;
      }
    });
  }

  Future<void> cancelRecorderSubscriptions({String from = ''}) async {
    iPrint("cancelRecorderSubscriptions $from");
    await recordStream?.cancel();
    recordStream = null;
  }

  /// Creates an path to a temporary file.
  Future<String> _createTempAacFilePath(String name,
      {String ext = 'aac'}) async {
    if (kIsWeb) {
      throw Exception(
        'This method only works for mobile as it creates a temporary AAC file',
      );
    }
    final tmpDir = await getTemporaryDirectory();
    final path = '${join(tmpDir.path, name)}.$ext';
    final parent = dirname(path);
    await Directory(parent).create(recursive: true);
    return path;
  }

  String formatDuration(int milliseconds) {
    const oneDigit = '0';
    int totalSeconds = milliseconds ~/ 1000;
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds - seconds) ~/ 60;

    String minuteStr = '$minutes'.padLeft(2, oneDigit); // 确保分钟是两位数
    String secondStr = '$seconds'.padLeft(2, oneDigit); // 确保秒是两位数
    String msStr = '${milliseconds % 1000}'.padLeft(3, oneDigit); // 毫秒

    return '$minuteStr:$secondStr.$msStr';
  }

  /// 开始录音
  void recorderStart(BuildContext ctx) async {
    debugPrint("> on record start");
    try {
      // String name = "${Xid().toString()}";
      String name = "voice_tmp";
      if (kIsWeb) {
        if (await recorder.isEncoderSupported(Codec.opusWebM)) {
          filePath = '$name.webm';
          recordCodec = Codec.opusWebM;
          recordingMimeType = 'audio/webm;codecs="opus"';
        } else {
          filePath = '$name.mp4';
          recordCodec = Codec.aacMP4;
          recordingMimeType = 'audio/aac';
        }
      } else {
        filePath = await _createTempAacFilePath(name);
        recordCodec = Codec.aacADTS;
        recordingMimeType = 'audio/aac';
      }
      // 必须要设置，才能够监听 振幅大小
      setSubscriptionDuration(1);
      await recorder.startRecorder(
        toFile: filePath,
        codec: recordCodec,
        // bitRate: 8000 | 10000 | 11000 不行
        bitRate: 12000,
        // sampleRate: 8000,
        audioSource: AudioSource.microphone,
      );

      await cancelRecorderSubscriptions();

      /// 监听录音
      recordStream ??= recorder.onProgress!.listen((e) {
        // debugPrint("> on record listen e ${e.toString()} ${DateTime.now()}");
        if (e.decibels != null) {
          // 分贝
          double dbLevel = e.decibels as double;
          waveform.add(dbLevel);

          double voiceData = dbLevel / 10.0 - 0.2;

          debugPrint(
              "> on record listen voiceData $voiceData ; dbLevel $dbLevel; e ${e.toString()} ${DateTime.now()}");
          if (voiceData > 0 && voiceData < 0.1) {
            voiceIco = "assets/images/chat/voice_volume_1.png";
          } else if (voiceData > 0.2 && voiceData < 0.3) {
            voiceIco = "assets/images/chat/voice_volume_2.png";
          } else if (voiceData > 0.3 && voiceData < 0.4) {
            voiceIco = "assets/images/chat/voice_volume_3.png";
          } else if (voiceData > 0.4 && voiceData < 0.5) {
            voiceIco = "assets/images/chat/voice_volume_4.png";
          } else if (voiceData > 0.5 && voiceData < 0.6) {
            voiceIco = "assets/images/chat/voice_volume_5.png";
          } else if (voiceData > 0.6 && voiceData < 0.7) {
            voiceIco = "assets/images/chat/voice_volume_6.png";
          } else if (voiceData > 0.7 && voiceData < 1) {
            voiceIco = "assets/images/chat/voice_volume_7.png";
          } else if (voiceData > 1) {
            voiceIco = "assets/images/chat/voice_volume_7.png";
          } else {
            voiceIco = "assets/images/chat/voice_volume_1.png";
          }
          if (overlayEntry != null) {
            overlayEntry!.markNeedsBuild();
          }
          setState(() {
            recordingDuration = e.duration;
            recorderTxt = formatDuration(recordingDuration.inMilliseconds);
            voiceIco = voiceIco;
          });
        }
      });
      setState(() {
        filePath = filePath;
      });
    } catch (err) {
      iPrint("on record start err ${err.toString()}");
      setState(() {
        recorderStop(recorder);
      });
    }
  }

  /// 结束录音
  Future<String?> recorderStop(FlutterSoundRecorder recorder) async {
    iPrint("recorderStop ${DateTime.now()}");
    try {
      String? filepath = await recorder.stopRecorder();
      await cancelRecorderSubscriptions(from: 'recorderStop');
      iPrint("recorderStop $filepath ${DateTime.now()}");
      iPrint("recorderStop ${File(filepath!).readAsBytesSync()}");
      recorderTxt = '00:00.000';
      if (mounted) {
        setState(() {
          recorderTxt;
        });
      }
      // _getDuration();
      return filepath;
    } catch (err) {
      debugPrint('recorderStop error: $err');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        start = details.globalPosition.dy;
        showVoiceView(context);
      },
      onLongPressEnd: (details) {
        hideVoiceView(context);
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
                color: Get.isDarkMode
                    ? const Color.fromRGBO(44, 44, 44, 1.0)
                    : const Color.fromRGBO(255, 255, 255, 1.0),
              ),
              color: Get.isDarkMode
                  ? const Color.fromRGBO(44, 44, 44, 1.0)
                  : const Color.fromRGBO(255, 255, 255, 1.0),
            ),
        margin: widget.margin ?? const EdgeInsets.fromLTRB(50, 0, 50, 20),
        child: Center(
            child: Text(
          textShow,
          style: const TextStyle(fontSize: 20),
        )),
      ),
    );
  }

  @override
  void dispose() {
    recorderStop(recorder);
    cancelRecorderSubscriptions();
    // Be careful : you must `close` the audio session when you have finished with it.
    recorder.closeRecorder();
    // recordPlugin?.dispose();
    super.dispose();
  }
}
