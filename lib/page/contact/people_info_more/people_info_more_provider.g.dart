// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'people_info_more_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 更多个人信息状态通知器

@ProviderFor(PeopleInfoMoreNotifier)
final peopleInfoMoreProvider = PeopleInfoMoreNotifierProvider._();

/// 更多个人信息状态通知器
final class PeopleInfoMoreNotifierProvider
    extends $NotifierProvider<PeopleInfoMoreNotifier, PeopleInfoMoreState> {
  /// 更多个人信息状态通知器
  PeopleInfoMoreNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'peopleInfoMoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$peopleInfoMoreNotifierHash();

  @$internal
  @override
  PeopleInfoMoreNotifier create() => PeopleInfoMoreNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PeopleInfoMoreState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PeopleInfoMoreState>(value),
    );
  }
}

String _$peopleInfoMoreNotifierHash() =>
    r'5f7d5ec007035f29fd9481af38727e131e11f98e';

/// 更多个人信息状态通知器

abstract class _$PeopleInfoMoreNotifier extends $Notifier<PeopleInfoMoreState> {
  PeopleInfoMoreState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PeopleInfoMoreState, PeopleInfoMoreState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PeopleInfoMoreState, PeopleInfoMoreState>,
              PeopleInfoMoreState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
