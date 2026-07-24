# Chat Message UI/UX Optimization Implementation Plan

> **STATUS: ✅ Completed & Verified (backfilled 2026-06-25)**
>
> All 7 tasks were implemented in an earlier session. On 2026-06-25 this plan
> was **verified only — no implementation code was changed**.
>
> **Verification evidence:**
> - `dart analyze lib` → `No issues found!`
> - `flutter test test/plugins/message_type_registry_test.dart` → 4/4 pass
> - `flutter test test/component/chat/custom_message_builder_test.dart` → 14/14 pass (1 location-route case skipped — known headless widget-test limitation)
>
> **Per-task landing check (all 7 confirmed in code):**
>
> | Task | Status | Evidence in code |
> |------|--------|------------------|
> | 1 WebRTC | ✅ | `_buildBody` matches the suggested code verbatim (`Colors.white` when `userIsAuthor`, `CupertinoIcons.videocam_fill/phone_fill`) |
> | 2 Location | ✅ | `MessagePluginSurface.standalone` (:233) + `Clip.antiAlias` (:147) + pin icon (:208) |
> | 3 Video | ✅ | `BackdropFilter` blur 8 (:107) + `CupertinoIcons.play_fill` (:122) |
> | 4 Image | ✅ | received border via `AppColors.getReceivedBubbleDivider(isSent, brightness)` token (:107) — **better than the doc's hardcoded `Border.all + iosGray5`** |
> | 5 Audio/VisitCard | ✅ | `standalone` surface + unified `AppColors.getChatBubbleBackground` |
> | 6 RedPacket | ✅ | `Color(0xFFFA5151)` + `MessageSpacing.getBubbleBorderRadius` (verbatim) |
> | 7 Transfer | ✅ | `MessageSpacing.getBubbleBorderRadius(isSender)` (verbatim) |
>
> **Still needs real-device regression (automation cannot cover rendering):**
> - Task 3 glassmorphism play-button contrast in dark / OLED modes
> - Task 6 red-packet color-temperature feel across light/dark
> - Per project rule: Flutter functional/visual verification must be on a **real device**, not a simulator.
>
> ⚠️ **This file is currently untracked by git** (`docs/plans/` is a new untracked directory). Run `git add docs/plans/` to bring it under version control. The implementation it describes already lives in the tracked source files listed above.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Optimize the UI/UX effects and overall design of more than ten message types in IMBoyApp to align perfectly with the iOS 17 / iMessage visual standards defined in `DESIGN.md`, ensuring cohesive backgrounds, border-radii, alignments, and high readability.

**Architecture:** Utilize specialized pluggable message builders under `lib/component/chat/` registered through `MessageTypeRegistry`. Ensure each builder implements the correct surface mode (`standalone` vs `bubble`), standardizes spacing and border-radii using `MessageSpacing`, and implements correct adaptive colors (using `AppColors`) across light/dark/OLED modes.

**Tech Stack:** Flutter, Dart, Google Fonts / Cupertino Icons, backdrop_filter glassmorphism, semantic AppColors system.

---

### Task 1: WebRTC Call Message Builder Readability Fix

**Files:**
- Modify: `lib/component/chat/message_webrtc_builder.dart`

**Step 1: Write/Update existing tests if any, or prepare execution plan**
Verify that we use adaptive text and icon colors that are 100% readable.

**Step 2: Implement optimal styling**
Modify `_buildBody` in `WebRTCMessageBuilder` to use adaptive colors matching the sender status and brightness:
- If sent by me (`userIsAuthor` is true): text and icon should be `Colors.white` since the bubble is deep brand blue.
- If received (`userIsAuthor` is false): text and icon should adapt to the theme (using `AppColors.getTextColor(brightness)`).
- Upgrade icons to CupertinoIcons for iOS feel.

```dart
// Suggested replacement structure in _buildBody:
Widget _buildBody(
  BuildContext context,
  String messageType,
  String title,
  bool userIsAuthor,
) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final isVideo = messageType == MessageType.webrtcVideo;

  final textColor = userIsAuthor
      ? Colors.white
      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
  final iconColor = userIsAuthor
      ? Colors.white
      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        isVideo ? CupertinoIcons.videocam_fill : CupertinoIcons.phone_fill,
        color: iconColor,
        size: 18,
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
```

