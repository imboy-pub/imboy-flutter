import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/theme_manager.dart';

/// 聊天背景管理器
/// 提供聊天背景的个性化设置和管理
class ChatBackgroundManager extends GetxController {
  static ChatBackgroundManager get to => Get.find();

  final RxString _currentBackground = 'default'.obs;
  final RxDouble _backgroundOpacity = 0.3.obs;
  final RxBool _useCustomColor = false.obs;
  final RxString _customColorHex = '#F5F5F5'.obs;

  String get currentBackground => _currentBackground.value;
  double get backgroundOpacity => _backgroundOpacity.value;
  bool get useCustomColor => _useCustomColor.value;
  Color get customColor => Color(int.parse(_customColorHex.value.replaceFirst('#', '0xFF')));

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
  static const Map<String, String> backgroundNames = {
    'default': '默认背景',
    'pattern_1': '几何图案',
    'pattern_2': '简约纹理',
    'pattern_3': '波纹图案',
    'gradient_1': '渐变蓝',
    'gradient_2': '渐变紫',
    'solid_color': '纯色背景',
    'custom_image': '自定义图片',
  };

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  /// 加载设置
  void _loadSettings() {
    _currentBackground.value = StorageService.to.getString('chat_background') ?? 'default';
    _backgroundOpacity.value = StorageService.to.getDouble('chat_background_opacity') ?? 0.3;
    _useCustomColor.value = StorageService.to.getBool('chat_use_custom_color') ?? false;
    _customColorHex.value = StorageService.to.getString('chat_custom_color') ?? '#F5F5F5';
  }

  /// 保存设置
  void _saveSettings() {
    StorageService.to.setString('chat_background', _currentBackground.value);
    StorageService.to.setDouble('chat_background_opacity', _backgroundOpacity.value);
    StorageService.to.setBool('chat_use_custom_color', _useCustomColor.value);
    StorageService.to.setString('chat_custom_color', _customColorHex.value);
  }

  /// 设置背景
  void setBackground(String background) {
    _currentBackground.value = background;
    _saveSettings();
  }

  /// 设置背景透明度
  void setBackgroundOpacity(double opacity) {
    _backgroundOpacity.value = opacity;
    _saveSettings();
  }

  /// 设置是否使用自定义颜色
  void setUseCustomColor(bool use) {
    _useCustomColor.value = use;
    _saveSettings();
  }

  /// 设置自定义颜色
  void setCustomColor(Color color) {
    _customColorHex.value = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    _saveSettings();
  }

  /// 获取当前背景装饰
  BoxDecoration getCurrentBackgroundDecoration() {
    final theme = ThemeManager.instance;
    final isDark = theme.isDarkMode;
    
    switch (_currentBackground.value) {
      case 'pattern_1':
        return BoxDecoration(
          color: theme.getThemeColor('surface'),
          image: DecorationImage(
            image: AssetImage('assets/images/chat_backgrounds/pattern_1.png'),
            repeat: ImageRepeat.repeat,
            opacity: _backgroundOpacity.value,
          ),
        );
        
      case 'pattern_2':
        return BoxDecoration(
          color: theme.getThemeColor('surface'),
          image: DecorationImage(
            image: AssetImage('assets/images/chat_backgrounds/pattern_2.png'),
            repeat: ImageRepeat.repeat,
            opacity: _backgroundOpacity.value,
          ),
        );
        
      case 'pattern_3':
        return BoxDecoration(
          color: theme.getThemeColor('surface'),
          image: DecorationImage(
            image: AssetImage('assets/images/chat_backgrounds/pattern_3.png'),
            repeat: ImageRepeat.repeat,
            opacity: _backgroundOpacity.value,
          ),
        );
        
      case 'gradient_1':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF64B5F6).withValues(alpha: _backgroundOpacity.value),
              const Color(0xFF42A5F5).withValues(alpha: _backgroundOpacity.value),
            ],
          ),
        );
        
      case 'gradient_2':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFBA68C8).withValues(alpha: _backgroundOpacity.value),
              const Color(0xFFAB47BC).withValues(alpha: _backgroundOpacity.value),
            ],
          ),
        );
        
      case 'solid_color':
        return BoxDecoration(
          color: _useCustomColor.value 
              ? customColor.withValues(alpha: _backgroundOpacity.value)
              : theme.getThemeColor('surface'),
        );
        
      case 'custom_image':
        // TODO: 实现自定义图片背景
        return BoxDecoration(
          color: theme.getThemeColor('surface'),
        );
        
      case 'default':
      default:
        return BoxDecoration(
          color: theme.getThemeColor('surface'),
          image: DecorationImage(
            image: AssetImage('assets/images/pattern.png'),
            repeat: ImageRepeat.repeat,
            colorFilter: ColorFilter.mode(
              theme.getThemeColor('surface').withValues(alpha: _backgroundOpacity.value),
              BlendMode.srcIn,
            ),
          ),
        );
    }
  }
}

