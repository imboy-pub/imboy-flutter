<!-- Generated: 2026-04-10 | Files scanned: 283 (pages) + 111 (components) | Token estimate: ~800 -->

# Frontend Architecture

## Page Tree (22 modules, 283 files)
```
page/
├── chat/              39  C2C/C2G messaging, message display
├── mine/              50  Profile, settings, collections, devices
├── group/             45  Group CRUD, members, settings, albums
├── contact/           29  Contact list, friend requests
├── personal_info/     21  Profile editing, avatar
├── passport/          15  Login, registration, auth
├── user_tag/          14  User tags & categorization
├── settings/          13  App/E2EE settings
├── channel/           10  Channel browsing, subscription
├── live_room/          8  Live streaming
├── search/             7  Global search
├── conversation/       6  Conversation list
├── single/             6  Standalone screens
├── scanner/            4  QR scanning
├── moment/             4  Social feed
├── qrcode/             3  QR display
├── bottom_navigation/  3  Bottom nav controller
├── wallet/             2  Payment
├── discover/           1  Explore
├── mention/            1  @mention
├── splash/             1  Splash
└── welcome/            1  Welcome
```

## Component Hierarchy (111 files)
```
component/
├── ui/            28  Buttons, cards, dialogs, avatar, badges
├── chat/          23  Message bubbles, input, reactions, builders
├── webrtc/        20  Voice/video call UI + signaling
├── helper/        15  Image, date, validation, cachedImageProvider
├── http/           8  Dio client, interceptors, error handling
├── extension/      4  String, BuildContext, List extensions
├── location/       3  Amap integration, geolocation
├── voice_record/   2  Audio recording
├── image_gallery/  2  Gallery/media picker
└── video/          1  Video playback
```

## State Management Flow
```
ConsumerWidget
  → ref.watch(xxxProvider)     read state
  → ref.read(xxxProvider.notifier).action()  trigger mutation
  → Notifier updates state
  → Widget rebuilds

Key Providers:
  page/chat/chat/              chat_provider.dart (message list, send)
  page/conversation/           conversation_provider.dart (conv list)
  page/contact/                contact_provider.dart (contacts)
  service/                     websocket_status_provider.dart (WS state)
  service/                     message_providers.dart (msg processing)
```

## Navigation (go_router)
```
/                   → BottomNavigation (conv, contact, discover, mine)
/login              → LoginPage
/chat/:type/:id     → ChatPage (C2C or C2G)
/group/:id          → GroupDetailPage
/contact/add        → AddFriendPage
/settings/e2ee      → E2EE settings pages
/scanner            → QR scanner
/channel/:id        → ChannelDetailPage
```

## Chat Page Mixin Architecture
```
ChatPage (StatefulWidget)
  ├── ChatInitializationHandler   init & dispose
  ├── ChatMessageHandler          send/receive messages
  ├── ChatScrollHandler           scroll & pagination
  ├── ChatInputHandler            text input & media
  ├── ChatReactionHandler         emoji reactions
  ├── ChatSelectionHandler        multi-select
  ├── ChatMediaHandler            image/video/audio
  └── ChatWebRTCHandler           voice/video calls
```
