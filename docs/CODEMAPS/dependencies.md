<!-- Generated: 2026-04-10 | Dependencies: 80+ packages | Token estimate: ~600 -->

# Dependencies Map

## External Services
```
Backend (Erlang/OTP):  ../imboy/     WebSocket + REST API
Sentry:                sentry_flutter 8.12   Error tracking
Firebase:              firebase_messaging 15.2  Push notifications (FCM)
Amap:                  amap_flutter_*        Maps & geolocation (China)
JiGuang:               plugin/jverify/       Phone verification SDK
```

## Core Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| flutter_riverpod | 3.3.1 | State management |
| go_router | 17.0.1 | Navigation/routing |
| dio | 5.9.2 | HTTP client (HTTP/2) |
| web_socket_channel | 3.0.3 | WebSocket transport |
| sqflite_sqlcipher | 3.4.0 | Encrypted SQLite |
| flutter_secure_storage | 10.0.0 | Secure key/token storage |
| shared_preferences | 2.5.4 | Non-sensitive preferences |
| pointycastle | 4.0.0 | Cryptography (RSA, AES) |
| jose | 0.3.5 | JWT handling |

## UI Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| flutter_screenutil | 5.9.3 | Screen adaptation |
| flutter_animate | 4.5.2 | Animations |
| google_fonts | 8.0.2 | Typography |
| dynamic_color | 1.7.0 | Material 3 colors |
| emoji_picker_flutter | 4.4.0 | Emoji keyboard |
| flutter_markdown | 0.7.7 | Markdown rendering |
| qr_flutter | 4.1.0 | QR code display |

## Media Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| wechat_camera_picker | 4.5.0 | Camera (WeChat-style) |
| wechat_assets_picker | 10.1.1 | Gallery picker |
| video_player | 2.11.1 | Video playback |
| video_compress | 3.1.4 | Video compression |
| flutter_sound | 9.30.0 | Audio recording |
| flutter_webrtc | 1.3.1 | Voice/video calls |
| just_audio | 0.9.46 | Audio playback |

## Embedded Plugins (plugin/)
```
flutter_chat_ui/    Custom chat UI with 8 message-type packages
jverify/            JiGuang phone verification
r_upgrade/          In-app upgrade
```

## Dev Dependencies
| Package | Purpose |
|---------|---------|
| build_runner 2.12.2 | Code generation runner |
| riverpod_generator 4.0.2 | Riverpod codegen |
| envied_generator 1.3.2 | Env var codegen |
| mocktail 1.0.4 | Mocking (no codegen) |
| mockito 5.4.6 | Mocking (with codegen) |
| integration_test | E2E testing |

## Cross-Platform SQLite Stack
```
iOS/Android/macOS → sqflite_sqlcipher (native, encrypted)
Windows/Linux     → sqflite_common_ffi (FFI, plaintext for now)
Web               → sqflite_common_ffi_web (WASM, plaintext)
```
