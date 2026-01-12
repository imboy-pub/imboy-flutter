# Flutter UI/UX Implementation Roadmap for ImBoy App

This roadmap guides the transformation of the HTML/CSS UI Kit into a production-ready Flutter application.

## Phase 0: Architecture & Configuration (Week 1)

**Goal**: Establish a solid codebase foundation and folder structure.

### 0.1 Architecture Design
- [ ] **Architecture Pattern**: Decide on a pattern (e.g., MVVM, Clean Architecture, or MVC).
- [ ] **Folder Structure**: Set up a scalable structure.
  ```text
  lib/
  ├── config/          # Routes, Themes, Constants
  ├── core/            # Utils, Extensions, Base Classes
  ├── data/            # Models, Repositories, API Services
  ├── modules/         # Feature-based (Auth, Chat, Social, Wallet)
  │   ├── view/
  │   ├── controller/  # or bloc/provider
  │   └── widgets/
  └── widgets/         # Shared UI Components (Atoms/Molecules)
  ```

### 0.2 Project Configuration
- [ ] **Assets**: Create directories for `assets/images`, `assets/icons`, `assets/fonts`.
- [ ] **Localization (i18n)**: Setup `easy_localization` or `flutter_localizations`. Create initial `en.json` and `zh.json`.
- [ ] **Environment Config**: Setup flavors (dev, prod) if necessary.

## Phase 1: Foundation & Theming (Week 1-2)

**Goal**: Set up the design system, themes, and core widgets.

### 1.1 Project Dependencies
- [ ] Initialize Flutter project (already done).
- [ ] Add dependencies: `flutter_screenutil` (for responsive design), `google_fonts`.
- [ ] Choose and install a State Management solution (e.g., `get`, `provider`, `flutter_bloc`, or `flutter_riverpod`).
- [ ] Add Utility packages: `intl`, `logger`, `equatable` (if using Bloc).

### 1.2 Design System Implementation
- [ ] **Colors**: Create `AppColors` class matching the CSS variables.
  - Primary: `Color(0xFF059669)` (Emerald 600)
  - Dark Mode Primary: `Color(0xFF10B981)` (Emerald 500)
  - Backgrounds: Light `Color(0xFFF1F5F9)`, Dark `Color(0xFF0F172A)`
  - **Action**: Verify colors against `ui_kit_gallery.html`.
- [ ] **Typography**: Configure `TextTheme` with `Inter` font. Implement `AppTextStyles` for H1, H2, Body, Caption.
- [ ] **ThemeData**: Configure `lightTheme` and `darkTheme` in `MaterialApp` (or `GetMaterialApp`).
- [ ] **Font Size Controller**: Implement a `ThemeController` to handle dynamic font scaling (textFactor).

### 1.3 Core Components (Atoms)
- [ ] `ImBoyButton`: Custom button with variants (Primary, Secondary, Outline, Danger).
- [ ] `ImBoyInput`: Text field with decoration, icon support, and error states.
- [ ] `ImBoyAvatar`: Widget handling network images with initials fallback.
- [ ] `ImBoyListItem`: Generic list tile for settings and contacts.
- [ ] `ImBoyBadge`: Notification badge widget.

## Phase 2: Main Navigation & Structure (Week 2)

**Goal**: Implement the shell of the app (Bottom Tab, Navigation).

### 2.1 Navigation Structure
- [ ] Implement `BottomNavigationBar` with 4 tabs: Chats, Contacts, Discover, Me.
- [ ] **State Preservation**: Ensure tabs keep state when switching (use `PageStorage` or `IndexedStack`).
- [ ] Setup routing for named routes (e.g., `/chat`, `/profile`) using Flutter's native Navigator 2.0, `go_router`, or `GetX` routing.

### 2.2 Main Screens (Skeletons)
- [ ] **Chat List Screen**: `ListView` with `ImBoyListItem`. Handle Empty and Loading states.
- [ ] **Contact List Screen**: Grouped list with alphabet indexer (use `azlistview`).
- [ ] **Discover Screen**: List of entry points (Moments, Scan, etc.).
- [ ] **Profile Screen**: User info header and settings list.

## Phase 3: Chat Interface (Week 3-4)

**Goal**: A fully functional chat UI with different message types.

