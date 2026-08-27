// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rtc_room_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RtcRoomNotifier)
final rtcRoomProvider = RtcRoomNotifierProvider._();

final class RtcRoomNotifierProvider
    extends $NotifierProvider<RtcRoomNotifier, RtcRoomState> {
  RtcRoomNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rtcRoomProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rtcRoomNotifierHash();

  @$internal
  @override
  RtcRoomNotifier create() => RtcRoomNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RtcRoomState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RtcRoomState>(value),
    );
  }
}

String _$rtcRoomNotifierHash() => r'08d5573c95f6645952860c5b5a2f03f973c83f97';

abstract class _$RtcRoomNotifier extends $Notifier<RtcRoomState> {
  RtcRoomState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<RtcRoomState, RtcRoomState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RtcRoomState, RtcRoomState>,
              RtcRoomState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
