import 'package:flutter/services.dart';

class SoundManager {
  static const MethodChannel _channel = MethodChannel('imboy/sound');
  
  static Future<void> playKeyPressSound() async {
    try {
      await _channel.invokeMethod('playKeyPressSound');
    } on PlatformException catch (e) {
      print("Failed to play key press sound: '${e.message}'.");
    } on MissingPluginException catch (e) {
      print("Key press sound plugin not implemented: '${e.message}'.");
    } catch (e) {
      print("Unexpected error playing key press sound: $e");
    }
  }
  
  static Future<void> playMetallicSound() async {
    try {
      await _channel.invokeMethod('playMetallicSound');
    } on PlatformException catch (e) {
      print("Failed to play metallic sound: '${e.message}'.");
    } on MissingPluginException catch (e) {
      print("Metallic sound plugin not implemented: '${e.message}'.");
    } catch (e) {
      print("Unexpected error playing metallic sound: $e");
    }
  }
}
