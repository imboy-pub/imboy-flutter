/// 覆盖率追踪器 - 追踪测试覆盖率
library;

import 'dart:convert';
import 'test_path.dart';

/// 覆盖率指标
class CoverageMetric {
  /// 指标名称
  final String name;

  /// 已覆盖数量
  final int covered;

  /// 总数量
  final int total;

  /// 覆盖率 (0.0 - 1.0)
  double get coverage => total > 0 ? covered / total : 0.0;

  /// 覆盖率百分比
  int get coveragePercent => (coverage * 100).round();

  const CoverageMetric({
    required this.name,
    required this.covered,
    required this.total,
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'covered': covered,
      'total': total,
      'coverage': coverage,
      'coveragePercent': coveragePercent,
    };
  }

  /// 从 JSON 创建
  factory CoverageMetric.fromJson(Map<String, dynamic> json) {
    return CoverageMetric(
      name: json['name'] as String,
      covered: json['covered'] as int,
      total: json['total'] as int,
    );
  }

  @override
  String toString() => '$name: $coveragePercent% ($covered/$total)';
}

/// 元素覆盖记录
class ElementCoverage {
  /// 元素选择器
  final String selector;

  /// 元素类型
  final String elementType;

  /// 访问次数
  int visitCount = 0;

  /// 最后访问时间
  DateTime? lastVisitedAt;

  /// 涉及的测试路径
  final List<String> pathIds = [];

  /// 交互类型
  final Set<String> interactionTypes = {};

  ElementCoverage({
    required this.selector,
    required this.elementType,
  });

  /// 记录访问
  void recordVisit({
    required String pathId,
    required String interactionType,
  }) {
    visitCount++;
    lastVisitedAt = DateTime.now();
    if (!pathIds.contains(pathId)) {
      pathIds.add(pathId);
    }
    interactionTypes.add(interactionType);
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'selector': selector,
      'elementType': elementType,
      'visitCount': visitCount,
      'lastVisitedAt': lastVisitedAt?.toIso8601String(),
      'pathIds': pathIds,
      'interactionTypes': interactionTypes.toList(),
    };
  }

  /// 从 JSON 创建
  factory ElementCoverage.fromJson(Map<String, dynamic> json) {
    final coverage = ElementCoverage(
      selector: json['selector'] as String,
      elementType: json['elementType'] as String,
    );
    coverage.visitCount = json['visitCount'] as int? ?? 0;
    coverage.lastVisitedAt = json['lastVisitedAt'] != null
        ? DateTime.parse(json['lastVisitedAt'] as String)
        : null;
    coverage.pathIds.addAll((json['pathIds'] as List?)?.cast<String>() ?? []);
    coverage.interactionTypes.addAll(
      (json['interactionTypes'] as List?)?.cast<String>() ?? [],
    );
    return coverage;
  }
}

/// 模块覆盖记录
class ModuleCoverage {
  /// 模块名称
  final String name;

  /// 总元素数
  int totalElements = 0;

  /// 已覆盖元素数
  int coveredElements = 0;

  /// 覆盖的元素
  final Map<String, ElementCoverage> elements = {};

  /// 子模块
  final Map<String, ModuleCoverage> subModules = {};

  ModuleCoverage({required this.name});

  /// 获取覆盖率
  double get coverage =>
      totalElements > 0 ? coveredElements / totalElements : 0.0;

  /// 添加元素
  void addElement(String selector, String elementType) {
    if (!elements.containsKey(selector)) {
      totalElements++;
      elements[selector] = ElementCoverage(
        selector: selector,
        elementType: elementType,
      );
    }
  }

  /// 覆盖元素
  void coverElement({
    required String selector,
    required String pathId,
    required String interactionType,
  }) {
    final element = elements[selector];
    if (element != null) {
      if (element.visitCount == 0) {
        coveredElements++;
      }
      element.recordVisit(
        pathId: pathId,
        interactionType: interactionType,
      );
    }
  }

  /// 获取或创建子模块
  ModuleCoverage getOrCreateSubModule(String name) {
    if (!subModules.containsKey(name)) {
      subModules[name] = ModuleCoverage(name: name);
    }
    return subModules[name]!;
  }

  /// �换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'totalElements': totalElements,
      'coveredElements': coveredElements,
      'coverage': coverage,
      'elements': elements.map((k, v) => MapEntry(k, v.toJson())),
      'subModules': subModules.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  /// 从 JSON 创建
  factory ModuleCoverage.fromJson(Map<String, dynamic> json) {
    final coverage = ModuleCoverage(name: json['name'] as String);
    coverage.totalElements = json['totalElements'] as int? ?? 0;
    coverage.coveredElements = json['coveredElements'] as int? ?? 0;

    final elementsMap = json['elements'] as Map<String, dynamic>?;
    if (elementsMap != null) {
      elementsMap.forEach((key, value) {
        coverage.elements[key] =
            ElementCoverage.fromJson(value as Map<String, dynamic>);
      });
    }

    final subModulesMap = json['subModules'] as Map<String, dynamic>?;
    if (subModulesMap != null) {
      subModulesMap.forEach((key, value) {
        coverage.subModules[key] =
            ModuleCoverage.fromJson(value as Map<String, dynamic>);
      });
    }

    return coverage;
  }
}

