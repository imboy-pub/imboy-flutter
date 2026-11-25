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
    r'378d67e34474318d6b1d9028db4439b7797ef802';

/// 联系人标签设置 Notifier

abstract class _$ContactSettingTagNotifier
    extends $Notifier<ContactSettingTagState> {
  ContactSettingTagState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
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
    return element.handleCreate(ref, build);
  }
}
