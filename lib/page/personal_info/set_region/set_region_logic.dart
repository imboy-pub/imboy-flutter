import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/service/cache/region_cache.dart';

import 'package:imboy/component/helper/func.dart';

/// 地区选择逻辑控制器（支持省/市/区三级联动与搜索）
///
/// 注意：
/// - 顶层 SetRegionPage 仍按原有方式展示顶层数据；
/// - 进入下级使用本文件内置的 _SubRegionPage，不改动现有 SetRegionPage；
/// - 搜索仅在当前层级内过滤（顶层过滤省；次级过滤市；末级为区/县列表）。
class SetRegionLogic extends GetxController {
  /// 当前层级列表（顶层为国家/大区；次级为省/市；末级为区/县）
  final RxList regionList = [].obs;

  /// 选中的完整地区，形如："中国大陆 北京 朝阳"
  final RxString selectedRegion = ''.obs;

  /// 初始值，用于变更比较
  String _initialValue = '';

  /// 是否发生变更（selectedRegion 与初始值对比）
  final RxBool hasChanged = false.obs;

  /// 当前的路径（逐级进入时，依次追加）
  final RxList<String> regionPath = <String>[].obs;

  /// 全量数据（仅加载一次）
  List<dynamic> _fullRegionList = [];

  @override
  void onInit() {
    super.onInit();
    loadRegionData().then((_) async {
      final cachedSelected = await RegionCache.loadSelectedRegion();
      if (cachedSelected.isNotEmpty) {
        initData(cachedSelected);
      }
      final cachedPath = await RegionCache.loadRegionPath();
      if (cachedPath.isNotEmpty) {
        regionPath.value = cachedPath;
      }
      final cachedList = await RegionCache.loadRegionList();
      if (cachedList.isNotEmpty) {
        final bool hasFull = _fullRegionList.isNotEmpty;
        final bool cachedOk = _isValidRegionStructure(cachedList);
        if (!cachedOk) {
          if (hasFull) {
            regionList.value = _fullRegionList;
            await RegionCache.saveRegionList(_fullRegionList);
          } else {
            regionList.value = cachedList;
          }
        } else if (hasFull && !_isRegionListConsistent(cachedList, _fullRegionList)) {
          regionList.value = _fullRegionList;
          await RegionCache.saveRegionList(_fullRegionList);
        } else {
          regionList.value = cachedList;
        }
      } else {
        // 无缓存时，若全量数据有效则维持全量数据
        if (_fullRegionList.isNotEmpty) {
          regionList.value = _fullRegionList;
        }
      }
    });
  }

  /// 初始化数据
  /// 用途：设置初始值与路径
  /// 参数：currentValue 当前值（空字符串或"省 市 区"）
  /// 返回：void
  /// 异常：无
  /// 复杂度：O(n) 按空格切分字符串
  void initData(String currentValue) {
    _initialValue = currentValue;
    selectedRegion.value = currentValue;
    hasChanged.value = false;

    if (selectedRegion.value.isNotEmpty) {
      regionPath.value =
          selectedRegion.value.split(' ').where((e) => e.trim().isNotEmpty).toList();
    } else {
      regionPath.clear();
    }
  }

