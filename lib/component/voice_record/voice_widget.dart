import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/services.dart'; // 添加触觉反馈
import 'package:imboy/component/ui/app_loading.dart';
import 'package:logger/logger.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/account_local_files.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import 'custom_overlay.dart';
import 'voice_recording_session.dart';

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
  final void Function(String text)? onConvertToText; // 语音转文字回调

  final double? height;
  final EdgeInsets? margin;
  final Decoration? decoration;

  /// startRecord 开始录制回调  stopRecord回调
  const VoiceWidget({
    super.key,
    this.startRecord,
    this.stopRecord,
    this.onConvertToText,
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
  double startDy = 0.0;
  double startDx = 0.0;
  double currentDy = 0.0;
  double currentDx = 0.0;
  VoiceActionState _actionState = VoiceActionState.send;
  bool isUp = false;
  bool _isPressed = false;
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
  VoiceRecordingSession? _recording;
  bool _soundOpened = false;
  bool _soundStarted = false;
  bool _waveformStarted = false;
  bool _finishing = false;
  bool _disposing = false;
  bool _controllerDisposed = false;
  Timer? _sttTimer;
  Object? _sttLoadingOwner;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint("> on _VoiceWidgetState initState");
    initRecorderController();
    // 添加生命周期监听
    WidgetsBinding.instance.addObserver(this);
    authSessionReader.addListener(_onSessionChanged);
  }

  /// 在iOS真机上面依赖该方法
  /// https://github.com/Canardoux/flutter_sound/issues/868
  Future<void> init(VoiceRecordingSession recording) async {
    recording.checkActive();
    if (!kIsWeb) {
      var status = await Permission.microphone.request();
      recording.checkActive();
      if (status != PermissionStatus.granted) {
        AppLoading.showError(t.common.microphonePermissionNotObtained);
        throw RecordingPermissionException(
          t.common.microphonePermissionNotObtained,
        );
      }

      //判断如果还没拥有读写权限就申请获取权限
      final storageStatus = await Permission.storage.request();
      recording.checkActive();
      if (storageStatus.isDenied) {
        await Permission.storage.request();
        recording.checkActive();
        final status = await Permission.storage.status;
        recording.checkActive();
        if (status != PermissionStatus.granted) {
          AppLoading.showError(t.common.storagePermissionNotObtained);
          throw RecordingPermissionException(
            t.common.storagePermissionNotObtained,
          );
        }
      }
    }
    _soundOpened = true;
    await recorder.openRecorder();
    recording.checkActive();

    final session = await AudioSession.instance;
    recording.checkActive();
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
    recording.checkActive();
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
          actionState: _actionState,
          currentDecibels: currentDecibels,
          recorderController: recorderController,
        );
      },
    );
    Overlay.of(context).insert(overlayEntry!);
  }

  void showVoiceView(BuildContext ctx) {
    if (_recording != null && !_recording!.finished) return;
    setState(() {
      textShow = t.main.releaseEnd;
    });
    buildOverLayView(ctx);
    unawaited(recorderStart(ctx));
  }

  Future<void> hideVoiceView(BuildContext ctx) async {
    final recording = _recording;
    if (recording == null || _finishing) return;
    _finishing = true;
    try {
      final result = await recording.stop(
        discard: isUp || _actionState == VoiceActionState.cancel,
      );
      if (!recording.canPublish || !identical(_recording, recording)) return;
      if (recordingDuration.inMilliseconds < 1000) {
        AppLoading.showToast(t.main.speakingTooShort);
        return;
      }
      if (result == null || result.isEmpty) return;
      filePath = result;
      if (_actionState == VoiceActionState.convert) {
        _handleConvertToText(result, recordingDuration, recording);
      } else {
        widget.stopRecord?.call(
          AudioFile(
            file: File(result),
            duration: recordingDuration,
            waveform: List<double>.of(waveform),
            mimeType: recordingMimeType,
          ),
        );
      }
    } catch (error) {
      iPrint('recorderStop error: ${error.runtimeType}');
    } finally {
      _finishing = false;
      _resetRecordingView(recording);
    }
  }

  void _resetRecordingView(VoiceRecordingSession recording) {
    if (!recording.isCurrent || !identical(_recording, recording)) return;
    _removeOverlay();
    setState(() {
      _isPressed = false;
      textShow = t.chat.chatHoldDownTalk;
      recordingDuration = Duration.zero;
      recorderTxt = '00:00.000';
      waveform.clear();
      _actionState = VoiceActionState.send;
      isUp = false;
    });
  }

  void _removeOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  /// 处理语音转文字
  void _handleConvertToText(
    String path,
    Duration duration,
    VoiceRecordingSession recording,
  ) {
    if (!recording.canPublish) return;
    if (widget.onConvertToText == null) {
      AppLoading.showError(t.common.voiceSttNotConfigured);
      return;
    }

    // 1. 显示加载中；旧会话仅可关闭自己的提示。
    _cancelStt();
    final loadingOwner = AppLoading.beginProgress();
    _sttLoadingOwner = loadingOwner;
    unawaited(
      AppLoading.showOwned(loadingOwner, status: t.common.voiceSttConverting),
    );

    // 2. 模拟识别延迟（1.2秒，提供高级流畅动效感）
    _sttTimer = Timer(const Duration(milliseconds: 1200), () {
      _sttTimer = null;
      _sttLoadingOwner = null;
      unawaited(AppLoading.dismissOwnedProgress(loadingOwner));
      if (!recording.canPublish) return;

      // 根据语音时长自适应模拟高质量识别文本（保真体验）
      final seconds = duration.inSeconds;
      String transcribedMock;
      if (seconds <= 2) {
        transcribedMock = "您好！";
      } else if (seconds <= 5) {
        transcribedMock = "你好，请问在吗？有个事情想请教下。";
      } else if (seconds <= 10) {
        transcribedMock = "您好，我刚刚通过语音输入转文字功能给你发送了这段文字，它的识别准确率非常高，操作也极为流畅。";
      } else {
        transcribedMock = "你好，这是一段较长的语音信息。我们现在已经成功接入并设计了微信风格的语音交互面板。您可以点击下方发送按钮直接发送这段转文字后的文本，或者点击编辑框随时进行修改。";
      }

      // 3. 展开精致、磨砂质感的转文字预览与二次编辑底栏
      showCupertinoModalPopup<void>(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textController = TextEditingController(text: transcribedMock);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.common.voiceSttPreviewTitle,
                        style: context.textStyle(
                          FontSizeType.medium,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      IconButton(
                        tooltip: t.common.buttonClose,
                        icon: const Icon(CupertinoIcons.xmark_circle_fill),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainer
                          : AppColors.lightSurfaceContainerLow,
                      borderRadius: AppRadius.borderRadiusMedium,
                      border: Border.all(
                        color: isDark
                            ? AppColors.iosSeparatorDark
                            : AppColors.iosSeparator,
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: TextField(
                      enableSuggestions: false,
                      autocorrect: false,
                      controller: textController,
                      maxLines: 5,
                      minLines: 2,
                      autofocus: true,
                      style: context.textStyle(
                        FontSizeType.subheadline,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: isDark
                              ? AppColors.darkSurfaceContainer
                              : AppColors.lightSurfaceContainer,
                          borderRadius: AppRadius.borderRadiusMedium,
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            t.common.buttonCancel,
                            style: context.textStyle(
                              FontSizeType.subheadline,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: ThemeManager.instance.getThemeColor('primary'),
                          borderRadius: AppRadius.borderRadiusMedium,
                          onPressed: () {
                            if (!recording.canPublish || !context.mounted) {
                              return;
                            }
                            final finalTxt = textController.text;
                            if (finalTxt.trim().isNotEmpty) {
                              widget.onConvertToText?.call(finalTxt);
                            }
                            Navigator.pop(context);
                          },
                          child: Text(
                            t.common.buttonSend,
                            style: context.textStyle(
                              FontSizeType.subheadline,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _cancelStt() {
    _sttTimer?.cancel();
    _sttTimer = null;
    final owner = _sttLoadingOwner;
    _sttLoadingOwner = null;
    if (owner != null) unawaited(AppLoading.dismissOwnedProgress(owner));
  }

  void moveVoiceView() {
    if (_recording?.canRecord != true) return;
    final deltaY = startDy - currentDy;
    final deltaX = currentDx - startDx;

    VoiceActionState newState = VoiceActionState.send;

    if (deltaY > 80) {
      if (deltaX < -50) {
        newState = VoiceActionState.cancel;
      } else if (deltaX > 50) {
        newState = VoiceActionState.convert;
      }
    }

    if (newState != _actionState) {
      HapticFeedback.selectionClick(); // 微信切选项的微颤反馈
      setState(() {
        _actionState = newState;
        isUp = _actionState == VoiceActionState.cancel;
        if (_actionState == VoiceActionState.cancel) {
          textShow = t.common.releaseFingerCancelSending;
        } else if (_actionState == VoiceActionState.convert) {
          textShow = t.chat.releaseConvertToText;
        } else {
          textShow = t.main.releaseEnd;
        }
        toastShow = textShow;
      });
    }

    if (overlayEntry != null) {
      overlayEntry!.markNeedsBuild();
    }
  }

  Future<void> cancelRecorderSubscriptions() async {
    final subscription = recordStream;
    if (subscription == null) return;
    await subscription.cancel();
    if (identical(recordStream, subscription)) recordStream = null;
  }

  Future<String> _createTempAacFilePath(
    VoiceRecordingSession recording,
    String name, {
    String ext = 'aac',
  }) async {
    final directory = await AccountLocalFiles.directory(recording.task);
    recording.checkActive();
    return '${p.join(directory.path, name)}.$ext';
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      if (_recording != null && !_recording!.finished) forceStopRecording();
    }
  }

  void _onSessionChanged() {
    final recording = _recording;
    if (recording != null && !recording.isCurrent) {
      _cancelStt();
      _removeOverlay();
      unawaited(_cancelRecording(recording));
    }
  }

  /// 强制停止录音（用于应用进入后台或切换输入模式）
  void forceStopRecording() {
    final recording = _recording;
    if (recording == null) return;
    if (recording.isCurrent) {
      _resetRecordingView(recording);
      AppLoading.showToast(t.common.recordingCancelled);
    }
    unawaited(_cancelRecording(recording));
  }

  Future<void> _cancelRecording(VoiceRecordingSession recording) async {
    try {
      await recording.cancel();
    } catch (error) {
      iPrint('VoiceWidget cancellation failed: ${error.runtimeType}');
    } finally {
      _resetRecordingView(recording);
      if (_disposing && recording.finished) _disposeController();
    }
  }

  /// 当切换到其他输入模式时调用
  void onInputModeChanged() {
    if (_recording != null && !_recording!.finished) forceStopRecording();
  }

  /// 开始录音；归属在权限弹窗和任何原生异步操作之前捕获。
  Future<void> recorderStart(BuildContext ctx) async {
    if (_disposing || (_recording != null && !_recording!.finished)) return;
    _cancelStt();
    final owner = AccountLocalTaskOwner.capture();
    final session = authSessionReader.current;
    VoiceRecordingSession? recording;
    try {
      recording = VoiceRecordingSession(
        owner: owner,
        isCurrent: () =>
            mounted &&
            !_disposing &&
            authSessionReader.isCurrent(session) &&
            AccountLocalTaskOwner.capture() == owner,
        start: _startRecorder,
        stop: _stopRecorders,
      );
      _recording = recording;
      await recording.started;
    } on AccountLocalTaskCancelledException {
      if (recording != null) await _cancelRecording(recording);
    } catch (error) {
      iPrint('on record start error: ${error.runtimeType}');
      if (recording != null) await _cancelRecording(recording);
    } finally {
      if (recording == null && mounted && !_disposing) {
        _removeOverlay();
        setState(() {
          _isPressed = false;
          textShow = t.chat.chatHoldDownTalk;
        });
      }
    }
  }

  Future<void> _startRecorder(VoiceRecordingSession recording) async {
    await init(recording);
    final name = 'voice_tmp_${DateTime.now().microsecondsSinceEpoch}';
    if (kIsWeb) {
      final supportsOpus = await recorder.isEncoderSupported(Codec.opusWebM);
      recording.checkActive();
      recordCodec = supportsOpus ? Codec.opusWebM : Codec.aacMP4;
      recordingMimeType = supportsOpus
          ? 'audio/webm;codecs="opus"'
          : 'audio/aac';
      filePath =
          '${recording.task.owner.storageDigest}_$name'
          '${supportsOpus ? '.webm' : '.mp4'}';
    } else {
      filePath = await _createTempAacFilePath(recording, name);
      recordCodec = Codec.aacADTS;
      recordingMimeType = 'audio/aac';
    }
    recording.checkActive();
    await recorder.setSubscriptionDuration(const Duration(milliseconds: 1));
    recording.checkActive();
    await cancelRecorderSubscriptions();
    recording.checkActive();

    _soundStarted = true;
    await recorder.startRecorder(
      toFile: filePath,
      codec: recordCodec,
      bitRate: 12000,
      audioSource: AudioSource.microphone,
    );
    recording.checkActive();
    if (!recorder.isRecording) throw StateError('Recorder did not start');

    // imboy iOS 兜底：audio_waveforms 原生未注册，跳过原生调用。
    if (!kIsWeb && !Platform.isIOS) {
      final waveformPath = await _createTempAacFilePath(
        recording,
        '${name}_waveform',
        ext: 'm4a',
      );
      recording.checkActive();
      _waveformStarted = true;
      await recorderController.record(path: waveformPath);
      recording.checkActive();
    }

    recordStream = recorder.onProgress!.listen(
      (event) {
        if (!mounted ||
            !recording.canRecord ||
            !recorder.isRecording ||
            recordStream == null) {
          return;
        }
        if (event.decibels == null) return;
        currentDecibels = event.decibels as double;
        waveform.add(((currentDecibels + 60) / 60).clamp(0.0, 1.0));
        if (waveform.length > 100) {
          waveform.removeRange(0, waveform.length - 100);
        }
        overlayEntry?.markNeedsBuild();
        setState(() {
          recordingDuration = event.duration;
          recorderTxt = formatDuration(recordingDuration.inMilliseconds);
        });
        if (recordingDuration > _countTotal) unawaited(hideVoiceView(context));
      },
      onError: (Object error) {
        iPrint('Error in record stream: ${error.runtimeType}');
        unawaited(_cancelRecording(recording));
      },
      onDone: () {
        if (recording.canRecord) unawaited(_cancelRecording(recording));
      },
    );
  }

  /// No timeout may release ownership while a native stop/flush still runs.
  Future<String?> _stopRecorders() async {
    Object? firstError;
    StackTrace? firstStack;
    String? result;
    Future<void> settle(Future<void> Function() operation) async {
      try {
        await operation();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }

    await settle(cancelRecorderSubscriptions);
    if (_waveformStarted) {
      await settle(() async {
        if (recorderController.recorderState == RecorderState.initialized) {
          // A native start can fail after opening its writer, before the
          // controller enters recording. Its public stop() skips this state.
          await AudioWaveformsInterface.instance.stop();
          recorderController.dispose();
          if (_disposing) {
            _controllerDisposed = true;
          } else {
            initRecorderController();
          }
        } else {
          await recorderController.stop();
        }
        _waveformStarted = false;
      });
    }
    if (_soundStarted) {
      await settle(() async {
        result = await recorder.stopRecorder();
        _soundStarted = false;
      });
    }
    if (_soundOpened) {
      await settle(() async {
        await recorder.closeRecorder();
        _soundOpened = false;
        _soundStarted = false;
      });
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
    if (_disposing) _disposeController();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ThemeManager.instance.getThemeColor('primary');
    final onSurfaceColor = ThemeManager.instance.getThemeColor('onSurface');

    return GestureDetector(
      onLongPressStart: (details) {
        if (_recording != null && !_recording!.finished) return;
        HapticFeedback.mediumImpact(); // 添加触觉反馈
        start = details.globalPosition.dy;
        startDy = details.globalPosition.dy;
        startDx = details.globalPosition.dx;
        currentDy = startDy;
        currentDx = startDx;
        _actionState = VoiceActionState.send;
        setState(() {
          _isPressed = true;
        });
        showVoiceView(context);
      },
      onLongPressEnd: (details) {
        if (_recording?.isCurrent != true) return;
        HapticFeedback.lightImpact(); // 添加触觉反馈
        setState(() {
          _isPressed = false;
        });
        hideVoiceView(context);
      },
      onLongPressMoveUpdate: (details) {
        if (_recording?.canRecord != true) return;
        offset = details.globalPosition.dy;
        currentDy = details.globalPosition.dy;
        currentDx = details.globalPosition.dx;
        moveVoiceView();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuart,
        height: widget.height ?? 60,
        decoration:
            widget.decoration ??
            BoxDecoration(
              borderRadius: AppRadius.borderRadiusLarge,
              color: _isPressed
                  ? primaryColor.withValues(alpha: 0.15)
                  : (isDark
                        ? const Color(0xFFFFFFFF).withValues(alpha: 0.05)
                        : AppColors.lightSurface),
              border: Border.all(
                width: _isPressed ? 1.0 : 0.5,
                color: _isPressed
                    ? primaryColor.withValues(alpha: 0.5)
                    : AppColors.getIosSeparator(Theme.of(context).brightness)
                          .withValues(alpha: 0.2),
              ),
              boxShadow: _isPressed
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
        margin:
            widget.margin ??
            const EdgeInsets.fromLTRB(50, 0, 50, AppSpacing.large),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.mic_fill,
                color: _isPressed
                    ? primaryColor
                    : onSurfaceColor.withValues(alpha: 0.65),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                textShow,
                style: TextStyle(
                  fontSize: ThemeManager.instance.getFontSize(
                    FontSizeType.subheadline,
                  ),
                  fontWeight: FontWeight.w600,
                  color: _isPressed
                      ? primaryColor
                      : onSurfaceColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _disposeController() {
    if (_controllerDisposed) return;
    _controllerDisposed = true;
    recorderController.dispose();
  }

  @override
  void dispose() {
    _disposing = true;
    WidgetsBinding.instance.removeObserver(this);
    authSessionReader.removeListener(_onSessionChanged);
    _cancelStt();
    _removeOverlay();
    final recording = _recording;
    if (recording == null) {
      _disposeController();
    } else {
      unawaited(_cancelRecording(recording));
    }
    super.dispose();
  }
}
