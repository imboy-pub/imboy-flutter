import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart' show FontSizeType;

/// 面对面建群页面
class FaceToFacePage extends ConsumerStatefulWidget {
  const FaceToFacePage({super.key});

  @override
  ConsumerState<FaceToFacePage> createState() => _FaceToFacePageState();
}

class _FaceToFacePageState extends ConsumerState<FaceToFacePage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(faceToFaceProvider);
    final notifier = ref.read(faceToFaceProvider.notifier);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.createGroupF2f,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: t.buttonBack,
        ),
      ),
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      body: Column(
        children: [
          // 使用 Expanded 包裹可滚动内容，确保不会溢出
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(height: 20, width: MediaQuery.sizeOf(context).width),
                  // 顶部提示：
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              t.createGroupF2fTips,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : colorScheme.onSurface.withValues(
                                        alpha: 0.8,
                                      ),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.left,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // 数字输入区
                  _buildNumberWidget(context, state),

                  const SizedBox(height: 16),

                  // 错误提示：仅在有文本时显示，避免空白占位
                  if (state.errorInfo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        state.errorInfo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.getIosRed(theme.brightness),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // NumericKeypad 固定在底部
          Container(
            color: isDark ? Colors.black87 : Colors.white,
            child: NumericKeypad(
              controller: state.textEditingController,
              onChanged: (value) async {
                notifier.updateResult(value);
                iPrint("_textEditingController value $value");

                if (value.length == 4) {
                  EasyLoading.show(status: '');
                  EasyLoading.dismiss();

                  Map<String, dynamic> res = await notifier.faceToFace(value);
                  notifier.updateErrorInfo(res['error'] ?? '');

                  String gid = res['gid'] ?? '';
                  if (gid.isNotEmpty && context.mounted) {
                    context.push(
                      '/group/face_to_face_confirm',
                      extra: {
                        'code': value,
                        'gid': gid,
                        'memberList': res['memberList'] ?? <dynamic>[],
                      },
                    );
                  }

                  // 延时清理输入与提示
                  Timer(const Duration(seconds: 3), () {
                    notifier.clearInput();
                    EasyLoading.dismiss();
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 4 位数字占位视图
  /// - 暗色模式：使用黑色金属渐变 + 轻微高光与阴影，呈现"金属感"
  /// - 浅色模式：使用主题容器色 + 细描边，简洁大方
  /// - 自适应：根据屏幕宽度调整单格尺寸与间距，确保"数据数组大小"得体
  Widget _buildNumberWidget(BuildContext context, FaceToFaceState state) {
    final length = state.resultData.length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final double screenW = MediaQuery.sizeOf(context).width;
    // 自适应尺寸（iPhone 小屏 ~ 现代大屏）
    final double boxSize = screenW <= 360
        ? 52
        : (screenW <= 400 ? 58 : (screenW <= 480 ? 64 : 68));
    final double gap = screenW <= 360 ? 8 : (screenW <= 400 ? 10 : 12);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final hasValue = index < length;
          final isActive = index == length && length < 4; // 当前输入焦点格
          final BoxDecoration baseDecoration = BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    colors: hasValue
                        ? const [Color(0xFF2A2C31), Color(0xFF16181C)]
                        : const [Color(0xFF202226), Color(0xFF131417)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isDark ? null : theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.borderRadiusMedium,
            border: Border.all(
              color: isDark
                  ? (isActive
                        ? Colors.white.withValues(alpha: 0.20)
                        : Colors.white54.withValues(
                            alpha: hasValue ? 0.10 : 0.06,
                          ))
                  : (isActive
                        ? colorScheme.primary.withValues(alpha: 0.45)
                        : theme.colorScheme.outline.withValues(alpha: 0.15)),
              width: isActive ? 1.2 : 0.8,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 6,
                      offset: const Offset(2, 3),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.06),
                      blurRadius: 3,
                      offset: const Offset(-2, -2),
                    ),
                  ]
                : const [],
          );

          return Container(
            width: boxSize,
            height: boxSize,
            margin: EdgeInsets.symmetric(horizontal: gap / 2),
            decoration: baseDecoration,
            alignment: Alignment.center,
            child: hasValue
                ? Text(
                    state.resultData[index],
                    style: TextStyle(
                      fontSize: FontSizeType.large.size,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  )
                : Opacity(
                    opacity: isDark ? 0.20 : 0.15,
                    child: Text(
                      '•', // 候选占位符（提升布局稳定性）
                      style: TextStyle(
                        fontSize: FontSizeType.large.size,
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          );
        }),
      ),
    );
  }
}
