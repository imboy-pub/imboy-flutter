import FlutterMacOS
import flutter_sound

// 临时修复类：将 FlutterSoundPlugin 路由到 TaudioPlugin
// 这是一个解决方案，因为 flutter_sound 9.30.0 的 macOS 实现使用 TaudioPlugin
// 但生成的代码期望的是 FlutterSoundPlugin
public class FlutterSoundPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // 直接调用实际的 TaudioPlugin 注册方法
    TaudioPlugin.register(with: registrar)
  }
}