#!/usr/bin/env python3
"""Render the Markdown task and acceptance views from this package's JSON.

This utility writes only TASKS.md and ACCEPTANCE.md in the selected package.
It never reads or writes a user's application repository or runtime state.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path

HEADER='''# IMBoy 企业客户端 UI/UX：可测试、可落地、可验收任务清单 V1.1

计划ID：`imboy-enterprise-uiux-v1`（沿用V1）｜状态：`READY_FOR_LOCAL_W0`。

**初始全部TODO，不是已运行报告。** 共51张卡：40张必需自动卡、9张原生平台人工卡、1张真实跨会话卡、1张可重复报告卡；5个Batch。JSON是任务结构真源，Markdown由同包工具生成；不得双写漂移。

关联：[PRD](PRD.md) · [测试合同](TEST_CONTRACT.md) · [续跑协议](RESUME_PROTOCOL.md) · [升级迁移](MIGRATION.md) · [验收清单](ACCEPTANCE.md) · [命令索引](COMMANDS.json)。

## 1. 范围与路径

只修改Flutter展示、局部纯展示组件、本地化及对应测试/文档。Backend/Admin仅必要时只读；不修改或运行后端/数据库，不抢占真机。API/DTO/Provider/Service/Domain、权限、feature、掩码、CAS/SSE/分页/SSO不变。既有修复先复验，不为产生代码diff重写。

源码路径从原研究提交定位，T01—T04按本机已提交HEAD复核；研究SHA不是固定执行基线。新增路径不代表当前已存在。`<生效locale>`、`@resolved/`在T04展开为逐文件清单；`@runtime/`和`@package/`分别是公共Git目录运行区与本发行包，不是源码目录通配授权。表中生产文件授权仅限“改哪个区块”列，不是整文件业务修改权。

每卡实施规模≤0.5人日，是任务切分上限，不是模型耗时承诺。达到上限仍未完成则拆子卡并登记范围/依赖/证据，不通过改状态强行收尾。已有完成任务可以test/docs-only；测试、实现与本任务提交一一映射。T29的结果文档提交只能在候选K门结束后产生，不把报告R当新代码已测。

## 2. Batch、并行度与结束标志

| Batch | 目标 | 工作流与资源约束 | 验收节点 |
|---|---|---|---|
| B0 冻结现场 | 无前置循环地完成发现/调查/路径/范围/锁/状态合同 | T00协调；T01/02/03只读并行写inbox；T04及.a/b/c由协调器串行接收；不并写index | M0：所有启动产物和实际正反例有记录；历史基线失败另列，不伪称零问题 |
| B1 建立输入 | 结构harness与本地化稳定；视觉字体独立 | T05/T06使用共享单写者；T07/08/09最多3lane；T05.a缺字体只阻塞视觉 | M1：真实夹具/文案可运行；字体能力单列 |
| B2 页面实施 | 消除当前实际缺口，保持业务行为 | P1/P2/P3最多3写lane；同页同文件串行；T13/T14不因T12的颜色阻塞而等待 | M2：本页定向断言和scope通过；每页可先进入B3 |
| B3 验证与视觉封存 | 结构/图像生成/审查分别记账，保留312配置 | 每页T22/23/24→.a→.b；T25—27调用回归不依赖golden；默认重型Flutter最多1进程 | M3：312配置计数、review、普通比较与回归证据齐全 |
| B4 最终与交接 | 同候选K门、原生平台卡、真实续跑、随时报告 | T28可前移到控制模块形成后；T29汇合；9原生卡受设备锁；T28.m独立；T33每批末/阻塞/暂停均可执行 | M4A自动通过；M4B原生通过；真实跨会话恢复独立状态 |

最多4活跃代理=3页面worker+1协调器。没有子代理能力则串行同一DAG。共享i18n/生成strings/harness/总状态/集成由协调器独写；P2独占cs_workspace_entry.dart入口外观，P3不得修改。Flutter锁按SDK真实路径/设备ID，不用各计划独立锁假装跨计划互斥。

## 3. 依赖图与最短并行落地路径

```text
T00 → (T01 || T02 || T03) → T04
T04 → T04.a(scope)                          ┐
T04 → T04.b(lock) → T04.c(state)             │
T04 → T05(structure)                        ├→ T07 / T08 / T09各页夹具
T04 → T06(i18n)                             ┘
T05 → T05.a(font) ─────────────────────────────→ 各页视觉/真实文字几何门

P1: T07 → T10 → T11 → T12 ┐
          ├→ T13         ├→ T22 → T22.a → T22.b ┐
          └→ T14 → T15   ┴→ T25               │
P2: T08 → T16 → T17 → T18 → T23 → T23.a → T23.b ├→ T29(K最终门)
                         └→ T26               │
P3: T09 → T19 → T20 → T21 → T24 → T24.a → T24.b ┤
                         └→ T27               │
T04.a + T04.c → T28(实际模块故障套件) ───────────┘
T28 + T04.c → T28.m(真实新会话；非自动门前置)
T29 → T30/30.a/30.b、T31/31.a/31.b、T32/32.a/32.b
T00 → T33(任意成功/失败/阻塞都可重复报告)
```

图示用于阅读，完整依赖以各卡与JSON为准；T22/23/24均额外依赖T05.a。主要候选关键链是P1实现→结构→golden→最终门，现场字体/设备会改变实际瓶颈，不能仅用任务编号当排期。

**最先可做：**T00完成后并行三页只读调查；T04后scope、锁/状态、结构、本地化各有明确产物；共同输入与guards稳定后开三页面原lane。视觉环境阻塞不阻塞T25—27；共享文件冲突由mutex调度，不额外伪造业务依赖。

## 4. 执行任务索引

'''
FOOTER='''
## 6. 门禁命令与收口

每卡“命令ID”可在COMMANDS.json找到argv/cwd/producer/成功条件；本机动态项在T04生成commands.resolved.json。详见[TEST_CONTRACT](TEST_CONTRACT.md)第5节各Batch命令。首次T00—T03不得调用未创建的检查器；自卡创建的测试只能在该卡实现后验证，不能在READY前要求自己已通过。

B0记录旧测试基线；B1运行结构/本地化/fixture及analyze；B2按页跑定向测试/scope/analyze；B3运行结构、单页golden普通比较、旧回归与scope/analyze；B4只在干净K运行最终全量。任何空目录、缺图、必需case skip、无exitcode、错tree/环境都不是PASS。

T33只输出报告快照；K通过才LOCAL_CANDIDATE_PASS，九张平台卡通过才UX_ACCEPTED；T28.m真实会话恢复单列。失败或缺设备可以报告PARTIAL_BLOCKED/MANUAL_PENDING，不能删除需求、改后台或新建工作树规避。

完整逐项勾选义务见ACCEPTANCE.md。运行时将实际勾选结果写execution/ACCEPTANCE_RESULTS.json/md，不修改静态验收合同以制造通过。
'''

def cell(v: object) -> str:
    return str(v).replace('|','\\|').replace('\n','<br>')

def render_tasks(data: dict) -> str:
    tasks=data['tasks']
    parts=[HEADER,'| ID | Batch / lane | 名称 | 上限人日 | 依赖 | 类型 |\n|---|---|---|---:|---|---|\n']
    for t in tasks:
        parts.append(f"| {t['id']} | {t['batch']} / {t['workstream']} | {cell(t['name'])} | {t['effort_person_days']:.2f} | {', '.join(t['dependencies']) or '无'} | {t['kind']} |\n")
    parts.append('\n## 5. 文件级执行卡\n\n测试名是必须实现或映射的验收目标，不表示当前已经存在/运行。人工卡的具体单场景≤3步脚本见NATIVE_CASES.json；准备条件单列。非人工卡中的观察步骤供review，不强迫无设备的自动实施停工。\n')
    for t in tasks:
        parts.append(f"\n### {t['id']} · {t['name']}\n\n| 字段 | 合同 |\n|---|---|\n")
        rows=[('ID / 名称',f"{t['id']} / {t['name']}"),('Batch / Workstream / 规模',f"{t['batch']} / {t['workstream']} / ≤{t['effort_person_days']:.2f}人日"),('目标',t['goal']),('参考依据',t['references']),('改动范围（逐文件/运行产物）','<br>'.join('`'+p+'`' for p in t['write_paths'])),('改哪个区块、改成什么',t['change']),('依赖',', '.join(t['dependencies']) or '无'),('关联验收项',', '.join(t['acceptance_ids'])),('自动/证据验收断言',t['acceptance_assertions']),('命令ID',', '.join(t['command_ids'])),('定向命令说明',t['test_command']),('人工观察（每场景≤3步）','<br>'.join(f'{i+1}. {s}' for i,s in enumerate(t['manual_steps']))),('证据绑定',t['evidence_rule']),('资源/冲突',', '.join(t['resource_keys'])),('失败处理',t['failure_route']),('回滚方式',t['rollback']),('风险',t['risk']),('完成判定',t['completion_rule']),('提交要求','Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。')]
        for k,v in rows:parts.append(f'| {k} | {cell(v)} |\n')
    parts.append(FOOTER)
    return ''.join(parts)

def render_ac(data: dict) -> str:
    parts=['# IMBoy UI/UX V1.1：逐项验收合同\n\n计划ID：`imboy-enterprise-uiux-v1`｜37项初始未验；实际状态写execution/ACCEPTANCE_RESULTS.json/md，不能改合同消除义务。\n\n自动、原生、真实恢复分开记账。N/A不豁免必需UI或golden；报告成功不代表产品成功。\n\n']
    last=None
    for ac in data['acceptance_items']:
        group=ac['id'].split('-')[1]
        if group!=last:parts.append('\n## '+group+' 验收项\n\n');last=group
        parts.append(f"- [ ] **{ac['id']}**（{', '.join(ac['task_ids'])}）：{ac['requirement']}\n")
    parts.append('''\n## 必须填写的结果字段\n\n| 字段 | 要求 |\n|---|---|\n| 代码候选 | candidate K SHA/tree；测试前后输入一致 |\n| 报告附件 | 当前R SHA；report-only差异检查；不宣称R已全量验证 |\n| 自动 | 每项NOT_RUN/PASS/FAIL/STALE/BLOCKED及证据；M4A通过才LOCAL_CANDIDATE_PASS |\n| 原生 | iOS/Android/macOS逐平台case；九张人工卡通过才UX_ACCEPTED |\n| 真实恢复 | T28.m两个真实会话证据；模拟测试不能替代 |\n| 失败/缺资源 | 缺陷ID、影响AC、owner、下一动作；不清零累计attempt |\n| Golden | expected/executed/compared/reviewed及环境/图hash；312配置不得漏项 |\n| 授权 | merge main / push / deploy / 删除worktree均NOT_AUTHORIZED |\n\n回归清单和case依据：[TEST_CONTRACT](TEST_CONTRACT.md)、[MATRIX](MATRIX.json)、[NATIVE_CASES](NATIVE_CASES.json)、[RECOVERY_CASES](RECOVERY_CASES.json)。\n''')
    return ''.join(parts)

def main() -> None:
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--package',type=Path,default=Path(__file__).resolve().parents[1]);args=ap.parse_args()
    root=args.package.resolve()
    outputs={'TASKS.md':render_tasks(json.loads((root/'TASKS.json').read_text())), 'ACCEPTANCE.md':render_ac(json.loads((root/'ACCEPTANCE.json').read_text()))}
    for name,text in outputs.items(): (root/name).write_text(text,encoding='utf-8')
    print('Rendered TASKS.md and ACCEPTANCE.md; recompute SHA256SUMS before redistributing a changed package.')
if __name__=='__main__':main()
