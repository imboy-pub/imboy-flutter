<!-- Generated: 2026-04-10 | Files scanned: 637 (lib/) + 133 (test/) | Token estimate: ~900 -->

# Architecture Overview

## System Type
Single Flutter application (cross-platform IM) with embedded plugins.

## Tech Stack
| Layer | Tech | Pattern |
|-------|------|---------|
| Presentation | Flutter 3.8+ / Material 3 | MVVM |
| State | Riverpod 3.3.1 (100% migrated from GetX) | Provider |
| Routing | go_router 17.0.1 | Declarative |
| Data | Repository + SQLite (SQLCipher encrypted) | Clean Architecture |
| Network | Dio 5.9 (HTTP/2) + WebSocket | REST + Real-time |
| Crypto | E2EE (RSA+AES), Shamir Secret Sharing | Zero-trust |
| i18n | slang 4.14 (code-gen) | 11 languages |
| Platform | iOS, Android, macOS, Web | Cross-platform |

## Data Flow
```
User Action
  → Page (ConsumerWidget)
    → Provider/Notifier (Riverpod)
      → Repository (SQLite) ──┐
      → API Client (Dio/HTTP) ├→ Model
      → WebSocket (real-time)  ┘
    ← State Update
  ← UI Rebuild
```

## Module Map (lib/)
```
lib/                    637 files
├── page/               283  Screen/route views (22 feature modules)
├── component/          111  Reusable widgets & helpers
├── store/               72  API(32) + Model(25) + Repo(15)
├── service/             71  Core services (WS, msg, DB, E2EE)
├── config/              17  Env, init, routing, constants
├── modules/             14  Domain modules (messaging, security)
├── theme/               13  Colors, typography, spacing
├── i18n/                11  Generated translation files
├── app_core/             3  Feature flags, routing guards
├── utils/                2  TSID, conversation key gen
├── main.dart                Entry point (Sentry init)
└── run.dart                 Alt entry (global error handlers)
```

## Plugin Structure
```
plugin/
├── flutter_chat_ui/   107  Custom chat UI (8 message-type sub-packages)
├── jverify/             5  JiGuang verification SDK
└── r_upgrade/           8  App upgrade functionality
```

## Key Architectural Decisions
- SQLCipher AES-256 encryption for all local data (forced, no opt-out)
- Per-user DB isolation: `{env}_{uid}.db`
- Message types: C2C, C2G, C2S, S2C via WebSocket
- WebRTC for voice/video calls
- Offline-first: persistent message queue + offline sync
