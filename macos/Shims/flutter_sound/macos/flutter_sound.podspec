Pod::Spec.new do |s|
  s.name             = 'flutter_sound'
  s.version          = '9.30.0'
  s.summary          = 'Local no-op macOS shim for flutter_sound.'
  s.description      = 'flutter_sound 9.30.0 declares pluginClass FlutterSoundPlugin for macOS but ships no macos/ implementation, so pod install fails. This local shim satisfies GeneratedPluginRegistrant link-time reference without changing app behavior; runtime method calls return FlutterMethodNotImplemented.'
  s.homepage         = 'https://example.invalid/ignored'
  s.license          = { :type => 'MPL-2.0' }
  s.author           = { 'imboy' => 'leeyisoft@qq.com' }
  s.source           = { :path => '.' }
  s.dependency 'FlutterMacOS'
  s.osx.deployment_target = '10.14'
  s.swift_version = '5.0'
  s.source_files     = 'Classes/**/*'
end
