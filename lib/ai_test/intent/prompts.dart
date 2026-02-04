/// AI 提示词模板
library;

import '../healing/failure_analyzer.dart' show FailureDetails;

/// 提示词模板类
class Prompts {
  /// 从用户故事生成测试用例的提示词
  static String generateTestsFromUserStory(String userStory) => '''
你是一位资深的 Flutter 测试工程师，精通集成测试和用户行为分析。

# 任务
请分析以下用户故事，生成全面的测试用例。

# 用户故事
$userStory

# 要求

## 测试类型覆盖
请生成以下类型的测试用例：
1. **正常路径测试** - 验证核心功能正常工作
2. **边缘情况测试** - 边界值、空输入、极端场景
3. **异常处理测试** - 网络错误、权限问题、数据异常

## 测试用例结构

每个测试用例必须包含：
- **name**: 测试名称（简洁描述，如"用户发送文本消息"）
- **description**: 测试描述（详细说明测试目的）
- **type**: 测试类型（normal/edge/error）
- **priority**: 优先级（high/medium/low）
- **preconditions**: 前置条件列表（如 ["用户已登录", "已添加好友"]）
- **steps**: 测试步骤列表
  - **action**: 操作描述（具体、可执行）
  - **expected**: 预期结果（可验证）
- **test_data**: 测试数据示例

## 输出格式

严格按以下 JSON 格式输出，不要包含任何其他文字：

```json
{
  "test_cases": [
    {
      "name": "测试名称",
      "description": "测试描述",
      "type": "normal",
      "priority": "high",
      "preconditions": ["前置条件1", "前置条件2"],
      "steps": [
        {"action": "操作描述", "expected": "预期结果"}
      ],
      "test_data": {"key": "value"}
    }
  ]
}
```

## 注意事项

1. 测试步骤要具体、可操作、可验证
2. 预期结果要明确、可检查
3. 优先级标注要合理
4. 前置条件要完整列出
5. 测试数据要真实有效

# 现在请生成测试用例...
''';

  /// 分析测试失败原因的提示词（使用 FailureDetails）
  static String analyzeFailure(dynamic failureDetails) => '''
你是一位资深的测试工程师和调试专家，精通 Flutter 集成测试。

# 任务
分析以下测试失败信息，提供根本原因分析和修复建议。

# 失败详情

**失败类型**: ${failureDetails is FailureDetails ? failureDetails.type.name : 'unknown'}

**错误信息**:
```
${failureDetails is FailureDetails ? failureDetails.errorMessage : failureDetails.toString()}
```

${failureDetails is FailureDetails && failureDetails.stackTrace != null ? '''
**堆栈跟踪**:
```
${failureDetails.stackTrace}
```
''' : ''}

${failureDetails is FailureDetails && failureDetails.failingStep != null ? '''
**失败的步骤**: ${failureDetails.failingStep}
''' : ''}

${failureDetails is FailureDetails && failureDetails.selector != null ? '''
**相关选择器**: ${failureDetails.selector}
''' : ''}

${failureDetails is FailureDetails && failureDetails.expectedValue != null ? '''
**期望值**: ${failureDetails.expectedValue}
**实际值**: ${failureDetails.actualValue}
''' : ''}

# 分析要求

## 失败原因分类
请将失败归类为以下类型之一：
- **elementNotFound**: 元素未找到（UI 元素找不到）
- **timeout**: 超时（操作或等待超时）
- **assertionFailure**: 断言失败（期望值与实际值不匹配）
- **networkError**: 网络错误（连接问题）
- **permissionError**: 权限错误（权限不足）
- **selectorInvalid**: 选择器失效（选择器语法错误或元素变化）
- **stateMismatch**: 状态不匹配（应用状态异常）
- **unknown**: 未知错误

## 愈合策略推荐
请推荐以下策略之一：
- **retry**: 重试操作（可能暂时性问题）
- **wait**: 等待（元素可能正在加载）
- **selectorUpdate**: 更新选择器（UI 结构变化）
- **fallback**: 使用回退方案（备用方法）
- **skip**: 跳过此步骤（非关键步骤）

## 分析内容
1. **根本原因**: 最可能的失败原因
2. **置信度**: 分析的可信程度 (high/medium/low)
3. **推荐策略**: 首选愈合策略
4. **修复建议**: 具体的修复步骤

# 输出格式

请以简洁的文字输出分析结果，格式如下：

```
根本原因: [具体描述]
置信度: [high/medium/low]
推荐策略: [策略名称]
修复建议: [具体步骤]
```

# 现在请分析...
''';

