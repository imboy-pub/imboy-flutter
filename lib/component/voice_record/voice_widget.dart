import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/services.dart'; // 添加触觉反馈
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:logger/logger.dart';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'package:imboy/component/helper/func.dart';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'custom_overlay.dart';
import 'package:imboy/i18n/strings.g.dart';

// 添加生命周期监听

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
  final void Function()? startRecord;
  final void Function(AudioFile? obj)? stopRecord;

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

class _VoiceWidgetState extends State<VoiceWidget> with WidgetsBindingObserver {
  // 倒计时总时长
  final _countTotal = const Duration(minutes: 3);
  double start = 0.0;
  double offset = 0.0;
  bool isUp = false;
  String textShow = t.chat.chatHoldDownTalk;
  String toastShow = t.common.slideUpCancelSending;

  final List<double> waveform = [];
  String recordingMimeType = 'audio/aac';
  late Codec recordCodec;

  // 当前分贝值，用于实时响应声音大小变化
  double currentDecibels = -60.0;

  // AudioWaveforms controller
  late RecorderController recorderController;

  OverlayEntry? overlayEntry;

  final recorder = FlutterSoundRecorder(logLevel: Level.error);
  String recorderTxt = '00:00.000';
  Duration recordingDuration = const Duration();

  String filePath = '';
  StreamSubscription<dynamic>? recordStream;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint("> on _VoiceWidgetState initState");
    init();
    initRecorderController();
    // 添加生命周期监听
    WidgetsBinding.instance.addObserver(this);
  }

  /// 在iOS真机上面依赖该方法
  /// https://github.com/Canardoux/flutter_sound/issues/868
  Future<void> init() async {
    if (!kIsWeb) {
      try {
        var status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          EasyLoading.showError(t.common.microphonePermissionNotObtained);
          throw RecordingPermissionException(
            t.common.microphonePermissionNotObtained,
          );
        }

        //判断如果还没拥有读写权限就申请获取权限
        if (await Permission.storage.request().isDenied) {
          await Permission.storage.request();
          if ((await Permission.storage.status) != PermissionStatus.granted) {
            EasyLoading.showError(t.common.storagePermissionNotObtained);
            throw RecordingPermissionException(
              t.common.storagePermissionNotObtained,
            );
          }
        }
      } on Exception catch (e) {
        iPrint('init_login_error: ${e.runtimeType}');
      }
    }
    await recorder.openRecorder();

    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
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
      ),
    );
  }

  /// 初始化RecorderController
  void initRecorderController() {
    // 在 audio_waveforms 2.0.0 中，updateFrequency 功能可能已被移除或通过构造函数设置
    recorderController = RecorderController();
    // 移除 updateFrequency 设置，使用默认配置
  }

  ///显示录音悬浮布局
  void buildOverLayView(BuildContext context) {
    overlayEntry ??= OverlayEntry(
      builder: (content) {
        return CustomOverlay(
          height: 210,
          waveform: waveform,
          durationText: recorderTxt, // 显示完整时间格式 00:00.000
          isRecording: true,
          isCancelling: isUp,
          currentDecibels: currentDecibels,
          recorderController: recorderController,
        );
      },
    );
    Overlay.of(context).insert(overlayEntry!);
  }

  /// 设置订阅周期
  Future<void> setSubscriptionDuration(
    double d,
  ) async // d is between 0.0 and 2000 (milliseconds)
  {
    setState(() {});
    await recorder.setSubscriptionDuration(Duration(milliseconds: d.floor()));
  }

  void showVoiceView(BuildContext ctx) {
    setState(() {
      textShow = t.main.releaseEnd;
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
    try {
      String? result = await recorderStop(recorder);
      iPrint("recorderStop result: $result");
      if (result != null) {
        filePath = result;
      } else {
        iPrint("recorderStop returned null");
        isUp = true;
      }
    } on Exception catch (e) {
      iPrint("recorderStop error: ${e.runtimeType}");
      isUp = true;
    }

    if (recordingDuration.inMilliseconds < 1000) {
      EasyLoading.showToast(t.main.speakingTooShort);
      isUp = true;
    }

    setState(() {
      textShow = t.chat.chatHoldDownTalk;
    });

    if (overlayEntry != null) {
      overlayEntry?.remove();
      overlayEntry = null;
    }

    // 无论是否取消发送，都要取消订阅
    await cancelRecorderSubscriptions(
      from: 'hideVoiceView',
      stopRecorder: true,
    );

    if (isUp) {
      iPrint("取消发送录音");
    } else if (strNoEmpty(filePath)) {
      if (kDebugMode) debugPrint("进行发送录音 waveform length: ${waveform.length}");
      widget.stopRecord!.call(
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

  void moveVoiceView() {
    iPrint("moveVoiceView ${DateTime.now()}");
    setState(() {
      isUp = start - offset > 120 ? true : false;
      if (isUp) {
        textShow = t.common.releaseFingerCancelSending;
        toastShow = textShow;
      } else {
        textShow = t.main.releaseEnd;
        toastShow = t.common.slideUpCancelSending;
      }
      // 更新悬浮层状态
      if (overlayEntry != null) {
        overlayEntry!.markNeedsBuild();
      }
    });
  }

  Future<void> cancelRecorderSubscriptions({
    String from = '',
    bool stopRecorder = false,
  }) async {
    // 只在调试模式下打印取消订阅的日志
    if (const bool.fromEnvironment('DEBUG_AUDIO')) {
      iPrint(
        "cancelRecorderSubscriptions $from, recordStream is null: ${recordStream == null}, stopRecorder: $stopRecorder",
      );
    }

    if (recordStream != null) {
      try {
        await recordStream!.cancel();
        // 只在调试模式下打印成功取消的日志
        if (const bool.fromEnvironment('DEBUG_AUDIO')) {
          iPrint("recordStream cancelled successfully from $from");
        }
      } on Exception catch (e) {
        // 只在调试模式下打印错误日志
        if (const bool.fromEnvironment('DEBUG_AUDIO')) {
          iPrint("Error cancelling recordStream from $from: ${e.runtimeType}");
        }
      } finally {
        recordStream = null;
      }
    }

    // 只有在明确要求时才停止录音器
    if (stopRecorder) {
      try {
        if (recorder.isRecording) {
          // 只在调试模式下打印停止录音器的日志
          if (const bool.fromEnvironment('DEBUG_AUDIO')) {
            iPrint("Recorder is still recording, stopping it from $from");
          }
          await recorder.stopRecorder();
        }
      } on Exception catch (e) {
        // 只在调试模式下打印错误日志
        if (const bool.fromEnvironment('DEBUG_AUDIO')) {
          iPrint("Error stopping recorder from $from: ${e.runtimeType}");
        }
      }
    }
  }

  /// Creates an path to a temporary file.
  Future<String> _createTempAacFilePath(
    String name, {
    String ext = 'aac',
  }) async {
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

  /// 生命周期监听
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (kDebugMode) {
      debugPrint("VoiceWidget didChangeAppLifecycleState: $state");
    }

    // 当应用进入后台、暂停或不活动状态时，停止录音
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      // 如果正在录音，强制停止
      if (recorder.isRecording && overlayEntry != null) {
        if (kDebugMode) {
          debugPrint("App going to background, force stopping recording");
        }
        forceStopRecording();
      }
    }
  }

  /// 强制停止录音（用于应用进入后台或切换输入模式）
  void forceStopRecording() {
    if (overlayEntry != null) {
      overlayEntry?.remove();
      overlayEntry = null;
    }

    isUp = true; // 标记为取消状态
    // 先取消订阅并停止录音器，然后清理录音状态
    cancelRecorderSubscriptions(
      from: 'forceStopRecording',
      stopRecorder: true,
    ).then((_) {
      // 直接清理录音状态，不需要 context
      setState(() {
        textShow = t.chat.chatHoldDownTalk;
      });
      if (recordingDuration.inMilliseconds < 1000) {
        EasyLoading.showToast(t.main.speakingTooShort);
      }
      recordingDuration = const Duration();
      waveform.clear();
    });

    // 显示提示
    EasyLoading.showToast(t.common.recordingCancelled);
  }

  /// 当切换到其他输入模式时调用
  void onInputModeChanged() {
    if (kDebugMode) debugPrint("VoiceWidget onInputModeChanged");
    if (overlayEntry != null) {
      if (kDebugMode) {
        debugPrint(
          "Voice widget detected input mode change, stopping recording",
        );
      }
      forceStopRecording();
    }
  }

  /// 开始录音
  Future<void> recorderStart(BuildContext ctx) async {
    if (kDebugMode) debugPrint("> on record start");
    try {
      // String name = "${Xid().toString()}";
      String name = "voice_tmp_${DateTime.now().millisecondsSinceEpoch}";
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

      if (kDebugMode) iPrint("recorderStart codec: $recordCodec");

      // 必须要设置，才能够监听 振幅大小
      await setSubscriptionDuration(1);

      // 确保之前的订阅已取消，但不要停止录音器
      if (recordStream != null) {
        try {
          await recordStream!.cancel();
          recordStream = null;
          iPrint("Previous recordStream cancelled");
        } on Exception catch (e) {
          iPrint("Error cancelling previous recordStream: ${e.runtimeType}");
        }
      }

      // 启动录音器
      await recorder.startRecorder(
        toFile: filePath,
        codec: recordCodec,
        // bitRate: 8000 | 10000 | 11000 不行
        bitRate: 12000,
        // sampleRate: 8000,
        audioSource: AudioSource.microphone,
      );

      iPrint("Recorder started, isRecording: ${recorder.isRecording}");

      // 检查录音器是否正在录音
      if (!recorder.isRecording) {
        iPrint(
          "Recorder is not recording after startRecorder, skipping subscription setup",
        );
        return;
      }

      // 暂时不启动 AudioWaveforms 的录音功能，避免与 FlutterSound 冲突
      await recorderController.record();

      // 设置录音监听
      recordStream = recorder.onProgress!.listen(
        (e) {
          // 检查是否仍在录音状态且订阅未取消
          if (!recorder.isRecording || recordStream == null) {
            // 不再打印日志，直接返回
            return;
          }

          // debugPrint("> on record listen e ${e.toString()} ${DateTime.now()}");
          if (e.decibels != null) {
            // 分贝
            double dbLevel = e.decibels as double;

            // 更新当前分贝值
            currentDecibels = dbLevel;

            // 优化波形数据收集，使其更适合实时显示
            // 将分贝值转换为0-1之间的振幅值
            double normalizedAmplitude = (dbLevel + 60) / 60; // 假设-60dB到0dB的范围
            normalizedAmplitude = normalizedAmplitude.clamp(
              0.0,
              1.0,
            ); // 限制在0-1之间

            // 添加波形数据，限制数组长度以避免内存问题
            waveform.add(normalizedAmplitude);
            if (waveform.length > 100) {
              waveform.removeRange(0, waveform.length - 100); // 保留最近100个数据点
            }

            // 只在调试模式下打印日志
            if (const bool.fromEnvironment('DEBUG_AUDIO')) {
              debugPrint(
                "> on record listen dbLevel $dbLevel; normalizedAmplitude $normalizedAmplitude; e ${e.toString()} ${DateTime.now()}",
              );
            }
            if (overlayEntry != null) {
              overlayEntry!.markNeedsBuild();
            }
            setState(() {
              recordingDuration = e.duration;
              recorderTxt = formatDuration(recordingDuration.inMilliseconds);
            });
          }
        },
        onError: (Object error) {
          iPrint("Error in record stream: ${error.runtimeType}");
          // 发生错误时取消订阅
          cancelRecorderSubscriptions(from: 'stream_error');
        },
        onDone: () {
          iPrint("Record stream completed");
          // 流完成时取消订阅
          cancelRecorderSubscriptions(from: 'stream_done');
        },
      );

      iPrint("Record stream subscription setup completed");
      setState(() {
        filePath = filePath;
      });
    } on Exception catch (err) {
      iPrint("on record start err: ${err.runtimeType}");
      // 发生错误时停止录音
      await recorderStop(recorder);
    }
  }

  /// 结束录音
  Future<String?> recorderStop(FlutterSoundRecorder recorder) async {
    iPrint("recorderStop ${DateTime.now()}");
    try {
      // 先取消订阅，防止停止录音后仍有监听事件，但不停止录音器
      await cancelRecorderSubscriptions(
        from: 'recorderStop_before_stop',
        stopRecorder: false,
      );

      // 暂时不停止 recorderController，避免与 FlutterSound 冲突
      try {
        await recorderController.stop().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            iPrint("recorderController.stop() timeout after 2s");
            return null;
          },
        );
        iPrint("recorderController stopped");
      } on Exception catch (e) {
        iPrint("recorderController.stop() error: ${e.runtimeType}");
      }

      // 停止 FlutterSound recorder - 添加超时保护防止永久阻塞
      String? filepath;
      try {
        filepath = await recorder.stopRecorder().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            iPrint("recorder.stopRecorder() timeout after 5s - returning null");
            return null;
          },
        );
        iPrint(
          "FlutterSound recorder stopped, hasFilepath: ${filepath != null}",
        );
      } on TimeoutException {
        iPrint("recorder.stopRecorder() timed out - treating as cancellation");
        return null;
      } on Exception catch (e) {
        iPrint("recorder.stopRecorder() error: ${e.runtimeType}");
        return null;
      }

      // 再次确保订阅已取消，此时可以停止录音器
      await cancelRecorderSubscriptions(
        from: 'recorderStop_after_stop',
        stopRecorder: false,
      );

      if (filepath != null && filepath.isNotEmpty) {
        try {
          final file = File(filepath);
          if (file.existsSync()) {
            iPrint("recorderStop file exists, size: ${file.lengthSync()}");
          } else {
            iPrint("recorderStop file does not exist");
          }
        } on Exception catch (e) {
          iPrint("recorderStop file check error: ${e.runtimeType}");
        }
      } else {
        iPrint("recorderStop filepath is null or empty");
      }

      recorderTxt = '00:00.000';
      if (mounted) {
        setState(() {
          recorderTxt = recorderTxt;
        });
      }
      return filepath;
    } on Exception catch (err) {
      iPrint('recorderStop error: ${err.runtimeType}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        HapticFeedback.mediumImpact(); // 添加触觉反馈
        start = details.globalPosition.dy;
        showVoiceView(context);
      },
      onLongPressEnd: (details) {
        HapticFeedback.lightImpact(); // 添加触觉反馈
        hideVoiceView(context);
      },
      onLongPressMoveUpdate: (details) {
        offset = details.globalPosition.dy;
        moveVoiceView();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuart,
        height: widget.height ?? 60,
        decoration:
            widget.decoration ??
            BoxDecoration(
              borderRadius: AppRadius.borderRadiusMedium,
              gradient: LinearGradient(
                colors: [
                  ThemeManager.instance
                      .getThemeColor('primary')
                      .withValues(alpha: 0.1),
                  ThemeManager.instance
                      .getThemeColor('primary')
                      .withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                width: 1.5,
                color: ThemeManager.instance
                    .getThemeColor('primary')
                    .withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: ThemeManager.instance
                      .getThemeColor('primary')
                      .withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
        margin: widget.margin ?? const EdgeInsets.fromLTRB(50, 0, 50, 20),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mic,
                color: ThemeManager.instance.getThemeColor('primary'),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                textShow,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: ThemeManager.instance.getThemeColor('onSurface'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 移除生命周期监听
    WidgetsBinding.instance.removeObserver(this);

    // 确保录音停止并取消所有订阅
    iPrint("VoiceWidget dispose: cleaning up resources");
    if (recorder.isRecording) {
      recorderStop(recorder).then((_) {
        cancelRecorderSubscriptions(from: 'dispose', stopRecorder: true);
      });
    } else {
      cancelRecorderSubscriptions(from: 'dispose', stopRecorder: true);
    }

    recorderController.dispose();
    // Be careful : you must `close` the audio session when you have finished with it.
    recorder.closeRecorder();
    // recordPlugin?.dispose();
    super.dispose();
  }
}
