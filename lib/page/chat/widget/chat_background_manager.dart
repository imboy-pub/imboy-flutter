import 'dart:io';

import 'package:flutter/material.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

/// 聊天背景状态
class ChatBackgroundState {
  final String currentBackground;
  final double backgroundOpacity;
  final bool useCustomColor;
  final String customColorHex;
  final String? customImagePath;

  const ChatBackgroundState({
    this.currentBackground = 'default',
    this.backgroundOpacity = 0.3,
    this.useCustomColor = false,
    this.customColorHex = '#F5F5F5',
    this.customImagePath,
  });

  ChatBackgroundState copyWith({
    String? currentBackground,
    double? backgroundOpacity,
    bool? useCustomColor,
    String? customColorHex,
    String? customImagePath,
  }) {
    return ChatBackgroundState(
      currentBackground: currentBackground ?? this.currentBackground,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      useCustomColor: useCustomColor ?? this.useCustomColor,
      customColorHex: customColorHex ?? this.customColorHex,
      customImagePath: customImagePath ?? this.customImagePath,
    );
  }

  Color get customColor =>
      Color(int.parse(customColorHex.replaceFirst('#', '0xFF')));
}

/// 聊天背景管理器 Notifier
class ChatBackgroundManager extends Notifier<ChatBackgroundState> {
  @override
  ChatBackgroundState build() {
    _loadSettings();
    return const ChatBackgroundState();
  }

  /// 预定义的背景选项
  static const List<String> backgroundOptions = [
    'default',
    'pattern_1',
    'pattern_2',
    'pattern_3',
    'gradient_1',
    'gradient_2',
    'solid_color',
    'custom_image',
  ];

  /// 背景名称映射
  static Map<String, String> get backgroundNames => {
    'default': t.common.defaultBackground,
    'pattern_1': t.chat.geometricPattern,
    'pattern_2': t.main.simpleTexture,
    'pattern_3': t.chat.ripplePattern,
    'gradient_1': t.main.gradientBlue,
    'gradient_2': t.main.gradientPurple,
    'solid_color': t.common.solidColorBackground,
    'custom_image': t.chat.customImage,
  };

  /// 加载设置
  void _loadSettings() {
    final currentBackground = StorageService.to.getString('chat_background');
    // 使用字符串存储 double 值
    final opacityStr = StorageService.to.getString('chat_background_opacity');
    final backgroundOpacity = opacityStr.isNotEmpty
        ? double.tryParse(opacityStr) ?? 0.3
        : 0.3;
    final useCustomColor = StorageService.to.getBool('chat_use_custom_color');
    final customColorHex = StorageService.to.getString('chat_custom_color');
    final customImagePath = StorageService.to.getString(
      'chat_custom_image_path',
    );

    state = ChatBackgroundState(
      currentBackground: currentBackground.isNotEmpty
          ? currentBackground
          : 'default',
      backgroundOpacity: backgroundOpacity,
      useCustomColor: useCustomColor ?? false,
      customColorHex: customColorHex.isNotEmpty ? customColorHex : '#F5F5F5',
      customImagePath: customImagePath.isNotEmpty ? customImagePath : null,
    );
  }

  /// 保存设置
  void _saveSettings() {
    StorageService.to.setString('chat_background', state.currentBackground);
    // 使用字符串存储 double 值
    StorageService.to.setString(
      'chat_background_opacity',
      state.backgroundOpacity.toString(),
    );
    StorageService.to.setBool('chat_use_custom_color', state.useCustomColor);
    StorageService.to.setString('chat_custom_color', state.customColorHex);
    StorageService.to.setString(
      'chat_custom_image_path',
      state.customImagePath ?? '',
    );
  }

  /// 设置背景
  void setBackground(String background) {
    state = state.copyWith(currentBackground: background);
    _saveSettings();
  }

  /// 设置背景透明度
  void setBackgroundOpacity(double opacity) {
    state = state.copyWith(backgroundOpacity: opacity);
    _saveSettings();
  }

  /// 设置是否使用自定义颜色
  void setUseCustomColor(bool use) {
    state = state.copyWith(useCustomColor: use);
    _saveSettings();
  }

  /// 设置自定义颜色
  void setCustomColor(Color color) {
    final hexValue =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    state = state.copyWith(customColorHex: hexValue);
    _saveSettings();
  }

