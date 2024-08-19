import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

// ignore: implementation_imports, unnecessary_import
import 'package:emoji_picker_flutter/src/category_view/category_emoji.dart'
    show CategoryEmoji;

/// Customized IMBoy category view
class EmojiCategoryView extends CategoryView {
  const EmojiCategoryView(
    super.config,
    super.state,
    super.tabController,
    super.pageController, {
    super.key,
  });

  @override
  EmojiCategoryViewState createState() => EmojiCategoryViewState();
}

class EmojiCategoryViewState extends State<EmojiCategoryView>
    with SkinToneOverlayStateMixin {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.config.categoryViewConfig.backgroundColor,
      child: n.Row([
        Expanded(
          child: EmojiTabBar(
            widget.config,
            widget.tabController,
            widget.pageController,
            widget.state.categoryEmoji,
            closeSkinToneOverlay,
          ),
        ),
        _buildBackspaceButton(),
      ]),
    );
  }

  Widget _buildBackspaceButton() {
    if (widget.config.categoryViewConfig.extraTab != null &&
        widget.config.categoryViewConfig.extraTab != CategoryExtraTab.NONE) {
      return BackspaceButton(
        widget.config,
        widget.state.onBackspacePressed,
        widget.state.onBackspaceLongPressed,
        widget.config.categoryViewConfig.backspaceColor,
      );
    }
    return const SizedBox.shrink();
  }
}

class EmojiTabBar extends StatelessWidget {
  const EmojiTabBar(
    this.config,
    this.tabController,
    this.pageController,
    this.categoryEmojis,
    this.closeSkinToneOverlay, {
    super.key,
  });

  final Config config;

  final TabController tabController;

  final PageController pageController;

  final List<CategoryEmoji> categoryEmojis;

  final VoidCallback closeSkinToneOverlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: config.categoryViewConfig.tabBarHeight,
      child: TabBar(
        // labelColor: config.categoryViewConfig.iconColorSelected,
        // indicatorColor: config.categoryViewConfig.indicatorColor,
        // unselectedLabelColor: config.categoryViewConfig.iconColor,
        // dividerColor: config.categoryViewConfig.dividerColor,
        controller: tabController,
        labelPadding: const EdgeInsets.only(top: 1.0),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: (index) {
          closeSkinToneOverlay();
          pageController.jumpToPage(index);
        },
        tabs: categoryEmojis
            .asMap()
            .entries
            .map<Widget>(
                (item) => _buildCategory(item.key, item.value.category))
            .toList(),
      ),
    );
  }

  Widget _buildCategory(int index, Category category) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(
          getIconForCategory(
            config.categoryViewConfig.categoryIcons,
            category,
          ),
          size: 28,
        ),
      ),
    );
  }
}

/// Custom IMBoy Search view implementation
class EmojiSearchView extends SearchView {
  const EmojiSearchView(super.config, super.state, super.showEmojiView,
      {super.key});

  @override
  EmojiSearchViewState createState() => EmojiSearchViewState();
}

class EmojiSearchViewState extends SearchViewState {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final emojiSize =
          widget.config.emojiViewConfig.getEmojiSize(constraints.maxWidth);
      final emojiBoxSize =
          widget.config.emojiViewConfig.getEmojiBoxSize(constraints.maxWidth);
      return Container(
        color: widget.config.searchViewConfig.backgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: emojiBoxSize + 8.0,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                scrollDirection: Axis.horizontal,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  return buildEmoji(
                    results[index],
                    emojiSize,
                    emojiBoxSize,
                  );
                },
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: widget.showEmojiView,
                  // color: widget.config.searchViewConfig.buttonColor,
                  icon: Icon(
                    Icons.arrow_back,
                    color: widget.config.searchViewConfig.buttonIconColor,
                    size: 28.0,
                  ),
                ),
                Expanded(
                  child: TextField(
                    onChanged: onTextInputChanged,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'search'.tr,
                      hintStyle: const TextStyle(
                        // color: AppColors.ItemOnColor,
                        fontWeight: FontWeight.normal,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Default Bottom Action Bar implementation
class AppBottomActionBar extends BottomActionBar {
  /// Constructor
  const AppBottomActionBar(super.config, super.state, super.showSearchView,
      {super.key});

  @override
  State<StatefulWidget> createState() => _AppBottomActionBarState();
}

class _AppBottomActionBarState extends State<AppBottomActionBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.config.bottomActionBarConfig.backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSearchViewButton(),
          _buildBackspaceButton(),
        ],
      ),
    );
  }

  Widget _buildSearchViewButton() {
    if (widget.config.bottomActionBarConfig.showSearchViewButton) {
      return CircleAvatar(
        backgroundColor: widget.config.bottomActionBarConfig.buttonColor,
        child: IconButton(
          onPressed: widget.showSearchView,
          icon: Icon(
            Icons.search,
            color: widget.config.bottomActionBarConfig.buttonIconColor,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBackspaceButton() {
    if (widget.config.bottomActionBarConfig.showBackspaceButton) {
      return BackspaceButton(
        widget.config,
        widget.state.onBackspacePressed,
        widget.state.onBackspaceLongPressed,
        widget.config.bottomActionBarConfig.buttonIconColor,
      );
    }
    return const SizedBox.shrink();
  }
}
