import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/service/cache/region_cache.dart';
import 'package:imboy/i18n/strings.g.dart';

part 'set_region_provider.g.dart';

/// 设置地区状态
class SetRegionState {
  final List<dynamic> regionList;
  final String selectedRegion;
  final bool hasChanged;
  final List<String> regionPath;

  const SetRegionState({
    this.regionList = const [],
    this.selectedRegion = '',
    this.hasChanged = false,
    this.regionPath = const [],
  });

  SetRegionState copyWith({
    List<dynamic>? regionList,
    String? selectedRegion,
    bool? hasChanged,
    List<String>? regionPath,
  }) {
    return SetRegionState(
      regionList: regionList ?? this.regionList,
      selectedRegion: selectedRegion ?? this.selectedRegion,
      hasChanged: hasChanged ?? this.hasChanged,
      regionPath: regionPath ?? this.regionPath,
    );
  }
}

/// 设置地区 Provider
@riverpod
class SetRegionNotifier extends _$SetRegionNotifier {
  String _initialValue = '';
  List<dynamic> _fullRegionList = [];

  @override
  SetRegionState build() {
    _loadRegionData().then((_) async {
      final cachedSelected = await RegionCache.loadSelectedRegion();
      if (cachedSelected.isNotEmpty) {
        initData(cachedSelected);
      }
      final cachedPath = await RegionCache.loadRegionPath();
      if (cachedPath.isNotEmpty) {
        state = state.copyWith(regionPath: cachedPath);
      }
      final cachedList = await RegionCache.loadRegionList();
      if (cachedList.isNotEmpty) {
        final bool hasFull = _fullRegionList.isNotEmpty;
        final bool cachedOk = _isValidRegionStructure(cachedList);
        if (!cachedOk) {
          if (hasFull) {
            state = state.copyWith(regionList: _fullRegionList);
            await RegionCache.saveRegionList(_fullRegionList);
          } else {
            state = state.copyWith(regionList: cachedList);
          }
        } else if (hasFull &&
            !_isRegionListConsistent(cachedList, _fullRegionList)) {
          state = state.copyWith(regionList: _fullRegionList);
          await RegionCache.saveRegionList(_fullRegionList);
        } else {
          state = state.copyWith(regionList: cachedList);
        }
      } else {
        if (_fullRegionList.isNotEmpty) {
          state = state.copyWith(regionList: _fullRegionList);
        }
      }
    });
    return const SetRegionState();
  }

  /// 初始化数据
  void initData(String currentValue) {
    _initialValue = currentValue;
    state = state.copyWith(selectedRegion: currentValue, hasChanged: false);

    if (state.selectedRegion.isNotEmpty) {
      final path = state.selectedRegion
          .split(' ')
          .where((e) => e.trim().isNotEmpty)
          .toList();
      state = state.copyWith(regionPath: path);
    } else {
      state = state.copyWith(regionPath: []);
    }
  }