  /// 选择并设置自定义图片背景
  Future<bool> pickCustomImage(BuildContext context) async {
    final media = await CapabilityLocator.I
        .get<MediaPickerCapability>()
        .pickSingle(context, MediaType.image);
    if (media == null) return false;
    state = state.copyWith(
      customImagePath: media.path,
      currentBackground: 'custom_image',
    );
    _saveSettings();
    return true;
  }

  /// 获取当前背景装饰
  BoxDecoration getCurrentBackgroundDecoration() {
    final themeNotifier = ref.read(themeProvider.notifier);
    final surfaceColor = themeNotifier.getThemeColor('surface');
    final currentState = state;

    switch (currentState.currentBackground) {
      case 'pattern_1':
        return BoxDecoration(
          color: surfaceColor,
          image: DecorationImage(
            image: AssetImage('assets/images/chat_backgrounds/pattern_1.png'),
            repeat: ImageRepeat.repeat,
            opacity: currentState.backgroundOpacity,
          ),
        );

      case 'pattern_2':
        return BoxDecoration(
          color: surfaceColor,
          image: DecorationImage(
            image: AssetImage('assets/images/chat_backgrounds/pattern_2.png'),
            repeat: ImageRepeat.repeat,
            opacity: currentState.backgroundOpacity,
          ),
        );

      case 'pattern_3':
        return BoxDecoration(
          color: surfaceColor,
          image: DecorationImage(
            image: AssetImage('assets/images/chat_backgrounds/pattern_3.png'),
            repeat: ImageRepeat.repeat,
            opacity: currentState.backgroundOpacity,
          ),
        );

      case 'gradient_1':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(
                0xFF64B5F6,
              ).withValues(alpha: currentState.backgroundOpacity),
              const Color(
                0xFF42A5F5,
              ).withValues(alpha: currentState.backgroundOpacity),
            ],
          ),
        );

      case 'gradient_2':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(
                0xFFBA68C8,
              ).withValues(alpha: currentState.backgroundOpacity),
              const Color(
                0xFFAB47BC,
              ).withValues(alpha: currentState.backgroundOpacity),
            ],
          ),
        );

      case 'solid_color':
        return BoxDecoration(
          color: currentState.useCustomColor
              ? currentState.customColor.withValues(
                  alpha: currentState.backgroundOpacity,
                )
              : surfaceColor,
        );

      case 'custom_image':
        final imagePath = currentState.customImagePath;
        if (imagePath != null && imagePath.isNotEmpty) {
          final file = File(imagePath);
          if (file.existsSync()) {
            return BoxDecoration(
              image: DecorationImage(
                image: FileImage(file),
                fit: BoxFit.cover,
                opacity: currentState.backgroundOpacity,
              ),
            );
          }
        }
        return BoxDecoration(color: surfaceColor);

      case 'default':
      default:
        return BoxDecoration(
          color: surfaceColor,
          image: DecorationImage(
            image: AssetImage('assets/images/pattern.png'),
            repeat: ImageRepeat.repeat,
            colorFilter: ColorFilter.mode(
              surfaceColor.withValues(alpha: currentState.backgroundOpacity),
              BlendMode.srcIn,
            ),
          ),
        );
    }
  }
}

/// 聊天背景管理器 Provider
final chatBackgroundManagerProvider =
    NotifierProvider<ChatBackgroundManager, ChatBackgroundState>(
      ChatBackgroundManager.new,
    );

/// 聊天背景设置页面
class ChatBackgroundSettingsPage extends ConsumerWidget {
  const ChatBackgroundSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(chatBackgroundManagerProvider.notifier);
    final state = ref.watch(chatBackgroundManagerProvider);

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.common.chatSettingBackground,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.allRegular,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 背景预览
            _buildBackgroundPreview(state, manager),

            AppSpacing.verticalXLarge,

            // 背景选择
            _buildBackgroundOptions(context, state, manager),

            AppSpacing.verticalXLarge,

            // 透明度调节
            _buildOpacitySlider(context, state, manager),

            AppSpacing.verticalXLarge,