### 3.1 Chat Screen Scaffold
- [ ] `AppBar` with User/Group title, Online Status, and action buttons.
- [ ] `MessageList`: `ListView.builder` with `reverse: true`.
- [ ] **Scroll to Bottom**: Handle new message scroll behavior.

### 3.2 Message Bubbles
- [ ] `TextMessageBubble`: Auto-sizing bubble with time stamp and read receipt status.
- [ ] `ImageMessageBubble`: Image preview with hero animation.
- [ ] `VoiceMessageBubble`: Playback button, progress bar, and duration.
- [ ] `SystemMessageBubble`: Center-aligned gray text.
- [ ] `FileMessageBubble`: Icon, filename, and size.

### 3.3 Input Area (Bottom Bar)
- [ ] **Keyboard Handling**: Manage focus nodes and keyboard visibility/resize.
- [ ] Text input field with auto-expand (minLines: 1, maxLines: 5).
- [ ] Voice record button (hold to record animation).
- [ ] Emoji picker panel integration (custom or package).
- [ ] "+" Menu panel (Grid of actions: Camera, File, Location, etc.).

## Phase 4: Social & Moments (Week 5)

**Goal**: The "Moments" feed (similar to WeChat Moments/Instagram).

### 4.1 Feed UI
- [ ] `ParallaxHeader`: User cover photo and avatar with scroll listener.
- [ ] `PostItem`: Complex widget with text, expandable content, image grid (1-9 images).
- [ ] **Image Grid Logic**: Handle 1 image (large), 4 images (2x2), 9 images (3x3) layouts.

### 4.2 Interaction
- [ ] Like button animation.
- [ ] Comment input sheet (popup from bottom, handle keyboard avoidance).
- [ ] Image viewer (gallery view for multi-image posts, zoomable).

## Phase 5: Wallet & Settings (Week 6)

**Goal**: Utility pages and app configuration.

### 5.1 Wallet
- [ ] **Wallet Home**: Dashboard with balance and grid menu.
- [ ] **Cards**: Bank card list with gradient backgrounds (CSS-like styling).
- [ ] **Red Packet**: Custom UI for sending/receiving money (Animation for opening packet).

### 5.2 Settings & Profile
- [ ] **Settings Pages**: Toggle switches, selection dialogs.
- [ ] **Language Switching**: Real-time language change.
- [ ] **QR Code**: Generate QR code for user profile (using `qr_flutter`).

## Phase 6: Polish & Interactivity (Week 7)

**Goal**: Animations, transitions, and dark mode testing.

### 6.1 Animations
- [ ] Hero transitions for avatars and images (List -> Detail).
- [ ] Page transitions (Slide right/left or Cupertino style).
- [ ] Loading skeletons (Shimmer effect) for all lists.

### 6.2 Dark Mode Audit
- [ ] Verify every screen in Dark Mode.
- [ ] Ensure contrast ratios are accessible.
- [ ] Test dynamic theme switching.

### 6.3 Dynamic Font Sizing
- [ ] Test "Large" and "Extra Large" font settings across all screens.
- [ ] Ensure `Text` widgets use `textScaleFactor`.

## Phase 7: Optimization & Release (Week 8)

**Goal**: Performance tuning and preparation for deployment.

### 7.1 Performance
- [ ] **List Performance**: Optimize `ListView` with `const` widgets and `itemExtent` where possible.
- [ ] **Image Caching**: Verify `cached_network_image` configuration (cache size, cleanup).
- [ ] **Memory Leak Check**: Use DevTools to check for leaks.

### 7.2 Release
- [ ] Update App Icon and Splash Screen (using `flutter_native_splash`).
- [ ] Configure Android `build.gradle` and iOS `Info.plist`.
- [ ] Build release APK/IPA.

## Technical Stack Recommendations

- **State Management**: Flexible (GetX, Provider, Bloc, or Riverpod).
- **Navigation**: Native Navigator, go_router, or GetX Named Routes.
- **Network Images**: `cached_network_image`.
- **Icons**: `flutter_svg` or `phosphor_flutter`.
- **Lists**: `azlistview` (for contacts), `pull_to_refresh` (for chat/feed).
- **Utils**: `flutter_screenutil` (responsive), `intl` (dates/numbers), `logger`.
- **Media**: `image_picker`, `photo_view` (zoomable images).
- **Storage**: `shared_preferences` or `sqlite3` (for local settings).
