#!/usr/bin/env python3
"""从各模块 md 重新生成 test/auto_test/README.md 的汇总与索引。

每轮测试/修复回写完 md 之后必须跑一次，否则 README 的统计会陈旧：

    cd imboyapp && python3 test/auto_test/regen_readme.py

只读各 `<module>/<page>.md` 里的表格行，重算全局汇总、模块索引、页面清单。
README 的规则说明与列定义是静态文案，写死在本脚本里，不从旧 README 继承——
避免「改了规则忘了同步」。
"""
import os
import glob
import collections

BASE = os.path.dirname(os.path.abspath(__file__))
KEYS = ['无待办', '回归复测', '待重验', '待首测', '待修复', '待复验', '阻塞']


def parse():
    """返回 {module: {page_md: (path, rows, counter, pending)}}"""
    data = collections.defaultdict(dict)
    for f in sorted(glob.glob(os.path.join(BASE, '*', '*.md'))):
        mod = os.path.basename(os.path.dirname(f))
        name = os.path.basename(f)
        rows, c, found, solved, pending, path = 0, collections.Counter(), 0, 0, 0, ''
        for line in open(f, encoding='utf-8'):
            if not line.startswith('| ') or line.startswith('| 计划变化'):
                continue
            col = [x.strip() for x in line.split('|')]
            if len(col) < 11:
                continue
            rows += 1
            c[col[1]] += 1
            if not path:
                path = col[3].strip('`')
            try:
                found += int(col[7])
                solved += int(col[8])
                pending += int(col[9])
            except ValueError:
                pass
        if rows:
            data[mod][name] = (path, rows, c, found, solved, pending)
    return data


def main():
    data = parse()
    tot = collections.Counter()
    pages = sum(len(v) for v in data.values())
    for mod in data.values():
        for _, rows, c, found, solved, pending in mod.values():
            tot.update(c)
            tot['_rows'] += rows
            tot['_found'] += found
            tot['_solved'] += solved
            tot['_pending'] += pending

    present = [k for k in KEYS if tot[k]]
    L = []
    A = L.append
    A('# imboyapp 自动化测试计划 —— 索引\n')
    A('> **权威文档**。imboyapp 现有全部功能点（已完成 / 未完成 / 阻塞 全部纳入）。')
    A('> 覆盖 **%d 个页面 / %d 个功能点**' % (pages, tot['_rows']))
    A('> 数据源：`lib/page/**` 真实源码抽取 ＋ 真机实测记录\n')
    A('> ⚠️ 本文件由 `regen_readme.py` 生成，**不要手改**。')
    A('> 每轮回写完各模块 md 后跑：`python3 test/auto_test/regen_readme.py`\n')
    A('## 目录结构\n')
    A('本目录**镜像 `lib/page/` 结构**：改了 `lib/page/channel/channel_list_page.dart`，')
    A('就去 `test/auto_test/channel/channel_list_page.md` 更新对应功能点。\n')
    A('执行规程见 [LOOP_PROMPT.md](./LOOP_PROMPT.md)。\n')
    A('## 表格规则（保证有限膨胀）\n')
    A('| 规则 | 说明 |\n|---|---|')
    A('| **一行 = 一个功能点** | 行数只随功能增加，**不随测试轮次增加** |')
    A('| **按功能介绍覆盖写** | 同一功能点永远只有一行。新一轮改状态和计数，不加行 |')
    A('| **bug 用计数不用叙述** | `待处理 = 发现 − 解决`，恒等式可自动校验 |')
    A('| **备注只写当前未闭环的事** | 闭环即清空。修复细节去 git log 查 |\n')
    A('## 列定义\n')
    A('| 计划变化 | 含义 |\n|---|---|')
    A('| `待首测` | 从没测过 |')
    A('| `回归复测` | 页面整体标过通过，但这个功能点当初没被单独验证 |')
    A('| `待修复` | 有未修 bug |')
    A('| `待复验` | 代码已改，缺真机证据 |')
    A('| `阻塞` | 缺外部条件（第二台设备 / 真实素材 / 授权 / 特定数据规模） |')
    A('| `无待办` | 当前无动作，只在回归轮被动扫到 |\n')
    A('## 全局汇总\n')
    A('| 计划变化 | 条数 | 占比 |\n|---|---|---|')
    for k in present:
        A('| %s | %d | %.1f%% |' % (k, tot[k], tot[k] * 100.0 / tot['_rows']))
    A('| **合计** | **%d** | 100%% |\n' % tot['_rows'])
    A('bug 累计：**发现 %d / 解决 %d / 待处理 %d**\n'
      % (tot['_found'], tot['_solved'], tot['_pending']))
    bad = tot['_found'] - tot['_solved'] - tot['_pending']
    A('> 恒等式 `发现 − 解决 = 待处理` %s\n' % ('成立' if bad == 0 else '**不成立，差 %d，需排查**' % bad))
    A('## 模块索引\n')
    head = ' | '.join(present)
    A('| 模块 | 页面 | 功能点 | 待处理bug | %s |' % head)
    A('|---|---|---|---|%s' % ('---|' * len(present)))
    for mod in sorted(data, key=lambda m: -sum(v[1] for v in data[m].values())):
        rows = sum(v[1] for v in data[mod].values())
        pend = sum(v[5] for v in data[mod].values())
        c = collections.Counter()
        for v in data[mod].values():
            c.update(v[2])
        A('| [%s](%s/) | %d | %d | %d | %s |'
          % (mod, mod, len(data[mod]), rows, pend,
             ' | '.join(str(c[k]) for k in present)))
    A('\n## 页面清单\n')
    for mod in sorted(data):
        A('\n### %s\n' % mod)
        for name in sorted(data[mod]):
            _, rows, _, _, _, pend = data[mod][name]
            flag = ' ⚠️ %d 待处理' % pend if pend else ''
            A('- [%s](%s/%s) — %d 功能点%s' % (name[:-3], mod, name, rows, flag))

    out = os.path.join(BASE, 'README.md')
    open(out, 'w', encoding='utf-8').write('\n'.join(L) + '\n')
    print('README 已重生成：%d 页面 / %d 功能点 / 待处理 bug %d'
          % (pages, tot['_rows'], tot['_pending']))
    if bad:
        raise SystemExit('恒等式不成立，差 %d' % bad)


if __name__ == '__main__':
    main()
