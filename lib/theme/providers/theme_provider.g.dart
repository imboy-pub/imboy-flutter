// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// MaterialApp mode is a projection of the same persisted theme state.

@ProviderFor(ThemeModeNotifier)
final themeModeProvider = ThemeModeNotifierProvider._();

/// MaterialApp mode is a projection of the same persisted theme state.
final class ThemeModeNotifierProvider
    extends $NotifierProvider<ThemeModeNotifier, ThemeMode> {
  /// MaterialApp mode is a projection of the same persisted theme state.
  ThemeModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeNotifierHash();

  @$internal
  @override
  ThemeModeNotifier create() => ThemeModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeNotifierHash() => r'a957f2e6c908c22d22481dfcf8ce5c01e6c900a7';

/// MaterialApp mode is a projection of the same persisted theme state.

abstract class _$ThemeModeNotifier extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 主题管理器 Provider
///
/// 使用 Riverpod 管理主题状态，支持亮色/暗色模式切换、字体缩放等功能

@ProviderFor(ThemeNotifier)
final themeProvider = ThemeNotifierProvider._();

/// 主题管理器 Provider
///
/// 使用 Riverpod 管理主题状态，支持亮色/暗色模式切换、字体缩放等功能
final class ThemeNotifierProvider
    extends $NotifierProvider<ThemeNotifier, ThemeState> {
  /// 主题管理器 Provider
  ///
  /// 使用 Riverpod 管理主题状态，支持亮色/暗色模式切换、字体缩放等功能
  ThemeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeNotifierHash();

  @$internal
  @override
  ThemeNotifier create() => ThemeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeState>(value),
    );
  }
}

String _$themeNotifierHash() => r'8aa223c4b0512e64ca7a7a47e3f7afd9b28fe720';

/// 主题管理器 Provider
///
/// 使用 Riverpod 管理主题状态，支持亮色/暗色模式切换、字体缩放等功能

abstract class _$ThemeNotifier extends $Notifier<ThemeState> {
  ThemeState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeState, ThemeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeState, ThemeState>,
              ThemeState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