**Step 3: Run Flutter analyzer/tests to verify correctness**
Run: `flutter test test/plugins/message_type_registry_test.dart`

---

### Task 2: Location Message Card Premium Upgrade

**Files:**
- Modify: `lib/component/chat/message_location_builder.dart`

**Step 1: Change to Standalone Surface**
Modify `LocationMessageTypePlugin` to return `MessagePluginSurface.standalone` so it is not wrapped in standard padding/bubble, allowing us to implement a perfectly flush map bubble card.

**Step 2: Implement modern flush location bubble**
- Clip content using `Clip.antiAlias` and border radius from `MessageSpacing.getBubbleBorderRadius(isSentByMe)`.
- Use correct bubble background from `AppColors.getChatBubbleBackground`.
- Show title and address on the top part with clean margins and typography.
- Make the map thumbnail fill the bottom part of the card completely.
- Add a classic central red location pin icon over the map snapshot for strong spatial cue.
- Add Received light mode border (`0.5pt iosGray5`) to match `DESIGN.md`.

**Step 3: Verify execution**
Run analyzer to ensure type safety.

---

### Task 3: Video Message Premium UI Refinement

**Files:**
- Modify: `lib/component/chat/message_video_builder.dart`

**Step 1: Implement Glassmorphism Play Button**
- Replace the simple black circle play button with a gorgeous modern glassmorphism play button using a combination of `BackdropFilter` (blur 8), circular white outline, and semi-transparent overlay.
- Use `CupertinoIcons.play_fill`.

**Step 2: Bottom Gradient Scrim & Duration Badge**
- Add a linear black-to-transparent gradient overlay at the bottom of the stack to guarantee high contrast and perfect readability for the duration text on any thumbnail.
- Align duration text style with iOS standards.

**Step 3: Verify execution**
Run: `flutter test test/component/chat/custom_message_builder_test.dart`

---

### Task 4: Image Message received border polish

**Files:**
- Modify: `lib/component/chat/message_image_builder.dart`

**Step 1: Add RECEIVED light border**
- If the image is received (not sent by me) and theme is light mode, add a subtle outline (`Border.all(color: AppColors.iosGray5, width: 0.5)`) over the image so light/white images do not bleed into the background.

**Step 2: Verify execution**
Check for compilation or build warnings.

---

### Task 5: Eliminate double-padding on Voice & Visit Card messages

**Files:**
- Modify: `lib/component/chat/message_audio_builder.dart`
- Modify: `lib/plugins/builtin/register_builtin_plugins.dart`
- Modify: `lib/component/chat/message_visit_card_builder.dart`

**Step 1: Remove redundant outer paddings**
- In `VoiceMessageTypePlugin.build` inside `lib/component/chat/message_audio_builder.dart`, remove the redundant `Padding` wrapper since the inner bubble handles its own constraints.
- In `_VisitCardMessageTypePlugin.build` inside `lib/plugins/builtin/register_builtin_plugins.dart`, remove the redundant `Padding` wrapper.

**Step 2: Visit Card Adaptive Color & Border**
- Update `VisitCardMessageBuilder` background to use unified `AppColors.getChatBubbleBackground(userIsAuthor, false, theme.brightness)`.
- Add received light mode border (`0.5pt iosGray5`).

**Step 3: Verify alignment**
Check that all bubble edges in the list are perfectly vertically aligned.

---

### Task 6: Red Packet Message Bubble Cohesion

**Files:**
- Modify: `lib/component/chat/message_red_packet_builder.dart`

**Step 1: Integrate Speech Bubble Shape**
- Replace the generic medium border radius with standard speech bubble radius: `MessageSpacing.getBubbleBorderRadius(isSentByMe)`.
- Use warmer, softer red packet red `Color(0xFFFA5151)` instead of hardcoded neon red.

**Step 2: Run tests**
Ensure tests pass.

---

### Task 7: P2P Transfer Message Bubble Cohesion

**Files:**
- Modify: `lib/component/chat/message_transfer_builder.dart`

**Step 1: Integrate Speech Bubble Shape**
- Replace the generic medium border radius with standard speech bubble radius: `MessageSpacing.getBubbleBorderRadius(isSender)`.
- Clean up text style alignments.

**Step 2: Verify overall suite**
Run: `flutter test test/component/chat/custom_message_builder_test.dart`
