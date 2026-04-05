// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_tag_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ContactTagDetailNotifier)
final contactTagDetailProvider = ContactTagDetailNotifierProvider._();

final class ContactTagDetailNotifierProvider
    extends $NotifierProvider<ContactTagDetailNotifier, ContactTagDetailState> {
  ContactTagDetailNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactTagDetailProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactTagDetailNotifierHash();

  @$internal
  @override
  ContactTagDetailNotifier create() => ContactTagDetailNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactTagDetailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactTagDetailState>(value),
    );
  }
}

String _$contactTagDetailNotifierHash() =>
    r'20e7b90cc89f579eb7134a59ca4b4e13853228e3';

abstract class _$ContactTagDetailNotifier
    extends $Notifier<ContactTagDetailState> {
  ContactTagDetailState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ContactTagDetailState, ContactTagDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ContactTagDetailState, ContactTagDetailState>,
              ContactTagDetailState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