  /// 加载 assets/data/region.json
  /// 用途：为顶层列表提供数据源
  /// 参数：无
  /// 返回：Future<void>
  /// 异常：读取/解析失败将打印日志
  /// 复杂度：O(n)
  Future<void> loadRegionData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/region.json');
      final List<dynamic> data = json.decode(jsonString);
    _fullRegionList = data;
    regionList.value = data;
    RegionCache.saveRegionList(data);
  } catch (e) {
      iPrint('加载地区数据失败: $e');
    }
  }

  /// 判断某个名称是否已被选中（用于高亮）
  /// 参数：regionName 待判断的地区名
  /// 返回：bool
  /// 复杂度：O(k)，k为名称长度
  bool isRegionSelected(String regionName) {
    final parts = selectedRegion.value.split(' ').where((e) => e.trim().isNotEmpty).toList();
    return parts.contains(regionName);
  }

  /// 校验地区数据结构是否合法（递归）
  /// 用途：保证每一层为 Map{title, children: List} 或 String
  /// 参数：list 待校验列表
  /// 返回：bool
  /// 复杂度：O(n)
  bool _isValidRegionStructure(List<dynamic> list) {
    try {
      for (final item in list) {
        if (item is String) {
          continue;
        }
        if (item is Map) {
          final t = item['title'];
          final ch = item['children'];
          if (t == null || t is! String) {
            return false;
          }
          if (ch == null || ch is! List) {
            return false;
          }
          if (!_isValidRegionStructure(ch.cast<dynamic>())) {
            return false;
          }
        } else {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 判断缓存与全量数据是否一致（浅比较）
  /// 用途：对比顶层数量与标题集合，若不同则视为不一致
  /// 参数：
  /// - cached: 缓存的列表
  /// - full: 全量列表
  /// 返回：bool
  /// 复杂度：O(n)
  bool _isRegionListConsistent(List<dynamic> cached, List<dynamic> full) {
    if (cached.length != full.length) {
      return false;
    }

    Set<String> toTitles(List<dynamic> src) {
      final s = <String>{};
      for (final it in src) {
        if (it is String) {
          s.add(it);
        } else if (it is Map) {
          s.add((it['title'] ?? '').toString());
        }
      }
      return s;
    }

    final a = toTitles(cached);
    final b = toTitles(full);
    if (a.length != b.length) {
      return false;
    }
    if (!a.containsAll(b) || !b.containsAll(a)) {
      return false;
    }
    return true;
  }

  /// 在当前层级内搜索过滤
  /// 用途：根据关键字过滤当前层级（顶层为省；次级为市；末级为区/县）
  /// 参数：
  /// - source: 当前层级的原始 children 列表（若为顶层，传 _fullRegionList）
  /// - keyword: 关键字
  /// 返回：过滤后的列表
  /// 复杂度：O(n*m) n 为省份数，m 为城市数（在当前层级）
  List<dynamic> filterInLevel(List<dynamic> source, String keyword) {
    final kw = keyword.trim();
    if (kw.isEmpty) return source;

    final lc = kw.toLowerCase();
    final out = <dynamic>[];

    for (final item in source) {
      if (item is String) {
        // 末级为纯字符串
        if (item.toLowerCase().contains(lc)) {
          out.add(item);
        }
      } else if (item is Map) {
        final title = (item['title'] ?? '').toString();
        final children = (item['children'] ?? []) as List;

        // 命中自身标题
        if (title.toLowerCase().contains(lc)) {
          out.add(item);
          continue;
        }

        // 命中子项（仅将命中的子项保留）
        final matchedChildren = <dynamic>[];
        for (final c in children) {
          if (c is String) {
            if (c.toLowerCase().contains(lc)) {
              matchedChildren.add(c);
            }
          } else if (c is Map) {
            final ct = (c['title'] ?? '').toString();
            if (ct.toLowerCase().contains(lc)) {
              matchedChildren.add(c);
              continue;
            }
            final gc = (c['children'] ?? []) as List;
            final matchedGrand = <dynamic>[];
            for (final g in gc) {
              if (g is String) {
                if (g.toLowerCase().contains(lc)) {
                  matchedGrand.add(g);
                }
              }
            }
            if (matchedGrand.isNotEmpty) {
              matchedChildren.add({'title': ct, 'children': matchedGrand});
            }
          }
        }

        if (matchedChildren.isNotEmpty) {
          out.add({'title': title, 'children': matchedChildren});
        }
      }
    }

    return out;
    }

  /// 顶层搜索应用
  /// 用途：对顶层数据进行搜索过滤，结果写入 regionList 以刷新 UI
  /// 参数：
  /// - keyword: 搜索关键字
  /// 返回：void
  /// 异常：无
  /// 复杂度：O(n*m)，与 filterInLevel 一致
  void applyTopSearch(String keyword) {
    final src = _fullRegionList;
    regionList.value = filterInLevel(src, keyword);
  }

  /// 选择地区（在 SetRegionPage 顶层列表中被调用）
  /// 用途：若有子级则进入下一级页面；叶子节点则直接选中
  /// 参数：
  /// - regionName: 当前点击项标题
  /// - children: 子级（可能为空）
  /// - context: BuildContext
  /// - onSave: 顶部保存回调，由页面传入
  /// 返回：void
  /// 异常：无
  /// 复杂度：O(1)
  void selectRegion(
    String regionName,
    List children,
    BuildContext context,
    Future<bool> Function(String) onSave,
  ) {
    if (children.isNotEmpty) {
      _navigateToSubRegion(regionName, children, context, onSave);
    } else {
      _selectLeafRegion(regionName);
    }
  }

  /// 进入下一级页面
  /// 用途：使用内置的 _SubRegionPage 展示子级与搜索
  /// 参数：
  /// - parentName: 父级标题
  /// - children: 子级列表
  /// - context: BuildContext
  /// - onSave: 保存回调
  /// 返回：void
  /// 异常：无
  /// 复杂度：O(1)
  void _navigateToSubRegion(
    String parentName,
    List children,
    BuildContext context,
    Future<bool> Function(String) onSave,
  ) {
    // 确保路径单链路：从顶层开始逐级构建
    final newPath = _buildSingleChainPath(parentName);

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => _SubRegionPage(
          title: parentName,
          children: children,
          parentPath: newPath,
          onRegionSelected: (selectedPath) {
            // 验证路径有效性后再保存
            if (_isValidPath(selectedPath)) {
              selectedRegion.value = selectedPath.join(' ');
              regionPath.value = selectedPath;
              hasChanged.value = selectedRegion.value != _initialValue;
              RegionCache.saveSelectedRegion(selectedRegion.value);
              RegionCache.saveRegionPath(regionPath.value);
            }
          },
          onSave: onSave,
        ),
      ),
    );
  }

  /// 构建单一链路路径
  /// 用途：确保从顶层到当前选择项形成唯一路径，避免分支路径
  /// 参数：currentSelection 当前选择的项目名称
  /// 返回：List<String> 单一链路路径
  /// 复杂度：O(n)
  List<String> _buildSingleChainPath(String currentSelection) {
    final currentPath = List<String>.from(regionPath);
    
    // 如果当前路径为空，直接从选择项开始
    if (currentPath.isEmpty) {
      return [currentSelection];
    }
    
    // 检查当前选择是否已在路径中
    final existingIndex = currentPath.indexOf(currentSelection);
    if (existingIndex >= 0) {
      // 如果已存在，截取到该位置（避免重复）
      return currentPath.sublist(0, existingIndex + 1);
    }
    
    // 验证路径连续性：确保当前选择是路径末端的有效子项
    if (_isValidNextLevel(currentPath, currentSelection)) {
      return [...currentPath, currentSelection];
    }
    
    // 路径不连续时，重新从当前选择开始
    return [currentSelection];
  }

  /// 验证下一级选择是否有效
  /// 用途：检查当前选择是否为路径末端项的有效子项
  /// 参数：
  /// - currentPath: 当前路径
  /// - nextSelection: 下一级选择
  /// 返回：bool
  /// 复杂度：O(n*m)
  bool _isValidNextLevel(List<String> currentPath, String nextSelection) {
    if (currentPath.isEmpty) return true;
    
    try {
      // 从全量数据中查找路径对应的数据节点
      dynamic currentNode = _fullRegionList;
      
      for (final pathItem in currentPath) {
        if (currentNode is List) {
          // 在当前层级中查找匹配项
          dynamic found;
          for (final item in currentNode) {
            if (item is String && item == pathItem) {
              found = item;
              break;
            } else if (item is Map && item['title'] == pathItem) {
              found = item;
              break;
            }
          }
          
          if (found == null) return false;
          
          // 移动到下一层级
          if (found is Map) {
            currentNode = found['children'] ?? [];
          } else {
            // 字符串节点没有子级
            return false;
          }
        } else {
          return false;
        }
      }
      
      // 检查 nextSelection 是否在当前节点的子级中
      if (currentNode is List) {
        for (final item in currentNode) {
          if (item is String && item == nextSelection) {
            return true;
          } else if (item is Map && item['title'] == nextSelection) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      iPrint('验证路径有效性失败: $e');
      return false;
    }
  }

  /// 验证完整路径是否有效
  /// 用途：确保选择的路径在数据结构中存在且连续
  /// 参数：path 待验证的路径
  /// 返回：bool
  /// 复杂度：O(n*m)
  bool _isValidPath(List<String> path) {
    if (path.isEmpty) return true;
    
    try {
      dynamic currentNode = _fullRegionList;
      
      for (int i = 0; i < path.length; i++) {
        final pathItem = path[i];
        if (currentNode is! List) return false;
        
        // 在当前层级中查找匹配项
        dynamic found;
        for (final item in currentNode) {
          if (item is String && item == pathItem) {
            found = item;
            break;
          } else if (item is Map && item['title'] == pathItem) {
            found = item;
            break;
          }
        }
        
        if (found == null) return false;
        
        // 如果不是最后一项，需要有子级
        if (i < path.length - 1) {
          if (found is Map) {
            currentNode = found['children'] ?? [];
          } else {
            return false; // 字符串节点不应该有后续路径
          }
        }
      }
      
      return true;
    } catch (e) {
      iPrint('路径验证失败: $e');
      return false;
    }
  }

  /// 选择末级（叶子）节点
  /// 用途：将末级写入 selectedRegion 并计算 hasChanged
  /// 参数：regionName 末级名称
  /// 返回：void
  /// 异常：无
  /// 复杂度：O(1)
  void _selectLeafRegion(String regionName) {
    // 构建到叶子节点的完整路径
    final newPath = _buildSingleChainPath(regionName);
    
    // 验证路径有效性
    if (_isValidPath(newPath)) {
      selectedRegion.value = newPath.join(' ');
      regionPath.value = newPath;
      hasChanged.value = selectedRegion.value != _initialValue;
      RegionCache.saveSelectedRegion(selectedRegion.value);
      RegionCache.saveRegionPath(regionPath.value);
    } else {
      iPrint('选择的叶子节点路径无效: $newPath');
    }
  }

  /// 回滚到初始选择值
  /// 用途：在保存失败时恢复为进入页面前的选择，保持本地与缓存一致性
  /// 参数：无
  /// 返回：void
  /// 异常：无
  /// 复杂度：O(n)，按空格拆分恢复路径
  void revertToInitial() {
    selectedRegion.value = _initialValue;
    if (_initialValue.isNotEmpty) {
      final initialPath = _initialValue.split(' ').where((e) => e.trim().isNotEmpty).toList();
      // 验证初始路径的有效性
      if (_isValidPath(initialPath)) {
        regionPath.value = initialPath;
      } else {
        // 初始路径无效时清空
        regionPath.clear();
        selectedRegion.value = '';
        iPrint('初始路径无效，已清空: $_initialValue');
      }
    } else {
      regionPath.clear();
    }
    hasChanged.value = false;
    
    // 同步缓存状态
    RegionCache.saveSelectedRegion(selectedRegion.value);
    RegionCache.saveRegionPath(regionPath.value);
  }

  /// 更新地区数据（后端对接占位方法）
  /// 用途：从后端获取最新的地区数据并更新本地缓存
  /// 参数：无
  /// 返回：Future<bool> 更新是否成功
  /// 异常：网络异常时返回 false
  /// 复杂度：O(n) 取决于数据量大小
  /// 
  /// TODO: 待后端接口确认后实现真实的网络请求
  Future<bool> updateRegionDataFromServer() async {
    try {
      iPrint('开始从服务器更新地区数据...');
      
      // 占位：模拟网络请求延迟
      await Future.delayed(const Duration(milliseconds: 500));
      
      // TODO: 实现真实的 HTTP 请求
      // final response = await http.get(Uri.parse('$baseUrl/api/regions'));
      // if (response.statusCode == 200) {
      //   final List<dynamic> serverData = json.decode(response.body);
      //   
      //   // 验证服务器数据格式
      //   if (_isValidRegionStructure(serverData)) {
      //     _fullRegionList = serverData;
      //     regionList.value = serverData;
      //     await RegionCache.saveRegionList(serverData);
      //     iPrint('地区数据更新成功');
      //     return true;
      //   } else {
      //     iPrint('服务器返回的地区数据格式无效');
      //     return false;
      //   }
      // } else {
      //   iPrint('服务器返回错误: ${response.statusCode}');
      //   return false;
      // }
      
      // 占位实现：直接返回成功
      iPrint('地区数据更新完成（占位实现）');
      return true;
      
    } catch (e) {
      iPrint('更新地区数据失败: $e');
      return false;
    }
  }

  /// 同步选择的地区到服务器（后端对接占位方法）
  /// 用途：将用户选择的地区信息同步到服务器
  /// 参数：
  /// - selectedRegionStr: 选择的地区字符串（如"中国大陆 北京 朝阳区"）
  /// 返回：Future<bool> 同步是否成功
  /// 异常：网络异常时返回 false
  /// 复杂度：O(1)
  /// 
  /// TODO: 待后端接口确认后实现真实的网络请求
  Future<bool> syncSelectedRegionToServer(String selectedRegionStr) async {
    try {
      iPrint('开始同步地区选择到服务器: $selectedRegionStr');
      
      // 占位：模拟网络请求延迟
      await Future.delayed(const Duration(milliseconds: 300));
      
      // TODO: 实现真实的 HTTP 请求
      // final requestBody = {
      //   'region': selectedRegionStr,
      //   'regionPath': regionPath.value,
      //   'timestamp': DateTime.now().millisecondsSinceEpoch,
      // };
      // 
      // final response = await http.post(
      //   Uri.parse('$baseUrl/api/user/region'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: json.encode(requestBody),
      // );
      // 
      // if (response.statusCode == 200) {
      //   iPrint('地区选择同步成功');
      //   return true;
      // } else {
      //   iPrint('地区选择同步失败: ${response.statusCode}');
      //   return false;
      // }
      
      // 占位实现：直接返回成功
      iPrint('地区选择同步完成（占位实现）');
      return true;
      
    } catch (e) {
      iPrint('同步地区选择失败: $e');
      return false;
    }
  }

  /// 检查地区数据版本（后端对接占位方法）
  /// 用途：检查本地地区数据是否为最新版本
  /// 参数：无
  /// 返回：Future<bool> 是否需要更新
  /// 异常：网络异常时返回 false
  /// 复杂度：O(1)
  /// 
  /// TODO: 待后端接口确认后实现真实的版本检查
  Future<bool> checkRegionDataVersion() async {
    try {
      iPrint('检查地区数据版本...');
      
      // 占位：模拟网络请求延迟
      await Future.delayed(const Duration(milliseconds: 200));
      
      // TODO: 实现真实的版本检查
      // final response = await http.get(Uri.parse('$baseUrl/api/regions/version'));
      // if (response.statusCode == 200) {
      //   final versionInfo = json.decode(response.body);
      //   final serverVersion = versionInfo['version'] ?? '';
      //   final localVersion = await RegionCache.getDataVersion();
      //   
      //   final needUpdate = serverVersion != localVersion;
      //   iPrint('服务器版本: $serverVersion, 本地版本: $localVersion, 需要更新: $needUpdate');
      //   return needUpdate;
      // } else {
      //   iPrint('版本检查失败: ${response.statusCode}');
      //   return false;
      // }
      
      // 占位实现：随机返回是否需要更新
      final needUpdate = DateTime.now().millisecond % 2 == 0;
      iPrint('版本检查完成（占位实现），需要更新: $needUpdate');
      return needUpdate;
      
    } catch (e) {
      iPrint('检查地区数据版本失败: $e');
      return false;
    }
  }
}

/// 子级地区页面（带搜索与逐级进入）
///
/// 独立于 SetRegionPage，避免改动现有视图；支持：
/// - 当前层级搜索（省/市/区其中一层）
/// - 继续逐级进入
/// - 末级直接选择，保存按钮通过 onSave 触发
class _SubRegionPage extends StatefulWidget {
  final String title;
  final List children;
  final List<String> parentPath;
  final Function(List<String>) onRegionSelected;
  final Future<bool> Function(String) onSave;

  const _SubRegionPage({
    required this.title,
    required this.children,
    required this.parentPath,
    required this.onRegionSelected,
    required this.onSave,
  });

  @override
  State<_SubRegionPage> createState() => _SubRegionPageState();
}

class _SubRegionPageState extends State<_SubRegionPage> {
  late List _source;
  late List _list;
  final TextEditingController _searchC = TextEditingController();
  final FocusNode _searchF = FocusNode();
  Timer? _debounce;
  // 列表键盘导航与滚动支持
  final ScrollController _scrollC = ScrollController();
  final FocusNode _listF = FocusNode();
  int _highlight = -1;
  static const double _kItemExtent = 56.0;

  @override
  void initState() {
    super.initState();
    _source = List.from(widget.children);
    _list = List.from(_source);
    _searchC.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.removeListener(_onQueryChanged);
    _searchC.dispose();
    _searchF.dispose();
    _scrollC.dispose();
    _listF.dispose();
    super.dispose();
  }

  /// 搜索关键字变更
  /// 用途：500ms 防抖过滤当前层级
  /// 参数：无（读取 _searchC.text）
  /// 返回：void
  /// 异常：无
  /// 复杂度：O(n)
  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final kw = _searchC.text.trim();
      if (kw.isEmpty) {
        setState(() => _list = List.from(_source));
        return;
      }
      setState(() {
        _list = _filterLevel(_source, kw);
      });
    });
  }

  /// 在当前层级执行过滤
  /// 用途：与 SetRegionLogic.filterInLevel 一致，但为局部实现，避免依赖控制器
  /// 参数：source 层级列表；keyword 关键字
  /// 返回：过滤列表
  /// 复杂度：O(n*m)
  List<dynamic> _filterLevel(List<dynamic> source, String keyword) {
    final lc = keyword.toLowerCase();
    final out = <dynamic>[];

    for (final item in source) {
      if (item is String) {
        if (item.toLowerCase().contains(lc)) {
          out.add(item);
        }
      } else if (item is Map) {
        final title = (item['title'] ?? '').toString();
        final children = (item['children'] ?? []) as List;

        if (title.toLowerCase().contains(lc)) {
          out.add(item);
          continue;
        }

        final matchedChildren = <dynamic>[];
        for (final c in children) {
          if (c is String) {
            if (c.toLowerCase().contains(lc)) {
              matchedChildren.add(c);
            }
          } else if (c is Map) {
            final ct = (c['title'] ?? '').toString();
            if (ct.toLowerCase().contains(lc)) {
              matchedChildren.add(c);
              continue;
            }
            final gc = (c['children'] ?? []) as List;
            final matchedGrand = <dynamic>[];
            for (final g in gc) {
              if (g is String && g.toLowerCase().contains(lc)) {
                matchedGrand.add(g);
              }
            }
            if (matchedGrand.isNotEmpty) {
              matchedChildren.add({'title': ct, 'children': matchedGrand});
            }
          }
        }

        if (matchedChildren.isNotEmpty) {
          out.add({'title': title, 'children': matchedChildren});
        }
      }
    }
    return out;
  }

  /// 处理点击：继续进入或选择末级
  /// 用途：根据类型判断是否还有 children
  /// 参数：model 当前项；path 路径
  /// 返回：void
  /// 异常：无
  /// 复杂度：O(1)
  void _onTap(dynamic model, List<String> path) async {
    String title = '';
    List children = [];
    if (model is String) {
      title = model;
    } else if (model is Map) {
      title = (model['title'] ?? '').toString();
      children = (model['children'] ?? []) as List;
    }
    title = title.trim();

    if (children.isNotEmpty) {
      // 继续进入下一级：确保路径连续性
      final newPath = _buildConsistentPath(path, title);
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => _SubRegionPage(
            title: title,
            children: children,
            parentPath: newPath,
            onRegionSelected: widget.onRegionSelected,
            onSave: widget.onSave,
          ),
        ),
      );
    } else {
      // 末级选择：构建完整路径
      final selectedPath = _buildConsistentPath(path, title);
      widget.onRegionSelected(selectedPath);
      setState(() {}); // 刷新一下右侧勾选
    }
  }

  /// 构建一致的路径
  /// 用途：确保路径连续且不重复
  /// 参数：
  /// - currentPath: 当前路径
  /// - newItem: 新增项
  /// 返回：List<String> 一致的路径
  /// 复杂度：O(n)
  List<String> _buildConsistentPath(List<String> currentPath, String newItem) {
    final result = List<String>.from(currentPath);
    
    // 检查新项是否已在路径中
    final existingIndex = result.indexOf(newItem);
    if (existingIndex >= 0) {
      // 如果已存在，截取到该位置（避免重复和循环）
      return result.sublist(0, existingIndex + 1);
    }
    
    // 新项不在路径中，直接追加
    result.add(newItem);
    return result;
  }

  /// 是否为当前已选路径末端
  bool _isSelected(String title) {
    final current = Get.find<SetRegionLogic>().selectedRegion.value;
    final parts = current.split(' ').where((e) => e.trim().isNotEmpty).toList();
    return parts.contains(title);
  }

  /// 处理键盘事件（子页）
  /// 用途：↑/↓ 移动高亮、Enter 选择当前项、Esc 返回、Tab 焦点切换
  /// 参数：node 当前焦点节点；event 键盘事件
  /// 返回：KeyEventResult
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    
    // Tab 键焦点切换：搜索框 <-> 列表
    if (key == LogicalKeyboardKey.tab) {
      if (_searchF.hasFocus) {
        _listF.requestFocus();
      } else {
        _searchF.requestFocus();
      }
      return KeyEventResult.handled;
    }

    // 搜索框聚焦时，仅处理 Tab 和 Esc
    if (_searchF.hasFocus) {
      if (key == LogicalKeyboardKey.escape) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // 列表焦点时的导航键
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _onEnterSelect();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 高亮移动
  /// 用途：在列表中移动高亮项并滚动到可见位置
  /// 参数：delta 步长（+1 或 -1）
  /// 返回：void
  void _moveHighlight(int delta) {
    final total = _list.length;
    if (total == 0) return;
    int next = _highlight;
    if (next < 0) {
      next = delta > 0 ? 0 : total - 1;
    } else {
      next = (next + delta).clamp(0, total - 1);
    }
    setState(() {
      _highlight = next;
    });
    final maxScroll = _scrollC.hasClients ? _scrollC.position.maxScrollExtent : 0.0;
    final target = (_kItemExtent * next).clamp(0.0, maxScroll);
    if (_scrollC.hasClients) {
      _scrollC.animateTo(
        target,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  /// 回车选择当前高亮项
  /// 用途：触发与点击相同的逻辑
  /// 参数：无
  /// 返回：void
  void _onEnterSelect() {
    if (_highlight < 0 || _highlight >= _list.length) return;
    final item = _list[_highlight];
    _onTap(item, widget.parentPath);
  }

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<SetRegionLogic>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Obx(() {
            final enable = logic.hasChanged.value;
            return TextButton(
              onPressed: enable
                  ? () async {
                      final ok = await widget.onSave(logic.selectedRegion.value);
                      if (ok && mounted) {
                        Navigator.of(context).pop();
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('operationFailedAgainLater'.tr)),
                          );
                          logic.revertToInitial();
                        }
                      }
                    }
                  : null,
              child: Text(
                'buttonAccomplish'.tr,
                style: TextStyle(
                  color: enable
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                ),
              ),
            );
          }),
        ],
      ),
      body: Focus(
        focusNode: _listF,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Semantics(
              label: '${'searchRegion'.tr} - ${'regionSearchHint'.tr}',
              hint: 'regionSearchHint'.tr,
              textField: true,
              child: TextField(
                controller: _searchC,
                focusNode: _searchF,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'regionSearchHint'.tr,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _onQueryChanged(),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: _scrollC,
              itemCount: _list.length,
              separatorBuilder: (_, __) => Divider(
                height: 0.5,
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                final item = _list[index];
                String title = '';
                List children = [];
                if (item is String) {
                  title = item;
                } else if (item is Map) {
                  title = (item['title'] ?? '').toString();
                  children = (item['children'] ?? []) as List;
                }
                final hasChildren = children.isNotEmpty;
                final selected = _isSelected(title);

                return Semantics(
                  label: hasChildren 
                      ? '$title - ${children.length} ${'region'.tr}'
                      : title,
                  hint: hasChildren 
                      ? '${'buttonContinue'.tr}${'searchRegion'.tr}'
                      : selected 
                          ? '${'selected'.tr}${'region'.tr}'
                          : '${'buttonConfirm'.tr}${'region'.tr}',
                  button: true,
                  selected: selected,
                  focusable: true,
                  child: Material(
                    color: index == _highlight
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    child: ListTile(
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      trailing: hasChildren
                          ? Icon(
                              Icons.navigate_next, 
                              size: 20,
                              semanticLabel: 'buttonContinue'.tr,
                            )
                          : (selected
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).colorScheme.primary,
                                  semanticLabel: 'selected'.tr,
                                )
                              : null),
                      onTap: () => _onTap(item, widget.parentPath),
                      focusColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                      // 键盘高亮时的视觉指示
                      tileColor: index == _highlight
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                          : null,
                      shape: index == _highlight
                          ? RoundedRectangleBorder(
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2.0,
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    )
    );
  }
}