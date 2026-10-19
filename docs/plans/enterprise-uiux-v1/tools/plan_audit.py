#!/usr/bin/env python3
"""Read-only static audit of the IMBoy UI/UX document package.

Checks task/command dependency closure, generated Markdown, coverage manifests,
initial-state templates, local links and checksums. --self-test mutates copies
in memory to verify rejection of bad contracts. It does not test Flutter, create
worktrees, contact any server or certify actual cross-session recovery.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any
sys.dont_write_bytecode=True
from render_plan import render_tasks, render_ac

class AuditError(ValueError):
    pass

def require(ok: bool, message: str) -> None:
    if not ok: raise AuditError(message)

def load(root: Path) -> dict[str, Any]:
    files={'tasks':'TASKS.json','commands':'COMMANDS.json','matrix':'MATRIX.json',
           'ac':'ACCEPTANCE.json','native':'NATIVE_CASES.json','recovery':'RECOVERY_CASES.json',
           'state':'templates/STATE.example.json','legacy':'review/V1_TASK_IDS.json',
           'report_allow':'templates/REPORT_ONLY_ALLOWLIST.json'}
    return {key:json.loads((root/path).read_text(encoding='utf-8')) for key,path in files.items()}

def validate(d: dict[str, Any]) -> dict[str, int]:
    spec=d['tasks']; tasks=spec['tasks']; ids=[t['id'] for t in tasks]; idset=set(ids); tm={t['id']:t for t in tasks}
    require(len(ids)==len(idset),'duplicate task ID')
    require(len(tasks)==51,'V1.1 must have 51 declared leaf cards')
    require(spec['plan_id']=='imboy-enterprise-uiux-v1','stable plan ID changed')
    require(set(d['legacy']['ids'])<=idset,'original task ID lost')
    require({t['batch'] for t in tasks}=={'B0','B1','B2','B3','B4'},'must preserve five batches')
    nonempty=['name','goal','references','change','acceptance_assertions','test_command','rollback','risk','evidence_rule','completion_rule']
    for t in tasks:
        for k in nonempty:require(isinstance(t.get(k),str) and bool(t[k].strip()),f'{t["id"]}: empty {k}')
        require(0<t['effort_person_days']<=.5,f'{t["id"]}: card larger than 0.5 person day')
        require(1<=len(t['manual_steps'])<=3,f'{t["id"]}: manual step count')
        require(bool(t['write_paths']),f'{t["id"]}: no file-level scope')
        require(bool(t['command_ids']),f'{t["id"]}: empty command references')
        require(t['initial_status']=='TODO',f'{t["id"]}: invented run result')
        require(set(t['dependencies'])<=idset,f'{t["id"]}: missing dependency')
        require(t['id'] not in t['dependencies'],f'{t["id"]}: direct self dependency')
        require(len(t['dependencies'])==len(set(t['dependencies'])),f'{t["id"]}: duplicate dependency')
        require(not(t['kind']=='manual' and t['required_for_local']),f'{t["id"]}: manual blocks local automatically')
        pages=set()
        for p in t['write_paths']:
            if p.startswith(('lib/page/channel/','lib/page/workspace/workspace_channel_detail_page.dart')):pages.add('P1')
            elif p.startswith(('lib/modules/enterprise_oa/presentation/enterprise_workbench_page.dart','lib/page/workspace_shell/enterprise_shell_page.dart','lib/modules/customer_service/presentation/cs_workspace_entry.dart')):pages.add('P2')
            elif p.startswith('lib/modules/customer_service/presentation/'):pages.add('P3')
            if p.startswith('lib/'):
                require(not any(x in p for x in ['/domain/','/infrastructure/','/service/','/store/api/']),f'{t["id"]}: forbidden production layer')
        require(len(pages)<=1,f'{t["id"]}: more than one product page')
    ancestry:dict[str,set[str]]={};visiting:set[str]=set()
    def ancestors(tid:str)->set[str]:
        require(tid not in visiting,f'cycle through {tid}')
        if tid in ancestry:return ancestry[tid]
        visiting.add(tid);a:set[str]=set()
        for dep in tm[tid]['dependencies']:a.add(dep);a.update(ancestors(dep))
        visiting.remove(tid);ancestry[tid]=a;return a
    for tid in ids:ancestors(tid)
    cmds=d['commands']['commands']
    for cid,c in cmds.items():
        require(isinstance(c['argv'],list) and bool(c['argv']) and all(isinstance(x,str) and x.strip() for x in c['argv']),f'{cid}: empty argv')
        require(c.get('cwd') and c.get('success'),f'{cid}: missing execution boundary')
        prod=c.get('producer_task')
        require(prod is None or prod in idset,f'{cid}: unknown producer')
        if prod:
            for p in c['required_files']:require(p in tm[prod]['artifact_outputs'],f'{cid}: required file not produced by {prod}: {p}')
    for t in tasks:
        for cid in t['command_ids']:
            require(cid in cmds,f'{t["id"]}: unknown command')
            prod=cmds[cid].get('producer_task')
            require(prod is None or prod==t['id'] or prod in ancestry[t['id']],f'{t["id"]}: command {cid} needs future producer {prod}')
    require(tm['T33']['dependencies']==['T00'],'blocked reports cannot depend on T29')
    rp=tm['T33'].get('report_policy',{})
    require(rp.get('trigger_mode')=='EVENT_DRIVEN' and rp.get('deduplicate')=='non_report_input_hash' and rp.get('exclude_from_default_ready_queue') is True,'report can infinitely enqueue itself')
    require('T05.a' not in ancestry['T06'],'font blocks localization')
    for tid in ['T07','T08','T09','T14','T25','T26','T27']:
        require('T05.a' not in ancestry[tid],f'font blocks independent task {tid}')
    require('T12' not in ancestry['T13'] and 'T12' not in ancestry['T14'],'unnecessary P1 serial dependency')
    require('T28.m' not in ancestry['T29'],'real manual restart blocks local gate')
    for tid in ['T22','T23','T24']:require('T05.a' in ancestry[tid],f'{tid}: visual typography lacks font dependency')
    gates=d['commands']['gates'];auto={t['id'] for t in tasks if t['required_for_local']}
    require(len(auto)==40,'local automatic obligation count changed')
    require(set(gates['M4A']['required_tasks'])==auto-{'T29'},'final gate preconditions changed or include itself')
    require(gates['M4A']['result_task']=='T29','final gate has no explicit result task')
    for g in gates.values():
        require(set(g['required_tasks'])<=idset,'gate unknown task')
        require(all(c in cmds for c in g['commands']),'gate unknown command')
    native_tasks={t['id'] for t in tasks if t['kind']=='manual'}-{'T28.m'}
    require(len(native_tasks)==9 and set(gates['M4B']['required_tasks'])==native_tasks,'native platform cards not separated')
    acs=d['ac']['acceptance_items'];am={a['id']:a for a in acs}
    require(len(am)==len(acs)==37,'acceptance count/uniqueness')
    for t in tasks:
        for aid in t['acceptance_ids']:
            require(aid in am and t['id'] in am[aid]['task_ids'],f'{t["id"]}: broken reverse AC mapping')
    for a in acs:
        require(a['task_ids'] and set(a['task_ids'])<=idset,'AC task reference missing')
        for tid in a['task_ids']:require(a['id'] in tm[tid]['acceptance_ids'],f'{a["id"]}: missing task->AC link')
        require(a['auto_status']=='NOT_RUN','AC invents execution success')
    configs=d['matrix']['configs'];config_ids=[c['id'] for c in configs]
    require(d['matrix']['expected_count']==312 and len(configs)==312,'matrix lost configurations')
    require(len(set(config_ids))==312,'duplicate matrix configuration')
    for p,count in [('P1',120),('P2',72),('P3',120)]:
        cs=[c for c in configs if c['page']==p];require(len(cs)==count,'page matrix count')
        for scene in {c['scene'] for c in cs}:
            sc=[c for c in cs if c['scene']==scene]
            combos={(c['target_platform'],c['width'],c['theme'],c['text_scale']) for c in sc}
            require(len(combos)==24,'matrix Cartesian product incomplete')
            require({c['width'] for c in sc}=={360,1280},'width requirement')
            require({c['text_scale'] for c in sc}=={1.,2.},'text scale requirement')
    for c in configs:
        require(c['required'] is True,'mandatory golden downgraded')
        require(c['height']==800 and c['dpr']==1 and c['locale']=='zh-CN','matrix rendering input drift')
        for k in ['structure_task','capture_task','review_task']:require(c[k] in idset,'matrix task missing')
        require(c['capture_task']!=c['review_task'],'generation equals approval')
    ncs=d['native']['cases'];require(len({c['id'] for c in ncs})==len(ncs),'native duplicate ID')
    require({c['task_id'] for c in ncs}==native_tasks,'native cases do not cover all platform tasks')
    for c in ncs:
        require(len(c['steps'])<=3 and c['preconditions'],'native script step/precondition contract')
        require(c['status']=='MANUAL_PENDING','native proof invented')
    rcs=d['recovery']['cases'];require(len(rcs)==24 and len({x['id'] for x in rcs})==24,'recovery case count')
    require(d['recovery']['test_owner']=='T28' and d['recovery']['real_cross_session_owner']=='T28.m','simulation conflated with real restart')
    for c in rcs:require(c['status']=='NOT_RUN','recovery evidence invented')
    st=d['state'];require(st['example_only'] and st['status']=='NOT_INITIALIZED','state template looks live')
    require(set(st['tasks'])==idset,'state template task mismatch')
    for x in st['tasks'].values():require(x['verification_state']=='NOT_RUN' and x['work_state']=='TODO','template marks task complete')
    allow=d['report_allow']['paths']
    require(all(p.startswith('docs/plans/enterprise-uiux-v1/execution/') and '*' not in p for p in allow),'report-only whitelist is broad')
    for f in ['PRD.md','TASKS.md','ACCEPTANCE.md','COMMANDS.json']:
        require('docs/plans/enterprise-uiux-v1/'+f not in allow,'contract treated as report-only')
    require(all(p in allow for p in tm['T33']['write_paths']),'report task changes unapproved files')
    return dict(tasks=len(tasks),required_automatic_tasks=len(auto),manual_tasks=len(native_tasks)+1,report_tasks=1,commands=len(cmds),acceptance_items=len(acs),golden_configs=len(configs),native_cases=len(ncs),recovery_cases_defined=len(rcs))

def self_tests(data:dict[str,Any])->list[str]:
    def task(d:dict[str,Any],tid:str)->dict[str,Any]:return next(t for t in d['tasks']['tasks'] if t['id']==tid)
    tests=[
        ('duplicate_task_id',lambda d:d['tasks']['tasks'].append(copy.deepcopy(d['tasks']['tasks'][0]))),
        ('unknown_dependency',lambda d:task(d,'T10')['dependencies'].append('T99')),
        ('hidden_dependency_cycle',lambda d:task(d,'T00')['dependencies'].append('T29')),
        ('future_tool_at_bootstrap',lambda d:task(d,'T02')['command_ids'].append('C-STATE')),
        ('empty_task_command',lambda d:task(d,'T03').update(command_ids=[])),
        ('empty_command_argv',lambda d:d['commands']['commands']['C-ANALYZE'].update(argv=[])),
        ('report_waits_for_success',lambda d:task(d,'T33').update(dependencies=['T29'])),
        ('font_blocks_i18n',lambda d:task(d,'T06')['dependencies'].append('T05.a')),
        ('manual_blocks_local',lambda d:task(d,'T28.m').update(required_for_local=True)),
        ('final_gate_self_cycle',lambda d:d['commands']['gates']['M4A']['required_tasks'].append('T29')),
        ('missing_golden_config',lambda d:d['matrix']['configs'].pop()),
        ('mandatory_golden_downgraded',lambda d:d['matrix']['configs'][0].update(required=False)),
        ('golden_generation_as_approval',lambda d:d['matrix']['configs'][0].update(review_task=d['matrix']['configs'][0]['capture_task'])),
        ('native_four_steps',lambda d:d['native']['cases'][0]['steps'].append('extra step')),
        ('mixed_page_task',lambda d:task(d,'T10')['write_paths'].append('lib/modules/enterprise_oa/presentation/enterprise_workbench_page.dart')),
        ('scope_domain_write',lambda d:task(d,'T19')['write_paths'].append('lib/modules/customer_service/domain/cs_seat_gate.dart')),
        ('report_whole_docs_exemption',lambda d:d['report_allow']['paths'].append('docs/**')),
        ('invented_recovery_pass',lambda d:d['recovery']['cases'][0].update(status='PASS')),
        ('source_file_not_produced',lambda d:d['commands']['commands']['C-STATE-SELF']['required_files'].append('missing.py')),
        ('lost_original_task',lambda d:d['legacy']['ids'].append('T99')),
        ('unbounded_report_loop',lambda d:task(d,'T33')['report_policy'].update(trigger_mode='ALWAYS_READY')),
    ]
    passed=[]
    for name,mutate in tests:
        case=copy.deepcopy(data);mutate(case)
        try:validate(case)
        except (AuditError,KeyError):passed.append(name)
        else:raise AuditError('negative test was incorrectly accepted: '+name)
    return passed

def validate_files(root:Path,data:dict[str,Any],checksums:bool=True)->int:
    require((root/'TASKS.md').read_text(encoding='utf-8')==render_tasks(data['tasks']),'TASKS Markdown/JSON drift')
    schema=json.loads((root/'templates/STATE.schema.json').read_text())
    for value in data['state']['tasks'].values():
        for field in ['work_state','verification_state','manual_state']:
            require(value[field] in schema['$defs']['task']['properties'][field]['enum'],'template uses undefined state enum')
    require((root/'ACCEPTANCE.md').read_text(encoding='utf-8')==render_ac(data['ac']),'AC Markdown/JSON drift')
    require((root/'STATE.example.json').read_bytes()==(root/'templates/STATE.example.json').read_bytes(),'duplicate state template drift')
    # Normal Markdown local links only; URLs and source code path examples are not local file claims.
    links=0
    for md in root.rglob('*.md'):
        if md.relative_to(root).parts[0] == 'execution': continue
        for dest in re.findall(r'\[[^\]]*\]\(([^)]+)\)',md.read_text(encoding='utf-8')):
            dest=dest.split('#',1)[0]
            if not dest or re.match(r'^[a-zA-Z][\w+.-]*:',dest):continue
            target=(md.parent/dest).resolve()
            require(target.is_relative_to(root),f'link leaves package: {md.name}:{dest}')
            require(target.exists(),f'missing local link: {md.name}:{dest}')
            links+=1
    for f in root.rglob('*'):
        if f.is_file() and f.relative_to(root).parts[0] != 'execution':require(f.suffix.lower() not in ['.ttf','.otf','.woff','.woff2','.ttc'],'font binary included')
    if checksums:
        manifest=root/'SHA256SUMS';require(manifest.is_file(),'SHA256SUMS missing')
        listed={}
        for line in manifest.read_text().splitlines():
            digest,sep,name=line.partition('  ')
            require(bool(sep) and len(digest)==64 and name not in listed,'invalid/duplicate checksum line')
            target=(root/name).resolve();require(target.is_relative_to(root) and target.is_file(),'checksum path invalid')
            require(hashlib.sha256(target.read_bytes()).hexdigest()==digest,'checksum mismatch: '+name)
            listed[name]=digest
        actual={str(f.relative_to(root)) for f in root.rglob('*') if f.is_file() and f.name!='SHA256SUMS' and '__pycache__' not in f.parts and f.relative_to(root).parts[0] != 'execution'}
        require(set(listed)==actual,'checksum manifest missing or contains extra files')
    return links

def main()->None:
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--package',type=Path,default=Path(__file__).resolve().parents[1]);ap.add_argument('--self-test',action='store_true')
    ap.add_argument('--authoring-no-checksums',action='store_true',help='authoring only: report INCOMPLETE_INTEGRITY, never final distribution PASS')
    args=ap.parse_args();root=args.package.resolve()
    try:
        data=load(root);counts=validate(data);links=validate_files(root,data,not args.authoring_no_checksums)
        negative=self_tests(data) if args.self_test else []
        result=dict(status='PLAN_STATIC_CHECK_PASS' if not args.authoring_no_checksums else 'STRUCTURE_PASS_INCOMPLETE_INTEGRITY',scope='document package only; NOT Flutter, NOT actual worktree recovery',counts=counts,local_links_checked=links,negative_contract_tests_rejected=len(negative),negative_cases=negative,checksum_checked=not args.authoring_no_checksums)
        print(json.dumps(result,ensure_ascii=False,indent=2))
    except (AuditError,ValueError,OSError,KeyError) as e:
        print(json.dumps({'status':'FAIL','error':str(e)},ensure_ascii=False),file=sys.stderr);sys.exit(1)
if __name__=='__main__':main()
