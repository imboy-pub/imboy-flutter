import 'package:flutter/services.dart';
import 'package:imboy/service/app_logger.dart';

class SoundManager {
  static const MethodChannel _channel = MethodChannel('imboy/sound');

  static Future<void> playKeyPressSound() async {
    try {
      await _channel.invokeMethod('playKeyPressSound');
    } on PlatformException catch (e) {
      AppLogger.warning("Failed to play key press sound: '${e.message}'.");
    } on MissingPluginException catch (e) {
      AppLogger.warning(
        "Key press sound plugin not implemented: '${e.message}'.",
      );
    } catch (e) {
      AppLogger.warning("Unexpected error playing key press sound: $e");
    }
  }

  static Future<void> playMetallicSound() async {
    try {
      await _channel.invokeMethod('playMetallicSound');
    } on PlatformException catch (e) {
      AppLogger.warning("Failed to play metallic sound: '${e.message}'.");
    } on MissingPluginException catch (e) {
      AppLogger.warning(
        "Metallic sound plugin not implemented: '${e.message}'.",
      );
    } catch (e) {
      AppLogger.warning("Unexpected error playing metallic sound: $e");
    }
  }
}
