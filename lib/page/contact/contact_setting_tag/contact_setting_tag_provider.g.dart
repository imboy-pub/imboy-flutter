// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_setting_tag_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 联系人标签设置 Notifier

@ProviderFor(ContactSettingTagNotifier)
final contactSettingTagProvider = ContactSettingTagNotifierProvider._();

/// 联系人标签设置 Notifier
final class ContactSettingTagNotifierProvider
    extends
        $NotifierProvider<ContactSettingTagNotifier, ContactSettingTagState> {
  /// 联系人标签设置 Notifier
  ContactSettingTagNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactSettingTagProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactSettingTagNotifierHash();

  @$internal
  @override
  ContactSettingTagNotifier create() => ContactSettingTagNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactSettingTagState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactSettingTagState>(value),
    );
  }
}

String _$contactSettingTagNotifierHash() =>
    r'2e76662e484a54a4eeba779adb67aebb6a673409';

/// 联系人标签设置 Notifier

abstract class _$ContactSettingTagNotifier
    extends $Notifier<ContactSettingTagState> {
  ContactSettingTagState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<ContactSettingTagState, ContactSettingTagState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ContactSettingTagState, ContactSettingTagState>,
              ContactSettingTagState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
