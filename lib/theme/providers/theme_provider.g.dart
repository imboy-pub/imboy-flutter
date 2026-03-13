// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ThemeMode Provider - 用于 MaterialApp.themeMode
///
/// 这是从本地存储读取的主题模式

@ProviderFor(ThemeModeNotifier)
final themeModeProvider = ThemeModeNotifierProvider._();

/// ThemeMode Provider - 用于 MaterialApp.themeMode
///
/// 这是从本地存储读取的主题模式
final class ThemeModeNotifierProvider
    extends $NotifierProvider<ThemeModeNotifier, ThemeMode> {
  /// ThemeMode Provider - 用于 MaterialApp.themeMode
  ///
  /// 这是从本地存储读取的主题模式
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

String _$themeModeNotifierHash() => r'eeedb110ba8066ed5d12363c9cdf4d5b20ede5e0';

/// ThemeMode Provider - 用于 MaterialApp.themeMode
///
/// 这是从本地存储读取的主题模式

abstract class _$ThemeModeNotifier extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
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

String _$themeNotifierHash() => r'076788c2a3ae85d5d460eef73488b53b5d080c2b';

/// 主题管理器 Provider
///
/// 使用 Riverpod 管理主题状态，支持亮色/暗色模式切换、字体缩放等功能

abstract class _$ThemeNotifier extends $Notifier<ThemeState> {
  ThemeState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ThemeState, ThemeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeState, ThemeState>,
              ThemeState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