  /// 分析测试失败原因的提示词（已弃用，使用上面的方法）
  @Deprecated('Use analyzeFailure(FailureDetails) instead')
  static String analyzeFailureWithDetails({
    required String testName,
    required String errorMessage,
    required String stackTrace,
    String? screenshotContext,
  }) => '''
你是一位资深的测试工程师和调试专家，精通 Flutter 集成测试。

# 任务
分析以下测试失败信息，提供根本原因分析和修复建议。

# 测试信息

**测试名称**: $testName

**错误信息**:
```
$errorMessage
```

**堆栈跟踪**:
```
$stackTrace
```

${screenshotContext != null ? '''
**截图上下文**:
$screenshotContext
''' : ''}

# 分析要求

## 失败类型分类
请将失败归类为以下类型之一：
- **selectorHealing**: 选择器失效（UI 元素找不到）
- **timeout**: 超时（操作或等待超时）
- **dataError**: 数据错误（测试数据问题）
- **logicError**: 逻辑错误（业务逻辑问题）
- **networkError**: 网络错误（连接问题）
- **other**: 其他（未分类问题）

## 根因分析
1. 识别最可能的根本原因
2. 分析为什么会出现这个问题
3. 提供详细的技术解释

## 修复建议
1. 提供具体的修复步骤
2. 推荐最佳实践
3. 给出预防措施

# 输出格式

```json
{
  "type": "selectorHealing",
  "rootCause": "根本原因详细描述",
  "recommendedFix": "具体修复步骤和代码示例",
  "confidence": 0.85
}
```

# 现在请分析...
''';

  /// 从 API 文档生成测试用例
  static String generateTestsFromApiDoc(String apiDoc) => '''
你是一位资深的 API 测试工程师。

# 任务
根据以下 API 文档，生成全面的 API 测试用例。

# API 文档
$apiDoc

# 测试要求

## 测试类型
1. **正常请求测试** - 有效参数、正常返回
2. **参数验证测试** - 缺失参数、无效参数、边界值
3. **认证授权测试** - 无 Token、过期 Token、权限不足
4. **错误处理测试** - 服务器错误、网络异常

## 测试用例结构
同上（参考用户故事格式）

# 输出格式
```json
{
  "test_cases": [...]
}
```

# 现在请生成...
''';

  /// 优化现有测试用例
  static String optimizeTests(String existingTests, String testGoals) => '''
你是一位资深的测试架构师。

# 任务
优化以下现有测试用例，使其更完善和高效。

# 现有测试
$existingTests

# 测试目标
$testGoals

# 优化方向

1. **去重合并** - 识别并合并重复的测试
2. **增强覆盖** - 识别测试缺口并补充
3. **优化优先级** - 根据风险调整优先级
4. **改进步骤** - 优化测试步骤的可读性和可维护性
5. **数据优化** - 改进测试数据的有效性

# 输出格式
```json
{
  "optimized_tests": [...],
  "removed_tests": [...],
  "added_tests": [...],
  "recommendations": [...]
}
```

# 现在请优化...
''';

  /// 从 UI 设计稿生成测试
  static String generateTestsFromDesign(String designDescription) => '''
你是一位资深的 UI/UX 测试工程师。

# 任务
根据以下 UI 设计描述，生成全面的 UI 测试用例。

# 设计描述
$designDescription

# 测试重点

1. **布局测试** - 响应式布局、不同屏幕尺寸
2. **交互测试** - 点击、滑动、输入等交互行为
3. **视觉测试** - 颜色、字体、间距等视觉效果
4. **可访问性** - 字体大小、对比度、标签
5. **状态变化** - 加载、成功、错误等状态

# 输出格式
```json
{
  "test_cases": [...]
}
```

# 现在请生成...
''';

  /// 生成测试数据
  static String generateTestData(String dataType, String context) => '''
你是一位测试数据专家。

# 任务
生成用于测试的数据。

# 数据类型
$dataType

# 上下文
$context

# 要求

1. 数据要真实、有效、符合业务规则
2. 包含边界值和极端情况
3. 覆盖各种字符编码（中文、特殊符号）
4. 数据长度要合理（不过长也不过短）

# 输出格式
```json
{
  "test_data": {...}
}
```

# 现在请生成...
''';

  /// 生成测试报告摘要
  static String generateTestSummary(Map<String, dynamic> testResults) => '''
你是一位测试分析师。

# 任务
生成测试报告摘要。

# 测试结果
${testResults.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}

# 要求

1. **概览统计** - 总数、通过数、失败数
2. **通过率** - 百分比
3. **关键发现** - 重要的问题和模式
4. **建议** - 改进建议

请生成简洁的报告摘要。
''';
}