/// 覆盖率追踪器
class CoverageTracker {
  final Map<String, ModuleCoverage> _modules = {};

  /// 已执行的路径 ID
  final Set<String> _executedPathIds = {};

  /// 元素选择器到模块的映射
  final Map<String, String> _selectorToModule = {};

  /// 覆盖率阈值
  final double coverageThreshold;

  CoverageTracker({this.coverageThreshold = 0.8});

  /// 添加模块
  ModuleCoverage getOrCreateModule(String name) {
    if (!_modules.containsKey(name)) {
      _modules[name] = ModuleCoverage(name: name);
    }
    return _modules[name]!;
  }

  /// 注册元素
  void registerElement({
    required String module,
    required String selector,
    required String elementType,
    String? subModule,
  }) {
    final mod = getOrCreateModule(module);
    if (subModule != null) {
      final subMod = mod.getOrCreateSubModule(subModule);
      subMod.addElement(selector, elementType);
      _selectorToModule['$module/$subModule/$selector'] = '$module/$subModule';
    } else {
      mod.addElement(selector, elementType);
      _selectorToModule['$module/$selector'] = module;
    }
  }

  /// 记录元素访问
  void recordVisit({
    required String pathId,
    required String selector,
    required String interactionType,
  }) {
    // 查找元素所属模块
    String? moduleKey;
    for (final entry in _selectorToModule.entries) {
      if (entry.key.endsWith('/$selector')) {
        moduleKey = entry.value;
        break;
      }
    }

    if (moduleKey == null) {
      // 未注册的元素，记录到默认模块
      return;
    }

    final parts = moduleKey.split('/');
    if (parts.length == 1) {
      _modules[parts[0]]?.coverElement(
        selector: selector,
        pathId: pathId,
        interactionType: interactionType,
      );
    } else if (parts.length == 2) {
      _modules[parts[0]]?.getOrCreateSubModule(parts[1]).coverElement(
            selector: selector,
            pathId: pathId,
            interactionType: interactionType,
          );
    }

    _executedPathIds.add(pathId);
  }

  /// 记录路径执行
  void recordPathExecution(TestPath path) {
    for (final step in path.steps) {
      if (step.targetSelector != null) {
        recordVisit(
          pathId: path.id,
          selector: step.targetSelector!,
          interactionType: step.actionType.name,
        );
      }
    }
    _executedPathIds.add(path.id);
  }

  /// 获取模块覆盖率
  ModuleCoverage? getModuleCoverage(String name) {
    return _modules[name];
  }

  /// 获取所有模块覆盖率
  Map<String, ModuleCoverage> getAllModuleCoverage() {
    return Map.unmodifiable(_modules);
  }

  /// 计算总体覆盖率
  CoverageMetric calculateOverallCoverage() {
    var total = 0;
    var covered = 0;

    for (final module in _modules.values) {
      total += module.totalElements;
      covered += module.coveredElements;
    }

    return CoverageMetric(
      name: 'overall',
      covered: covered,
      total: total,
    );
  }

  /// 获取低覆盖率模块
  List<String> getLowCoverageModules({double threshold = 0.5}) {
    final result = <String>[];

    for (final entry in _modules.entries) {
      final module = entry.value;
      if (module.coverage < threshold && module.totalElements > 0) {
        result.add(entry.key);
      }
    }

    result.sort((a, b) {
      final coverageA = _modules[a]!.coverage;
      final coverageB = _modules[b]!.coverage;
      return coverageA.compareTo(coverageB);
    });

    return result;
  }

  /// 获取未覆盖元素
  List<String> getUncoveredElements() {
    final result = <String>[];

    for (final module in _modules.values) {
      for (final element in module.elements.values) {
        if (element.visitCount == 0) {
          result.add(element.selector);
        }
      }

      for (final subModule in module.subModules.values) {
        for (final element in subModule.elements.values) {
          if (element.visitCount == 0) {
            result.add('${subModule.name}: ${element.selector}');
          }
        }
      }
    }

    return result;
  }

  /// 是否达到覆盖率目标
  bool meetsCoverageGoal({double? threshold}) {
    final target = threshold ?? coverageThreshold;
    return calculateOverallCoverage().coverage >= target;
  }

  /// 获取覆盖率摘要
  Map<String, dynamic> getSummary() {
    final moduleMetrics = <String, CoverageMetric>{};

    for (final entry in _modules.entries) {
      final module = entry.value;
      moduleMetrics[entry.key] = CoverageMetric(
        name: entry.key,
        covered: module.coveredElements,
        total: module.totalElements,
      );
    }

    return {
      'overall': calculateOverallCoverage().toJson(),
      'modules': moduleMetrics.map((k, v) => MapEntry(k, v.toJson())),
      'executedPaths': _executedPathIds.length,
      'meetsGoal': meetsCoverageGoal(),
      'threshold': coverageThreshold,
    };
  }

  /// 导出为 JSON
  String exportToJson({bool pretty = true}) {
    final data = {
      'modules': _modules.map((k, v) => MapEntry(k, v.toJson())),
      'summary': getSummary(),
      'exportedAt': DateTime.now().toIso8601String(),
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data);
  }

  /// 清空追踪数据
  void clear() {
    _modules.clear();
    _executedPathIds.clear();
    _selectorToModule.clear();
  }
}