            // 自定义颜色
            _buildCustomColorSection(context, state, manager),
          ],
        ),
      ),
    );
  }

  /// 构建背景预览
  Widget _buildBackgroundPreview(
    ChatBackgroundState state,
    ChatBackgroundManager manager,
  ) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusMedium,
        child: Container(
          decoration: manager.getCurrentBackgroundDecoration(),
          child: Center(
            child: Text(
              t.common.chatSettingBackground,
              style: TextStyle(
                fontSize: FontSizeType.large.size,
                fontWeight: FontWeight.w500,
                // 背景预览图上的半透明黑标题文字，无对应语义 token，保留
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建背景选项
  Widget _buildBackgroundOptions(
    BuildContext context,
    ChatBackgroundState state,
    ChatBackgroundManager manager,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.common.backgroundSelectColor,
          style: context.textStyle(
            FontSizeType.large,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.verticalMedium,
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: ChatBackgroundManager.backgroundOptions.length,
          itemBuilder: (context, index) {
            final option = ChatBackgroundManager.backgroundOptions[index];
            final name =
                ChatBackgroundManager.backgroundNames[option] ?? option;

            return GestureDetector(
              onTap: () async {
                if (option == 'custom_image') {
                  await manager.pickCustomImage(context);
                } else {
                  manager.setBackground(option);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.borderRadiusSmall,
                  border: Border.all(
                    color: state.currentBackground == option
                        ? Theme.of(context).primaryColor
                        : Colors.grey.withValues(alpha: 0.3),
                    width: state.currentBackground == option ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                        child: _buildBackgroundPreviewThumbnail(option, state),
                      ),
                    ),
                    Container(
                      padding: AppSpacing.allSmall,
                      child: Text(
                        name,
                        style: context.textStyle(
                          FontSizeType.small,
                          fontWeight: state.currentBackground == option
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: state.currentBackground == option
                              ? Theme.of(context).primaryColor
                              : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 构建背景缩略图
  Widget _buildBackgroundPreviewThumbnail(
    String option,
    ChatBackgroundState state,
  ) {
    switch (option) {
      case 'gradient_1':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.chatWallpaperBlueLightStart,
                AppColors.splashGradientStart,
              ],
            ),
          ),
        );
      case 'gradient_2':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.chatWallpaperPurpleLightStart,
                AppColors.chatWallpaperPurpleLightEnd,
              ],
            ),
          ),
        );
      case 'solid_color':
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.color_lens, color: AppColors.iosGray),
        );
      case 'custom_image':
        final path = state.customImagePath;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (file.existsSync()) {
            return Image.file(file, fit: BoxFit.cover, width: double.infinity);
          }
        }
        return Container(
          color: Colors.grey[200],
          child: const Icon(
            Icons.add_photo_alternate,
            color: AppColors.iosGray,
          ),
        );
      default:
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.wallpaper, color: AppColors.iosGray),
        );
    }
  }

  /// 构建透明度滑块
  Widget _buildOpacitySlider(
    BuildContext context,
    ChatBackgroundState state,
    ChatBackgroundManager manager,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.common.backgroundTransparency,
          style: context.textStyle(
            FontSizeType.large,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.verticalMedium,
        Slider(
          value: state.backgroundOpacity,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          label: '${(state.backgroundOpacity * 100).round()}%',
          onChanged: (value) => manager.setBackgroundOpacity(value),
        ),
      ],
    );
  }

  /// 构建自定义颜色区域
  Widget _buildCustomColorSection(
    BuildContext context,
    ChatBackgroundState state,
    ChatBackgroundManager manager,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.common.backgroundUseCustomColor,
          style: context.textStyle(
            FontSizeType.large,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.verticalMedium,
        SwitchListTile(
          title: Text(t.common.backgroundUseCustomColor),
          subtitle: Text(t.common.backgroundOnlySolidColor),
          value: state.useCustomColor,
          onChanged: (value) => manager.setUseCustomColor(value),
        ),
        if (state.useCustomColor) ...[
          AppSpacing.verticalMedium,
          GestureDetector(
            onTap: () => _showColorPicker(context, manager),
            child: Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: state.customColor,
                borderRadius: AppRadius.borderRadiusSmall,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  t.common.backgroundSelectColor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 显示颜色选择器
  void _showColorPicker(BuildContext context, ChatBackgroundManager manager) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.common.backgroundSelectColor),
        content: SizedBox(
          width: 300,
          height: 200,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _predefinedColors.length,
            itemBuilder: (context, index) {
              final color = _predefinedColors[index];
              return GestureDetector(
                onTap: () {
                  manager.setCustomColor(color);
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.borderRadiusTiny,
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.buttonCancel),
          ),
        ],
      ),
    );
  }

  /// 预定义颜色
  static const List<Color> _predefinedColors = [
    AppColors.iosRed,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    AppColors.iosBlue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    AppColors.iosGreen,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    AppColors.iosOrange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];
}
