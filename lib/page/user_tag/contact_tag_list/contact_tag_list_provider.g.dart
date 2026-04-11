// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_tag_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ContactTagListNotifier)
final contactTagListProvider = ContactTagListNotifierProvider._();

final class ContactTagListNotifierProvider
    extends $NotifierProvider<ContactTagListNotifier, ContactTagListState> {
  ContactTagListNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactTagListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactTagListNotifierHash();

  @$internal
  @override
  ContactTagListNotifier create() => ContactTagListNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactTagListState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactTagListState>(value),
    );
  }
}

String _$contactTagListNotifierHash() =>
    r'80fa653ff35dea2ef4252c7f366d7e210ca08790';

abstract class _$ContactTagListNotifier extends $Notifier<ContactTagListState> {
  ContactTagListState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ContactTagListState, ContactTagListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ContactTagListState, ContactTagListState>,
              ContactTagListState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