/// 聊天背景设置页面
class ChatBackgroundSettingsPage extends StatelessWidget {
  const ChatBackgroundSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Get.put(ChatBackgroundManager());
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天背景'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 背景预览
            _buildBackgroundPreview(manager),
            
            const SizedBox(height: 24),
            
            // 背景选择
            _buildBackgroundOptions(manager),
            
            const SizedBox(height: 24),
            
            // 透明度调节
            _buildOpacitySlider(manager),
            
            const SizedBox(height: 24),
            
            // 自定义颜色
            _buildCustomColorSection(manager),
          ],
        ),
      ),
    );
  }

  /// 构建背景预览
  Widget _buildBackgroundPreview(ChatBackgroundManager manager) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Obx(() => Container(
          decoration: manager.getCurrentBackgroundDecoration(),
          child: const Center(
            child: Text(
              '聊天背景预览',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),
        )),
      ),
    );
  }

  /// 构建背景选项
  Widget _buildBackgroundOptions(ChatBackgroundManager manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择背景',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
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
            final name = ChatBackgroundManager.backgroundNames[option] ?? option;
            
            return Obx(() => GestureDetector(
              onTap: () => manager.setBackground(option),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: manager.currentBackground == option
                        ? Theme.of(context).primaryColor
                        : Colors.grey.withValues(alpha: 0.3),
                    width: manager.currentBackground == option ? 2 : 1,
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
                        child: _buildBackgroundPreviewThumbnail(option),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: manager.currentBackground == option
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: manager.currentBackground == option
                              ? Theme.of(context).primaryColor
                              : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ));
          },
        ),
      ],
    );
  }

  /// 构建背景缩略图
  Widget _buildBackgroundPreviewThumbnail(String option) {
    switch (option) {
      case 'gradient_1':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF64B5F6), Color(0xFF42A5F5)],
            ),
          ),
        );
      case 'gradient_2':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFBA68C8), Color(0xFFAB47BC)],
            ),
          ),
        );
      case 'solid_color':
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.color_lens, color: Colors.grey),
        );
      default:
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.wallpaper, color: Colors.grey),
        );
    }
  }

  /// 构建透明度滑块
  Widget _buildOpacitySlider(ChatBackgroundManager manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '背景透明度',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Obx(() => Slider(
          value: manager.backgroundOpacity,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          label: '${(manager.backgroundOpacity * 100).round()}%',
          onChanged: (value) => manager.setBackgroundOpacity(value),
        )),
      ],
    );
  }

  /// 构建自定义颜色区域
  Widget _buildCustomColorSection(ChatBackgroundManager manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '自定义颜色',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Obx(() => SwitchListTile(
          title: const Text('使用自定义颜色'),
          subtitle: const Text('仅适用于纯色背景'),
          value: manager.useCustomColor,
          onChanged: (value) => manager.setUseCustomColor(value),
        )),
        if (manager.useCustomColor) ...[
          const SizedBox(height: 12),
          Obx(() => GestureDetector(
            onTap: () => _showColorPicker(Get.context!, manager),
            child: Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: manager.customColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: const Center(
                child: Text(
                  '点击选择颜色',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )),
        ],
      ],
    );
  }

  /// 显示颜色选择器
  void _showColorPicker(BuildContext context, ChatBackgroundManager manager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: Container(
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
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 预定义颜色
  static const List<Color> _predefinedColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];
}