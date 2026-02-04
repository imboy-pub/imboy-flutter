// HTML 测试报告生成器
//
// 生成漂亮的 HTML 测试报告，包含：
// - 测试概览
// - 详细步骤
// - 截图展示
// - 错误分析

import 'dart:io';
import 'test_enhanced_helper.dart';

class TestHtmlReporter {
  final String outputDir;
  final String reportPath;

  TestHtmlReporter({this.outputDir = 'test_output'})
    : reportPath = '$outputDir/report.html';

  /// 生成 HTML 报告
  Future<void> generate(List<TestSession> sessions) async {
    final html = _generateHtml(sessions);
    final file = File(reportPath);
    await file.writeAsString(html);
    print('📄 HTML 报告已生成: ${file.absolute.path}');
  }

  String _generateHtml(List<TestSession> sessions) {
    final totalTests = sessions.length;
    final passedTests = sessions.where((s) => s.passed == true).length;
    final failedTests = sessions.where((s) => s.passed == false).length;
    sessions.fold(0, (sum, s) => sum + s.steps.length); // totalSteps calculated
    sessions.fold(
      0,
      (sum, s) => sum + s.steps.where((step) => step.success).length,
    ); // successfulSteps calculated
    final passRate = totalTests > 0 ? (passedTests / totalTests * 100) : 0;

    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IM Boy 测试报告</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        .header {
            background: white;
            border-radius: 16px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }

        .header h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 32px;
        }

        .header .subtitle {
            color: #666;
            font-size: 14px;
        }

        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .summary-card {
            background: white;
            border-radius: 12px;
            padding: 24px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            text-align: center;
            transition: transform 0.2s;
        }

        .summary-card:hover {
            transform: translateY(-4px);
        }

        .summary-card .value {
            font-size: 48px;
            font-weight: bold;
            margin-bottom: 8px;
        }

