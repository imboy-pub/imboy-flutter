import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'help_page.g.dart';

/// Help 模块的状态
class HelpState {
  final List<String> helpCategories;

  const HelpState({this.helpCategories = const []});

  HelpState copyWith({List<String>? helpCategories}) {
    return HelpState(helpCategories: helpCategories ?? this.helpCategories);
  }
}

@riverpod
class HelpNotifier extends _$HelpNotifier {
  @override
  HelpState build() {
    return const HelpState();
  }

  /// 加载帮助分类
  Future<void> loadHelpCategories() async {
    // 这里会调用 API 获取帮助分类
    state = state.copyWith(helpCategories: []);
  }
}
