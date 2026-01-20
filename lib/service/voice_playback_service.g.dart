// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_playback_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 语音播放服务

@ProviderFor(VoicePlaybackService)
final voicePlaybackServiceProvider = VoicePlaybackServiceProvider._();

/// 语音播放服务
final class VoicePlaybackServiceProvider
    extends $NotifierProvider<VoicePlaybackService, VoicePlaybackState> {
  /// 语音播放服务
  VoicePlaybackServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voicePlaybackServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voicePlaybackServiceHash();

  @$internal
  @override
  VoicePlaybackService create() => VoicePlaybackService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoicePlaybackState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoicePlaybackState>(value),
    );
  }
}

String _$voicePlaybackServiceHash() =>
    r'cd9edade6ad69588a637322668be9ab92bbcc99e';

/// 语音播放服务

abstract class _$VoicePlaybackService extends $Notifier<VoicePlaybackState> {
  VoicePlaybackState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<VoicePlaybackState, VoicePlaybackState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VoicePlaybackState, VoicePlaybackState>,
              VoicePlaybackState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