        .summary-card .label {
            color: #666;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .summary-card.total .value { color: #667eea; }
        .summary-card.passed .value { color: #10b981; }
        .summary-card.failed .value { color: #ef4444; }
        .summary-card.rate .value { color: #f59e0b; }

        .test-list {
            background: white;
            border-radius: 16px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }

        .test-item {
            border: 1px solid #e5e7eb;
            border-radius: 12px;
            margin-bottom: 20px;
            overflow: hidden;
            transition: all 0.3s;
        }

        .test-item:last-child {
            margin-bottom: 0;
        }

        .test-item.passed {
            border-left: 4px solid #10b981;
        }

        .test-item.failed {
            border-left: 4px solid #ef4444;
        }

        .test-header {
            padding: 20px;
            background: #f9fafb;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            user-select: none;
        }

        .test-header:hover {
            background: #f3f4f6;
        }

        .test-info h3 {
            color: #333;
            font-size: 18px;
            margin-bottom: 4px;
        }

        .test-info p {
            color: #666;
            font-size: 14px;
        }

        .test-status {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .status-badge {
            padding: 6px 16px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 600;
        }

        .status-badge.passed {
            background: #d1fae5;
            color: #065f46;
        }

        .status-badge.failed {
            background: #fee2e2;
            color: #991b1b;
        }

        .test-body {
            display: none;
            padding: 20px;
            border-top: 1px solid #e5e7eb;
        }

        .test-item.active .test-body {
            display: block;
        }

        .step-list {
            margin-top: 20px;
        }

        .step-item {
            padding: 12px;
            margin-bottom: 12px;
            border-radius: 8px;
            background: #f9fafb;
            border-left: 3px solid #d1d5db;
        }

        .step-item.success {
            border-left-color: #10b981;
        }

        .step-item.error {
            border-left-color: #ef4444;
            background: #fef2f2;
        }

        .step-name {
            font-weight: 600;
            color: #333;
            margin-bottom: 4px;
        }

        .step-desc {
            color: #666;
            font-size: 14px;
            margin-bottom: 8px;
        }

        .step-error {
            color: #dc2626;
            font-size: 14px;
            padding: 8px;
            background: #fee2e2;
            border-radius: 6px;
            margin-top: 8px;
        }

        .step-screenshot {
            margin-top: 12px;
        }

        .step-screenshot img {
            max-width: 300px;
            border-radius: 8px;
            border: 2px solid #e5e7eb;
            cursor: pointer;
            transition: transform 0.2s;
        }

        .step-screenshot img:hover {
            transform: scale(1.05);
        }

        .filter-bar {
            display: flex;
            gap: 12px;
            margin-bottom: 20px;
        }

        .filter-btn {
            padding: 10px 20px;
            border: none;
            border-radius: 8px;
            background: #f3f4f6;
            color: #666;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
        }

        .filter-btn:hover {
            background: #e5e7eb;
        }

        .filter-btn.active {
            background: #667eea;
            color: white;
        }

        .progress-bar {
            height: 8px;
            background: #e5e7eb;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 20px;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #10b981, #667eea);
            transition: width 0.5s;
        }

        @media (max-width: 768px) {
            .summary {
                grid-template-columns: 1fr 1fr;
            }

            .header h1 {
                font-size: 24px;
            }

            .summary-card .value {
                font-size: 36px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 IM Boy 测试报告</h1>
            <p class="subtitle">生成时间: ${DateTime.now().toLocal().toString().substring(0, 19)}</p>
            <div class="progress-bar">
                <div class="progress-fill" style="width: $passRate%"></div>
            </div>
        </div>

        <div class="summary">
            <div class="summary-card total">
                <div class="value">$totalTests</div>
                <div class="label">总测试数</div>
            </div>
            <div class="summary-card passed">
                <div class="value">$passedTests</div>
                <div class="label">通过</div>
            </div>
            <div class="summary-card failed">
                <div class="value">$failedTests</div>
                <div class="label">失败</div>
            </div>
            <div class="summary-card rate">
                <div class="value">${passRate.toStringAsFixed(1)}%</div>
                <div class="label">通过率</div>
            </div>
        </div>

        <div class="test-list">
            <div class="filter-bar">
                <button class="filter-btn active" onclick="filterTests('all')">全部</button>
                <button class="filter-btn" onclick="filterTests('passed')">通过</button>
                <button class="filter-btn" onclick="filterTests('failed')">失败</button>
            </div>

            ${sessions.map((session) => _generateTestCard(session)).join('')}
        </div>
    </div>

    <script>
        function toggleTest(element) {
            const testItem = element.closest('.test-item');
            testItem.classList.toggle('active');
        }

        function filterTests(filter) {
            const tests = document.querySelectorAll('.test-item');
            const buttons = document.querySelectorAll('.filter-btn');

            buttons.forEach(btn => btn.classList.remove('active'));
            event.target.classList.add('active');

            tests.forEach(test => {
                if (filter === 'all') {
                    test.style.display = 'block';
                } else if (filter === 'passed') {
                    test.style.display = test.classList.contains('passed') ? 'block' : 'none';
                } else if (filter === 'failed') {
                    test.style.display = test.classList.contains('failed') ? 'block' : 'none';
                }
            });
        }

        // 图片点击放大
        document.querySelectorAll('.step-screenshot img').forEach(img => {
            img.addEventListener('click', function() {
                window.open(this.src, '_blank');
            });
        });
    </script>
</body>
</html>
''';
  }

  String _generateTestCard(TestSession session) {
    final statusClass = session.passed == true ? 'passed' : 'failed';
    final statusText = session.passed == true ? '✅ 通过' : '❌ 失败';
    final duration =
        session.endTime?.difference(session.startTime).inSeconds ?? 0;
    final successSteps = session.steps.where((s) => s.success).length;
    final totalSteps = session.steps.length;

    return '''
<div class="test-item $statusClass" data-status="${session.passed == true ? 'passed' : 'failed'}">
    <div class="test-header" onclick="toggleTest(this)">
        <div class="test-info">
            <h3>${session.testName}</h3>
            <p>${session.platform} · $duration秒 · $successSteps/$totalSteps 步骤成功</p>
        </div>
        <div class="test-status">
            <span class="status-badge $statusClass">$statusText</span>
            <span style="color: #999;">▼</span>
        </div>
    </div>
    <div class="test-body">
        <div class="step-list">
            ${session.steps.map((step) => _generateStepItem(step)).join('')}
        </div>
    </div>
</div>
''';
  }

  String _generateStepItem(TestStep step) {
    final statusClass = step.success ? 'success' : 'error';
    final icon = step.success ? '✅' : '❌';

    return '''
<div class="step-item $statusClass">
    <div class="step-name">$icon ${step.name}</div>
    <div class="step-desc">${step.description}</div>
    ${!step.success && step.errorMessage != null ? '''
    <div class="step-error">
        <strong>错误:</strong> ${step.errorMessage}
    </div>
    ''' : ''}
    ${step.screenshotPath != null && step.screenshotPath!.isNotEmpty ? '''
    <div class="step-screenshot">
        <img src="${step.screenshotPath}" alt="${step.name} 截图" onerror="this.style.display='none'">
    </div>
    ''' : ''}
</div>
''';
  }
}
