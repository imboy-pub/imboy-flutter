// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_setting_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 联系人设置 Notifier

@ProviderFor(ContactSettingNotifier)
final contactSettingProvider = ContactSettingNotifierProvider._();

/// 联系人设置 Notifier
final class ContactSettingNotifierProvider
    extends $NotifierProvider<ContactSettingNotifier, ContactSettingState> {
  /// 联系人设置 Notifier
  ContactSettingNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactSettingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactSettingNotifierHash();

  @$internal
  @override
  ContactSettingNotifier create() => ContactSettingNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactSettingState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactSettingState>(value),
    );
  }
}

String _$contactSettingNotifierHash() =>
    r'f5579b6c683143400fdd7998bbeccdbe30f04fa4';

/// 联系人设置 Notifier

abstract class _$ContactSettingNotifier extends $Notifier<ContactSettingState> {
  ContactSettingState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ContactSettingState, ContactSettingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ContactSettingState, ContactSettingState>,
              ContactSettingState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