  /// 加载 assets/data/region.json
  Future<void> _loadRegionData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/region.json');
      final List<dynamic> data = json.decode(jsonString);
      _fullRegionList = data;
      state = state.copyWith(regionList: data);
      await RegionCache.saveRegionList(data);
    } catch (e) {
      iPrint('加载地区数据失败: $e');
    }
  }

  /// 判断某个名称是否已被选中（用于高亮）
  bool isRegionSelected(String regionName) {
    final parts = state.selectedRegion
        .split(' ')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return parts.contains(regionName);
  }

  /// 校验地区数据结构是否合法（递归）
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
  List<dynamic> filterInLevel(List<dynamic> source, String keyword) {
    final kw = keyword.trim();
    if (kw.isEmpty) return source;

    final lc = kw.toLowerCase();
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
  void applyTopSearch(String keyword) {
    final src = _fullRegionList;
    state = state.copyWith(regionList: filterInLevel(src, keyword));
  }

  /// 选择地区
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
  void _navigateToSubRegion(
    String parentName,
    List children,
    BuildContext context,
    Future<bool> Function(String) onSave,
  ) {
    final newPath = _buildSingleChainPath(parentName);

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => _SubRegionPage(
          title: parentName,
          children: children,
          parentPath: newPath,
          onRegionSelected: (selectedPath) {
            if (_isValidPath(selectedPath)) {
              state = state.copyWith(
                selectedRegion: selectedPath.join(' '),
                regionPath: selectedPath,
                hasChanged: selectedPath.join(' ') != _initialValue,
              );
              RegionCache.saveSelectedRegion(selectedPath.join(' '));
              RegionCache.saveRegionPath(selectedPath);
            }
          },
          onSave: onSave,
        ),
      ),
    );
  }

  /// 构建单一链路路径
  List<String> _buildSingleChainPath(String currentSelection) {
    final currentPath = List<String>.from(state.regionPath);

    if (currentPath.isEmpty) {
      return [currentSelection];
    }

    final existingIndex = currentPath.indexOf(currentSelection);
    if (existingIndex >= 0) {
      return currentPath.sublist(0, existingIndex + 1);
    }

    if (_isValidNextLevel(currentPath, currentSelection)) {
      return [...currentPath, currentSelection];
    }

    return [currentSelection];
  }

  /// 验证下一级选择是否有效
  bool _isValidNextLevel(List<String> currentPath, String nextSelection) {
    if (currentPath.isEmpty) return true;

    try {
      dynamic currentNode = _fullRegionList;

      for (final pathItem in currentPath) {
        if (currentNode is! List) return false;

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

        if (found is Map) {
          currentNode = found['children'] ?? [];
        } else {
          return false;
        }
      }

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
  bool _isValidPath(List<String> path) {
    if (path.isEmpty) return true;

    try {
      dynamic currentNode = _fullRegionList;

      for (int i = 0; i < path.length; i++) {
        final pathItem = path[i];
        if (currentNode is! List) return false;

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

        if (i < path.length - 1) {
          if (found is Map) {
            currentNode = found['children'] ?? [];
          } else {
            return false;
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
  void _selectLeafRegion(String regionName) {
    final newPath = _buildSingleChainPath(regionName);

    if (_isValidPath(newPath)) {
      state = state.copyWith(
        selectedRegion: newPath.join(' '),
        regionPath: newPath,
        hasChanged: newPath.join(' ') != _initialValue,
      );
      RegionCache.saveSelectedRegion(newPath.join(' '));
      RegionCache.saveRegionPath(newPath);
    } else {
      iPrint('选择的叶子节点路径无效: $newPath');
    }
  }

  /// 回滚到初始选择值
  void revertToInitial() {
    state = state.copyWith(selectedRegion: _initialValue, hasChanged: false);

    if (_initialValue.isNotEmpty) {
      final initialPath = _initialValue
          .split(' ')
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (_isValidPath(initialPath)) {
        state = state.copyWith(regionPath: initialPath);
      } else {
        state = state.copyWith(regionPath: [], selectedRegion: '');
        iPrint('初始路径无效，已清空: $_initialValue');
      }
    } else {
      state = state.copyWith(regionPath: []);
    }

    RegionCache.saveSelectedRegion(_initialValue);
    RegionCache.saveRegionPath(state.regionPath);
  }
}

/// 子级地区页面
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
  final ScrollController _scrollC = ScrollController();
  final FocusNode _listF = FocusNode();

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
      final selectedPath = _buildConsistentPath(path, title);
      widget.onRegionSelected(selectedPath);
      setState(() {});
    }
  }

  List<String> _buildConsistentPath(List<String> currentPath, String newItem) {
    final result = List<String>.from(currentPath);

    final existingIndex = result.indexOf(newItem);
    if (existingIndex >= 0) {
      return result.sublist(0, existingIndex + 1);
    }

    result.add(newItem);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: widget.title,
        rightDMActions: [
          TextButton(
            onPressed: () async {
              // 这里需要访问 Provider，暂时简化处理
              final ok = await widget.onSave(widget.parentPath.join(' '));
              if (ok && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(t.buttonAccomplish),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchC,
              focusNode: _searchF,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: t.regionSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _onQueryChanged(),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: _scrollC,
              itemCount: _list.length,
              separatorBuilder: (_, i) => Divider(
                height: 0.5,
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
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

                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(title),
                    trailing: hasChildren
                        ? const Icon(Icons.navigate_next, size: 20)
                        : null,
                    onTap: () => _onTap(item, widget.parentPath),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
