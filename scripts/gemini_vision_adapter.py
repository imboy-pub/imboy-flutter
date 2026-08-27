#!/usr/bin/env python3
"""将 auto_test 的供应商无关视觉任务提交给 Gemini。

本脚本只从环境读取 GEMINI_API_KEY，绝不打印或写入该密钥。调用方必须先通过
auto_test.py 的 IMBOY_ALLOW_VISION_UPLOAD=1 门禁，避免误上传真机截图。
"""
from __future__ import annotations

import base64
import json
import mimetypes
import os
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


def fail(message: str, code: int = 2) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(code)


def main() -> int:
    if len(sys.argv) != 2:
        fail('用法：gemini_vision_adapter.py <visual-request.json>', 64)
    api_key = os.environ.get('GEMINI_API_KEY', '')
    if not api_key:
        fail('缺少 GEMINI_API_KEY；不会发送截图。')
    request_path = Path(sys.argv[1])
    try:
        job = json.loads(request_path.read_text(encoding='utf-8'))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f'无法读取视觉任务: {exc}', 1)
    screenshot = Path(str(job.get('screenshot', '')))
    if not screenshot.is_file():
        fail('视觉任务引用的截图不存在。', 1)
    mime = mimetypes.guess_type(screenshot.name)[0]
    if mime not in {'image/png', 'image/jpeg', 'image/webp'}:
        fail(f'不支持的截图格式: {mime or "unknown"}', 1)

    prompt = (
        '你是移动端 UI/UX 回归审查员。只根据截图、基线和给定规则给出结论；'
        '不得把功能推断为通过。严格只返回 JSON object，不要 Markdown。\n'
        + json.dumps({
            'case_id': job.get('case_id'),
            'title': job.get('title'),
            'context': job.get('context'),
            'rubric': job.get('rubric'),
            'decision_rule': job.get('decision_rule'),
            'required_response_schema': job.get('required_response_schema'),
            'baseline_present': bool(job.get('baseline')),
        }, ensure_ascii=False)
    )
    parts = [
        {'text': prompt},
        {'inline_data': {'mime_type': mime, 'data': base64.b64encode(screenshot.read_bytes()).decode('ascii')}},
    ]
    if job.get('baseline'):
        baseline = Path(str(job['baseline']))
        baseline_mime = mimetypes.guess_type(baseline.name)[0]
        if not baseline.is_file() or baseline_mime not in {'image/png', 'image/jpeg', 'image/webp'}:
            fail('视觉任务引用的基线截图不存在或格式不受支持。', 1)
        parts.append({'text': '以上是当前截图；以下是批准基线。只把未解释的差异作为 finding。'})
        parts.append({'inline_data': {'mime_type': baseline_mime, 'data': base64.b64encode(baseline.read_bytes()).decode('ascii')}})
    payload = {
        'contents': [{'role': 'user', 'parts': parts}],
        'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0},
    }
    model = os.environ.get('GEMINI_MODEL', 'gemini-2.5-flash-lite')
    url = 'https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s' % (
        quote(model, safe='-.'), quote(api_key, safe=''),
    )
    request = Request(
        url,
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST',
    )
    try:
        with urlopen(request, timeout=60) as response:
            body = json.loads(response.read().decode('utf-8'))
    except HTTPError as exc:
        fail(f'Gemini 请求失败: HTTP {exc.code}', 1)
    except (URLError, TimeoutError) as exc:
        fail(f'Gemini 网络请求失败: {exc}', 1)
    try:
        text = body['candidates'][0]['content']['parts'][0]['text']
        result = json.loads(text)
    except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
        fail(f'Gemini 未返回可解析的 JSON 结论: {exc}', 1)
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
