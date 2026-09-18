import FlutterMacOS

/// Local no-op shim (hardening2 A4 build fix): upstream flutter_sound 9.30.0
/// declares a macOS plugin class but ships no macOS implementation. The
/// GeneratedPluginRegistrant references FlutterSoundPlugin at link time, so a
/// real class symbol is required; all method calls answer NotImplemented.
public class FlutterSoundPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "xyz.canardoux.fluttersound/noop_shim",
      binaryMessenger: registrar.messenger)
    let instance = FlutterSoundPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(FlutterMethodNotImplemented)
  }
}
