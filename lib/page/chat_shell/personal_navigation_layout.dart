import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/page/web_shell/web_shell_provider.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import 'chat_shell_breakpoint.dart';
import 'chat_shell_page.dart';

/// Semantic destinations; the mobile shell may omit the channels tab.
enum PersonalNavigationTab { messages, contacts, channels, mine }

PersonalNavigationTab personalTabFromMobileIndex(
  int index, {
  required bool channelAvailable,
}) {
  final tabs = [
    PersonalNavigationTab.messages,
    PersonalNavigationTab.contacts,
    if (channelAvailable) PersonalNavigationTab.channels,
    PersonalNavigationTab.mine,
  ];
  return tabs[index.clamp(0, tabs.length - 1)];
}

int mobileIndexForPersonalTab(
  PersonalNavigationTab tab, {
  required bool channelAvailable,
}) => switch (tab) {
  PersonalNavigationTab.messages => 0,
  PersonalNavigationTab.contacts => 1,
  PersonalNavigationTab.channels => channelAvailable ? 2 : 0,
  PersonalNavigationTab.mine => channelAvailable ? 3 : 2,
};

/// Transfers the visible destination only when the personal layout changes.
/// The existing navigation providers remain the source of truth; a pending
/// handoff lasts only until its post-frame callback runs.
class PersonalNavigationLayout extends ConsumerStatefulWidget {
  const PersonalNavigationLayout({
    super.key,
    required this.channelAvailable,
    required this.mobileBuilder,
    required this.desktopEntry,
  });

  final bool channelAvailable;
  final Widget Function(int? restoredIndex) mobileBuilder;
  final Widget desktopEntry;

  @override
  ConsumerState<PersonalNavigationLayout> createState() =>
      _PersonalNavigationLayoutState();
}

class _PersonalNavigationLayoutState
    extends ConsumerState<PersonalNavigationLayout> {
  ChatShellLayout? _layout;
  int? _mobileRestoredIndex;
  _NavigationRestore? _pending;

  Object _snapshot(ChatShellLayout layout) =>
      layout == ChatShellLayout.mobile
      ? ref.read(bottomNavigationProvider)
      : ref.read(webShellProvider);

  bool _isUnchanged(_NavigationRestore restore) {
    final current = _snapshot(restore.layout);
    return restore.layout == ChatShellLayout.mobile
        ? restore.expected == current
        : identical(restore.expected, current);
  }

  PersonalNavigationTab _visibleTab(ChatShellLayout layout) {
    final pending = _pending;
    if (pending != null &&
        pending.layout == layout &&
        _isUnchanged(pending) &&
        pending.uid == ref.read(currentUserProvider)?.uid) {
      return pending.tab;
    }
    return layout == ChatShellLayout.mobile
        ? personalTabFromMobileIndex(
            ref.read(bottomNavigationProvider),
            channelAvailable: widget.channelAvailable,
          )
        : PersonalNavigationTab.values[ref.read(webShellProvider).currentTab];
  }

  void _restore(ChatShellLayout layout, PersonalNavigationTab tab) {
    final restore = _NavigationRestore(
      layout,
      tab,
      _snapshot(layout),
      ref.read(currentUserProvider)?.uid,
    );
    _pending = restore;
    if (layout == ChatShellLayout.mobile) {
      _mobileRestoredIndex = mobileIndexForPersonalTab(
        tab,
        channelAvailable: widget.channelAvailable,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_pending, restore)) return;
      _pending = null;
      if (_layout != layout ||
          !_isUnchanged(restore) ||
          restore.uid != ref.read(currentUserProvider)?.uid) {
        return;
      }
      if (layout == ChatShellLayout.mobile) {
        final index = mobileIndexForPersonalTab(
          tab,
          channelAvailable: widget.channelAvailable,
        );
        if (ref.read(bottomNavigationProvider) != index) {
          ref.read(bottomNavigationProvider.notifier).changeIndex(index);
        }
      } else if (ref.read(webShellProvider).currentTab != tab.index) {
        ref.read(webShellProvider.notifier).switchTab(tab.index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = resolveChatShellLayout(MediaQuery.sizeOf(context).width);
    final previous = _layout;
    if (previous != null && previous != layout) {
      _restore(layout, _visibleTab(previous));
    }
    _layout = layout;
    return ChatShellPage(
      mobileEntry: widget.mobileBuilder(_mobileRestoredIndex),
      desktopEntry: widget.desktopEntry,
    );
  }
}

class _NavigationRestore {
  const _NavigationRestore(this.layout, this.tab, this.expected, this.uid);

  final ChatShellLayout layout;
  final PersonalNavigationTab tab;
  final Object expected;
  final String? uid;
}
