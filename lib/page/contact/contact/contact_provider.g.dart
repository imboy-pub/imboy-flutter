// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ContactNotifier)
final contactProvider = ContactNotifierProvider._();

final class ContactNotifierProvider
    extends $NotifierProvider<ContactNotifier, ContactState> {
  ContactNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactNotifierHash();

  @$internal
  @override
  ContactNotifier create() => ContactNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactState>(value),
    );
  }
}

String _$contactNotifierHash() => r'47cade0969988be5de05624db07433e66f9af660';

abstract class _$ContactNotifier extends $Notifier<ContactState> {
  ContactState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ContactState, ContactState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ContactState, ContactState>,
              ContactState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(currentIndexBarData)
final currentIndexBarDataProvider = CurrentIndexBarDataProvider._();

final class CurrentIndexBarDataProvider
    extends $FunctionalProvider<Set<String>, Set<String>, Set<String>>
    with $Provider<Set<String>> {
  CurrentIndexBarDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentIndexBarDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentIndexBarDataHash();

  @$internal
  @override
  $ProviderElement<Set<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<String> create(Ref ref) {
    return currentIndexBarData(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$currentIndexBarDataHash() =>
    r'b39cbcde736260f12f172005ac1c191d99f6d91d';
