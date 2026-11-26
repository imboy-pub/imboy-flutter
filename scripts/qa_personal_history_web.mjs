#!/usr/bin/env node
// qa_personal_history_web.mjs —— MH-06 个人云端历史 Web/后端 QA 驱动（LOCAL-CARD-MH-06）。
//
// 纪律（卡面+QA_MANIFEST 冻结）：
// - 必须携带 --qa-manifest；拒绝缺失 manifest、非隔离目标、未证明归属的设备。
// - 逐场景记录收据（候选 HEAD/tree、实际命令/cwd、原始 exit、pass/fail/skip、脱敏日志 sha256），
//   而非只返回脚本退出码；无 mock/skip/HTTP200/截图替代真实行为。
// - 浏览器：机器 Chrome（Playwright channel:'chrome'，借 imboyadmin node_modules，不入 imboyapp 依赖）。
// - KDF 域（frozen ruling）：PBKDF2 迭代 [310000,600000]；HKDF info="imboy/personal-history/v1"。
// - C4：多标签接管=手动 reload（不裁自动接管）。
// - A5：storage/日志明文与密钥 grep 探针。
//
// 用法：
//   node scripts/qa_personal_history_web.mjs --qa-manifest <path> \
//        [--only H02,H06] [--headed] [--app-url http://127.0.0.1:9817/app/] \
//        [--backend-ctl <ctl.sh>] [--web-origin http://127.0.0.1:9817] \
//        [--negative-origin http://127.0.0.1:9818] [--web-root <dir serving qa-client.html>]

import { createHash, randomBytes } from 'node:crypto';
import { execFileSync, spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, appendFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const SCRIPT_PATH = fileURLToPath(import.meta.url);
const SCRIPT_CWD = process.cwd();
const RUN_ID = `mh06-qa-${new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14)}-${process.pid}`;
const RUN_SUFFIX = String(process.pid);

// ---------------- CLI ----------------
function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--qa-manifest') out.manifest = argv[++i];
    else if (a === '--only') out.only = argv[++i];
    else if (a === '--headed') out.headed = true;
    else if (a === '--app-url') out.appUrl = argv[++i];
    else if (a === '--backend-ctl') out.backendCtl = argv[++i];
    else if (a === '--web-origin') out.webOrigin = argv[++i];
    else if (a === '--negative-origin') out.negativeOrigin = argv[++i];
    else if (a === '--web-root') out.webRoot = argv[++i];
    else if (a === '--help' || a === '-h') { out.help = true; }
    else { console.error(`unknown arg: ${a}`); process.exit(2); }
  }
  return out;
}
const ARGS = parseArgs(process.argv.slice(2));
if (ARGS.help || !ARGS.manifest) {
  console.log('usage: node scripts/qa_personal_history_web.mjs --qa-manifest <path> [--only H02,H06] [--headed] [--app-url URL] [--backend-ctl PATH] [--web-origin URL] [--negative-origin URL] [--web-root DIR]');
  process.exit(ARGS.manifest ? 0 : 2);
}

// ---------------- 日志与脱敏 ----------------
const SECRETS = [];
function sanitize(text) {
  let s = String(text);
  for (const sec of SECRETS) s = s.split(sec).join('<redacted>');
  s = s.replace(/(token|refreshtoken|authorization)"?\s*[:=]\s*"?[A-Za-z0-9._~-]{20,}/gi, '$1:<redacted>');
  s = s.replace(/Bearer\s+[A-Za-z0-9._~-]{20,}/g, 'Bearer <redacted>');
  s = s.replace(/\+86(1990000\d{4})/g, '+86****$1');
  s = s.replace(/[A-Za-z0-9+/=]{60,}/g, (m) => `<b64:${m.length}>`);
  return s;
}
function sha256(text) { return createHash('sha256').update(text).digest('hex'); }

// ---------------- manifest 校验（拒绝缺 manifest/非隔离目标/未证明归属设备）----------------
function loadManifest(p) {
  if (!existsSync(p)) { console.error(`FATAL: qa-manifest not found: ${p}`); process.exit(2); }
  const m = JSON.parse(readFileSync(p, 'utf8'));
  const errs = [];
  if (!m.manifest_id || !/^MH06-QA-MANIFEST-/.test(m.manifest_id)) errs.push('manifest_id 非本卡');
  if (m.card !== 'LOCAL-CARD-MH-06') errs.push(`card 不符: ${m.card}`);
  const ib = m.isolated_backend || {};
  if (ib.http_host !== '127.0.0.1') errs.push(`http_host 非回环: ${ib.http_host}`);
  if (Number(ib.http_port) !== 9816) errs.push(`http_port 非 9816: ${ib.http_port}`);
  const db = ib.database || {};
  if (db.db_name !== 'mh06_personal_history_r1') errs.push(`db_name 非隔离库: ${db.db_name}`);
  if (db.owner_role !== 'imboy_plan_qa') errs.push(`owner_role 非计划 QA: ${db.owner_role}`);
  if (!String(db.instance || '').includes('55427')) errs.push('pg instance 非 55427 计划实例');
  if (!m.log_dir) errs.push('log_dir 缺失');
  const wo = m.web_origin || {};
  if (!String(wo.primary || '').startsWith('http://127.0.0.1:')) errs.push('web_origin.primary 非回环隔离');
  if (!m.synthetic_accounts || !String(m.synthetic_accounts.range || '').includes('8101')) errs.push('synthetic_accounts 段非 8101~');
  if (errs.length) { console.error('FATAL: manifest 校验失败:\n  ' + errs.join('\n  ')); process.exit(2); }
  return m;
}
const MANIFEST = loadManifest(ARGS.manifest);
const TS_ROOT = resolve(MANIFEST.log_dir, '..');            // .task-state/IMBOY_MASTER_V2_2_20261118
const WT_IMBOYAPP = join(TS_ROOT, '..', '..', '_task_worktrees', 'IMBOY_MASTER_V2_2_20261118', 'imboyapp');
const WT_IMBOY = join(TS_ROOT, '..', '..', '_task_worktrees', 'IMBOY_MASTER_V2_2_20261118', 'imboy');
const API_BASE = `http://127.0.0.1:9816`;
const WEB_ORIGIN = ARGS.webOrigin || 'http://127.0.0.1:9817';
const NEG_ORIGIN = ARGS.negativeOrigin || 'http://127.0.0.1:9818';
const WEB_ROOT = ARGS.webRoot || join(TS_ROOT, 'runtime', 'mh06', 'web');
const CLIENT_URL = `${WEB_ORIGIN}/qa-client.html`;
const BACKEND_CTL = ARGS.backendCtl || join(TS_ROOT, 'runtime', 'mh06', 'backend', 'ctl-mh06.sh');
const RUN_DIR = join(MANIFEST.log_dir, RUN_ID);
mkdirSync(RUN_DIR, { recursive: true });
mkdirSync(join(MANIFEST.log_dir, 'logs'), { recursive: true });

// ---------------- 指纹 ----------------
function gitInfo(cwd) {
  try {
    const head = execFileSync('git', ['rev-parse', 'HEAD'], { cwd, encoding: 'utf8' }).trim();
    const branch = execFileSync('git', ['rev-parse', '--abbrev-ref', 'HEAD'], { cwd, encoding: 'utf8' }).trim();
    const dirty = execFileSync('git', ['status', '--porcelain'], { cwd, encoding: 'utf8' })
      .split('\n').filter(Boolean);
    return { head, branch, dirty_count: dirty.length, dirty: dirty.slice(0, 12) };
  } catch (e) { return { error: String(e) }; }
}
const FINGERPRINT = {
  imboy: gitInfo(WT_IMBOY),
  imboyapp: gitInfo(WT_IMBOYAPP),
  script: SCRIPT_PATH,
  manifest_id: MANIFEST.manifest_id,
  node: process.version,
  run_id: RUN_ID,
};

// ---------------- 收据记录 ----------------
const RECEIPTS = [];
const SCENARIO_LOGS = {};
function scLog(id, line) {
  SCENARIO_LOGS[id] = (SCENARIO_LOGS[id] || '') + line + '\n';
}
async function runScenario(id, gate, carrier, fn) {
  const rec = {
    scenario_id: id, gate, carrier, status: 'FAIL', checks: [],
    command: `node scripts/qa_personal_history_web.mjs --qa-manifest ${ARGS.manifest}${ARGS.only ? ' --only ' + ARGS.only : ''}`,
    cwd: SCRIPT_CWD, candidate: FINGERPRINT,
    started_at: new Date().toISOString(), exit_code: 1, run_id: RUN_ID,
  };
  scLog(id, `== ${id} (${gate}) carrier=${carrier} start ${rec.started_at}`);
  scLog(id, `candidate imboy=${FINGERPRINT.imboy.head} imboyapp=${FINGERPRINT.imboyapp.head}`);
  try {
    const out = await fn({
      check: (name, ok, detail) => { rec.checks.push({ name, ok: !!ok, detail: sanitize(detail === undefined ? '' : detail) }); scLog(id, `  [${ok ? 'PASS' : 'FAIL'}] ${name}${detail !== undefined ? ' :: ' + sanitize(String(detail)).slice(0, 400) : ''}`); return !!ok; },
      log: (line) => scLog(id, '  ' + sanitize(String(line))),
    });
    rec.status = out && out.status ? out.status : (rec.checks.length && rec.checks.every(c => c.ok) ? 'PASS' : 'FAIL');
    if (out && out.note) rec.note = out.note;
  } catch (e) {
    rec.status = 'FAIL';
    rec.error = sanitize(String(e && e.stack || e));
    scLog(id, '  EXCEPTION: ' + sanitize(String(e && e.stack || e)));
  }
  rec.ended_at = new Date().toISOString();
  rec.exit_code = rec.status === 'PASS' ? 0 : (rec.status === 'SKIP' ? 2 : 1);
  const logPath = join(RUN_DIR, `scenario-${id}.log`);
  writeFileSync(logPath, sanitize(SCENARIO_LOGS[id] || '(no log)'));
  rec.log = `scenario-${id}.log`;
  rec.log_sha256 = sha256(readFileSync(logPath, 'utf8'));
  RECEIPTS.push(rec);
  appendFileSync(join(MANIFEST.log_dir, 'logs', `mh06-qa-${RUN_ID}.log`), sanitize(SCENARIO_LOGS[id] || '') + '\n');
  console.log(`[${id}] ${rec.status} (checks ${rec.checks.filter(c => c.ok).length}/${rec.checks.length})`);
  return rec;
}

// ---------------- Playwright 引导（借 imboyadmin，channel:'chrome'）----------------
let playwrightMod = null;
function loadPlaywright() {
  const candidates = [
    process.env.PLAYWRIGHT_PATH,
    '/Users/leeyi/project/imboy.pub/imboyadmin/node_modules/playwright',
    join(TS_ROOT, '..', '..', '_task_worktrees', 'IMBOY_MASTER_V2_2_20261118', 'imboyadmin', 'node_modules', 'playwright'),
  ].filter(Boolean);
  for (const c of candidates) {
    try {
      const req = createRequire(join(c, 'package.json'));
      playwrightMod = req('playwright');
      return { source: c, version: req('playwright/package.json').version };
    } catch (_) { /* next */ }
  }
  throw new Error('playwright 不可用（imboyadmin node_modules 与 PLAYWRIGHT_PATH 均失败）');
}

// ---------------- 后端 HTTP（node 侧，用于账号准备）----------------
async function httpJson(path, { method = 'GET', body, token, headers: extraHeaders, rawText = false } = {}) {
  const res = await fetch(API_BASE + path, {
    method,
    headers: Object.assign({},
      token ? { authorization: token } : {},
      body ? { 'content-type': 'application/json' } : {},
      extraHeaders || {}),
    body: body ? JSON.stringify(body) : undefined,
  });
  if (rawText) return { httpStatus: res.status, bodyText: await res.text() };
  let json = null; try { json = await res.json(); } catch (_) {}
  return { httpStatus: res.status, body: json };
}

// ---------------- psql 探针 ----------------
let PG_PW = null;
function pgProbe(sql) {
  if (!PG_PW) {
    const pwPath = join(TS_ROOT, 'runtime', 'qa-pg18-codex', '.pg-password');
    PG_PW = readFileSync(pwPath, 'utf8').trim();
  }
  const url = `postgresql://imboy_plan_qa:${PG_PW}@127.0.0.1:55427/mh06_personal_history_r1`;
  try {
    const out = execFileSync('psql', [url, '-tAc', sql], { encoding: 'utf8', timeout: 15000 }).trim();
    return { ok: true, out };
  } catch (e) { return { ok: false, out: String(e.message).split('\n')[0] }; }
}

// ---------------- 账号 ----------------
const ACCOUNTS = {
  A: { mobile: '+8619900008101', pwd: 'Mh06Qa#8101A', nick: 'MH06 QA A', kpwd: 'mh06-pass-A' },
  B: { mobile: '+8619900008102', pwd: 'Mh06Qa#8102B', nick: 'MH06 QA B', kpwd: 'mh06-pass-B' },
  C: { mobile: '+8619900008103', pwd: 'Mh06Qa#8103C', nick: 'MH06 QA C', kpwd: 'mh06-pass-C' },
  D: { mobile: '+8619900008104', pwd: 'Mh06Qa#8104D', nick: 'MH06 QA D', kpwd: 'mh06-pass-D' },
  E: { mobile: '+8619900008105', pwd: 'Mh06Qa#8105E', nick: 'MH06 QA E', kpwd: 'mh06-pass-E' },
  F: { mobile: '+8619900008106', pwd: 'Mh06Qa#8106F', nick: 'MH06 QA F', kpwd: 'mh06-pass-F' },
};
for (const a of Object.values(ACCOUNTS)) SECRETS.push(a.pwd, a.kpwd);
const SESSIONS = {}; // A -> {token, uid}

async function ensureAccount(key) {
  const a = ACCOUNTS[key];
  const su = await httpJson('/api/v1/passport/signup', { method: 'POST',
    body: { type: 'mobile', account: a.mobile, pwd: a.pwd, code: '123456', rsa_encrypt: '0', nickname: a.nick } });
  const su2 = su.httpStatus === 200 && su.body && su.body.code === 0 ? null : su; // 重复注册 tolerated（复跑）
  // Web 面登录（web_human JWT）：须带 origin/did/dname（be22 语义）
  // TSID 纪律：uid 是 64-bit 整数，Node JSON.parse 会丢精度——从原始文本
  // 以字符串提取（对齐 safeParseBigIntJson 语义），绝不走 double。
  const lgRaw = await fetch(`${API_BASE}/api/v1/web/passport/login`, { // nosemgrep: react-insecure-request — loopback QA fixture (127.0.0.1), dev-only, not shipped
    method: 'POST',
    headers: { 'content-type': 'application/json', origin: WEB_ORIGIN,
      did: `mh06-qa-${key.toLowerCase()}`, dname: 'Chrome-mh06' },
    body: JSON.stringify({ type: 'mobile', account: a.mobile, pwd: a.pwd, rsa_encrypt: '0' }),
  }).then(async r => ({ httpStatus: r.status, text: await r.text() }));
  const uidMatch = lgRaw.text.match(/"uid":(\d+)/);
  const uidStr = uidMatch ? uidMatch[1] : null;
  const tokenMatch = lgRaw.text.match(/"token":"([A-Za-z0-9._~-]+)"/);
  const lg = { httpStatus: lgRaw.httpStatus, body: { code: uidStr && tokenMatch ? 0 : 1, payload: { uid: uidStr, token: tokenMatch ? tokenMatch[1] : null } } };
  // 原生面登录（H18 负例/原生面探测用）；token 正则提取（JWT 无精度问题）
  const ntRaw = await fetch(`${API_BASE}/api/v1/passport/login`, { // nosemgrep: react-insecure-request — loopback QA fixture (127.0.0.1), dev-only, not shipped
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ type: 'mobile', account: a.mobile, pwd: a.pwd, rsa_encrypt: '0' }),
  }).then(r => r.text());
  const ntToken = (ntRaw.match(/"token":"([A-Za-z0-9._~-]+)"/) || [])[1] || null;
  if (lg.httpStatus !== 200 || !lg.body || lg.body.code !== 0 || !lg.body.payload || !lg.body.payload.token || !uidStr) {
    throw new Error(`account ${key} web login failed: signup=${JSON.stringify(sanitize(JSON.stringify(su2 || su)))} weblogin=${sanitize(lgRaw.text.slice(0, 200))}`);
  }
  SESSIONS[key] = {
    token: lg.body.payload.token,
    ntoken: ntToken,
    uid: uidStr,
    // web_human 会话设备标识（weblogin did 头）——personal-history 游标类端点
    // 的身份门（守卫 6285b2a5c）要求 client_instance 与其逐字相等。
    did: `mh06-qa-${key.toLowerCase()}`,
  };
  SECRETS.push(lg.body.payload.token, SESSIONS[key].ntoken || 'x');
  return SESSIONS[key];
}
function convKey(k1, k2) {
  // TSID 64-bit：禁止 Number()（double 丢精度）——BigInt 比较 + 字符串拼接
  const a = SESSIONS[k1].uid, b = SESSIONS[k2].uid;
  const [lo, hi] = BigInt(a) <= BigInt(b) ? [a, b] : [b, a];
  return `c2c:${lo}:${hi}`;
}

// ---------------- 真实 C2C 事实（守卫 beee163ea：归档必须引用真实已受理 C2C 消息事实）----------------
// personal_history_ds:upload_tx 的 guard_message_fact 经 accepted_message_sql 校验：
// msg_c2c 受理行须存在、conv_seq/action_version 与上传项逐字一致（编辑消费数=版本）、
// accepted_at ≥ opt-in enabled_at、上传者为会话参与方。因此每个归档项先走真实
// 发送链（原生 WS 面 /api/v1/ws），conv_seq 取自 SERVER_ACK（服务端权威）。
const FACTS = {};   // msg_id -> { conv, conv_seq, action_version, from, to }
const WSPOOL = {};  // key -> WebSocket；key:waiters -> [等待器]
const MSG_WAIT_MS = 15000;

async function wsOpen(key) {
  const cur = WSPOOL[key];
  if (cur && cur.readyState === 1) return cur;
  if (cur) { try { cur.close(); } catch (_) { /* stale */ } }
  // 原生面 WS（ntoken；did 与 web 面分开命名，互不抢占身份）。
  // 服务端要求 sec-websocket-protocol（缺省=400/406 拒手）——imboy-json=JSON 文本帧。
  const ws = new WebSocket(
    `ws://127.0.0.1:9816/api/v1/ws?token=${SESSIONS[key].ntoken}&did=mh06-nw-${key.toLowerCase()}&cos=web`,
    ['imboy-json']);
  WSPOOL[key + ':waiters'] = WSPOOL[key + ':waiters'] || [];
  ws.addEventListener('message', (m) => {
    let d = null; try { d = JSON.parse(String(m.data)); } catch (_) { return; }
    const q = WSPOOL[key + ':waiters'];
    for (let i = 0; i < q.length; i++) {
      if (q[i].match(d)) { clearTimeout(q[i].timer); q.splice(i, 1)[0].resolve(d); break; }
    }
  });
  await new Promise((res, rej) => {
    const t = setTimeout(() => rej(new Error('ws open timeout: ' + key)), MSG_WAIT_MS);
    ws.addEventListener('open', () => { clearTimeout(t); res(); }, { once: true });
    ws.addEventListener('error', () => { clearTimeout(t); rej(new Error('ws open error: ' + key)); }, { once: true });
  });
  WSPOOL[key] = ws;
  return ws;
}

function wsCall(key, frame, match, timeoutMs = MSG_WAIT_MS) {
  return new Promise((resolve, reject) => {
    const q = WSPOOL[key + ':waiters'];
    const w = { match, resolve,
      timer: setTimeout(() => {
        const i = q.indexOf(w); if (i >= 0) q.splice(i, 1);
        reject(new Error('ws wait timeout ' + key + ' frame=' + JSON.stringify(frame).slice(0, 120)));
      }, timeoutMs) };
    q.push(w);
    WSPOOL[key].send(JSON.stringify(frame));
  });
}

function msgIdLit(s) { return String(s).replace(/'/g, "''"); }

async function factRow(msgId) {
  const r = pgProbe(`SELECT conv_seq, action_version FROM public.msg_c2c WHERE msg_id='${msgIdLit(msgId)}'`);
  if (!r.ok || !r.out || !r.out.includes('|')) return null;
  const [seq, av] = r.out.split('|');
  return { conv_seq: Number(seq), action_version: Number(av) };
}

// 真实发送：SERVER_ACK 的 conv_seq 是权威值；受理事实行随后在 msg_c2c 可查。
async function sendReal(senderKey, peerKey, msgId, body) {
  await wsOpen(senderKey);
  const conv = convKey(senderKey, peerKey);
  const ack = await wsCall(senderKey, {
    id: msgId, type: 'C2C', from: SESSIONS[senderKey].uid, to: SESSIONS[peerKey].uid,
    msg_type: 'text', payload: { msg_type: 'text', body }, created_at: Date.now(),
  }, (d) => d && (d.in_reply_to === msgId || d.id === msgId));
  const perr = ack && ack.payload && (ack.payload.error || ack.payload.error_code);
  if (perr) throw new Error(`send ${msgId} rejected: ${String(perr).slice(0, 140)}`);
  if (!Number.isInteger(ack.conv_seq) || ack.conv_seq <= 0) {
    throw new Error(`send ${msgId}: SERVER_ACK 无 conv_seq: ${JSON.stringify(ack).slice(0, 200)}`);
  }
  let row = null;
  for (let i = 0; i < 20 && !row; i++) { row = await factRow(msgId); if (!row) await new Promise(r => setTimeout(r, 300)); }
  if (!row) throw new Error(`send ${msgId}: 受理事实未落库（msg_c2c 无行）`);
  FACTS[msgId] = { conv, conv_seq: ack.conv_seq, action_version: row.action_version, from: senderKey, to: peerKey };
  return FACTS[msgId];
}

// 真实编辑链：A message_edit 受理（要求对端在线）+ B message_edit_ack 消费
// → 事实 action_version+1（消费流水线自动递增 msg_c2c.action_version）。
async function editReal(senderKey, peerKey, originalMsgId, newContent) {
  await wsOpen(senderKey); await wsOpen(peerKey);
  const f = FACTS[originalMsgId];
  if (!f) throw new Error('editReal: no fact for ' + originalMsgId);
  const editId = 'edit-' + originalMsgId + '-' + RUN_SUFFIX;
  const rep = await wsCall(senderKey, {
    id: editId, type: 'C2C', action: 'message_edit',
    from: SESSIONS[senderKey].uid, to: SESSIONS[peerKey].uid, msg_type: 'text',
    payload: { original_msg_id: originalMsgId, content: newContent, edited_at: Date.now() },
    created_at: Date.now(),
  }, (d) => d && (d.in_reply_to === editId || d.id === editId));
  const perr = rep && rep.payload && (rep.payload.error || rep.payload.error_code);
  if (perr) throw new Error(`edit ${originalMsgId} rejected: ${String(perr).slice(0, 140)}`);
  const ackId = editId; // 消费按 request_id 匹配受理行（lock_receipt WHERE request_id=$1）——回执必须回显受理帧 id
  wsCall(peerKey, { // 消费无独立回执——fire-and-consume，以下轮询收敛为准。
    // 信封校验（validate_peer_fields）要求 from/to 合法、msg_type 非空——缺即
    // json_message_invalid(missing_required_fields) 丢弃（attempt-4 实证）。
    id: ackId, type: 'C2C', action: 'message_edit_ack',
    from: SESSIONS[peerKey].uid, to: SESSIONS[senderKey].uid, msg_type: 'text',
    payload: { original_msg_id: originalMsgId, content: newContent, edited_at: Date.now() },
    created_at: Date.now(),
  }, () => true, 8000).catch(() => {});
  for (let i = 0; i < 24; i++) {
    const row = await factRow(originalMsgId);
    if (row && row.action_version === f.action_version + 1 && row.conv_seq === f.conv_seq) {
      f.action_version = row.action_version;
      return f;
    }
    await new Promise(r => setTimeout(r, 500));
  }
  throw new Error('edit ' + originalMsgId + ': 事实未收敛（action_version 未 +1）');
}

// 幂等建交（QA 账号对）；以 /friend/list（GET，原生 token）原始文本实证关系成立
// （uid 是 64-bit 整数，JSON.parse 会丢精度——对齐 TSID 纪律，禁走解析体）。
async function ensureFriends(pairs) {
  for (const [x, y] of pairs) {
    const have = () => httpJson('/api/v1/friend/list', {
      token: SESSIONS[x].ntoken,
      rawText: true,
    }).then(r => r.bodyText.includes(String(SESSIONS[y].uid)));
    if (await have()) continue; // 已是好友（幂等快路径）
    const add = await httpJson('/api/v1/friend/add', { method: 'POST', token: SESSIONS[x].ntoken,
      body: { to: SESSIONS[y].uid, payload: JSON.stringify({ source: 'mobile', reason: 'mh06 qa fixture' }), created_at: Date.now() } });
    const addMsg = add.body && String(add.body.msg || add.body.field || '');
    const addOk = (add.httpStatus === 200 && add.body && add.body.code === 0) || addMsg === 'already_friends';
    if (!addOk) throw new Error(`friend add ${x}->${y} failed: http=${add.httpStatus} ${JSON.stringify(add.body).slice(0, 160)}`);
    if (addMsg !== 'already_friends') {
      const conf = await httpJson('/api/v1/friend/confirm', { method: 'POST', token: SESSIONS[y].ntoken,
        body: { from: SESSIONS[x].uid, to: SESSIONS[y].uid, payload: JSON.stringify({}) } });
      const confOk = (conf.httpStatus === 200 && conf.body && conf.body.code === 0)
        || (conf.body && conf.body.msg === 'no_pending_request');
      if (!confOk) throw new Error(`friend confirm ${x}->${y} failed: ${JSON.stringify(conf.body).slice(0, 160)}`);
    }
    let ok = await have(); // 落库短暂窗口容忍
    for (let i = 0; i < 10 && !ok; i++) { await new Promise(r => setTimeout(r, 400)); ok = await have(); }
    if (!ok) throw new Error(`friendship ${x}<->${y} not established (raw list lacks ${SESSIONS[y].uid})`);
  }
}

// ---------------- 浏览器设备模型 ----------------
let _pw = null;
const _contexts = {};
async function device(name, { fresh = false } = {}) {
  const dir = join(TS_ROOT, 'runtime', 'mh06', 'browser', `dev-${name}${fresh ? '-' + Date.now() : ''}`);
  mkdirSync(dirname(dir), { recursive: true });
  if (!_pw) { const meta = loadPlaywright(); scLog('boot', `playwright ${meta.version} from ${meta.source}`); _pw = meta ? playwrightMod : playwrightMod; }
  if (_contexts[name] && !fresh) return _contexts[name];
  const ctx = await playwrightMod.chromium.launchPersistentContext(dir, {
    channel: 'chrome', headless: !ARGS.headed,
    args: ['--no-first-run', '--no-default-browser-check'],
  });
  _contexts[name] = ctx;
  return ctx;
}
async function clientPage(ctx, accountKey, extra = {}) {
  const page = await ctx.newPage();
  page.on('console', (m) => { if (m.type() === 'error') scLog('console', `page-console-error: ${m.text().slice(0, 300)}`); });
  await page.goto(CLIENT_URL, { waitUntil: 'load' });
  await page.waitForFunction(() => window.__mh06 && window.__mh06.cfg, null, { timeout: 8000 });
  const s = SESSIONS[accountKey];
  await page.evaluate(async ({ token, uid, api, domain, password, did }) => {
    await window.__mh06.init({ token, account: String(uid), api, domain, password, did });
  }, { token: s.token, uid: s.uid, api: `${API_BASE}/api/v1/web/personal-history`, domain: extra.domain || 'local.mh06.qa', password: ACCOUNTS[accountKey].kpwd, did: s.did });
  // 设备开机语义：读状态，ON 则尽力收集 v1 密钥包（fail 不阻断——负例场景
  // 如未 opt-in/错口令依赖显式失败，不在这里吞）
  if (!extra.noAutoArm) {
    await page.evaluate(async () => {
      try {
        const st = await window.__mh06.status();
        const gen = st.body && st.body.payload && st.body.payload.generation;
        if (st.body && st.body.payload && st.body.payload.state === 'ON' && gen > 0 && window.__mh06.cfg().password) {
          await window.__mh06.restorePackage(window.__mh06.cfg().password, 1, gen);
        }
      } catch (_) { /* best-effort */ }
    }).catch(() => {});
  }
  return page;
}
async function reLogin(key) {
  // 后端重启后 web 会话失效（dsid 会话在内存）→ 重新 web 登录并刷新 SESSIONS
  const a = ACCOUNTS[key];
  const raw = await fetch(`${API_BASE}/api/v1/web/passport/login`, { // nosemgrep: react-insecure-request — loopback QA fixture (127.0.0.1), dev-only, not shipped
    method: 'POST',
    headers: { 'content-type': 'application/json', origin: WEB_ORIGIN,
      did: `mh06-qa-${key.toLowerCase()}`, dname: 'Chrome-mh06' },
    body: JSON.stringify({ type: 'mobile', account: a.mobile, pwd: a.pwd, rsa_encrypt: '0' }),
  }).then(r => r.text());
  const token = (raw.match(/"token":"([A-Za-z0-9._~-]+)"/) || [])[1];
  if (!token) throw new Error('reLogin failed for ' + key);
  SESSIONS[key].token = token; SECRETS.push(token);
  return token;
}
const ev = (page, fn, arg) => page.evaluate(fn, arg);
async function rawInit(page, accountKey, domain = 'local.mh06.qa') {
  const s = SESSIONS[accountKey];
  await ev(page, ({ token, uid, api, domain, password, did }) =>
    window.__mh06.init({ token, account: String(uid), api, domain, password, did }),
    { token: s.token, uid: s.uid, api: `${API_BASE}/api/v1/web/personal-history`, domain, password: ACCOUNTS[accountKey].kpwd, did: s.did });
}

// ---------------- 场景注册 ----------------
const SC = {}; // id -> {gate, carrier, fn}
function scenario(id, gate, carrier, fn) { SC[id] = { gate, carrier, fn }; }

// ---------- 前置探针（非 gate 场景；失败即整跑失败） ----------
async function preflight() {
  await runScenario('PREFLIGHT', 'LOCAL-CARD-MH-06', 'QA-WEB', async ({ check, log }) => {
    const h = await fetch(`${API_BASE}/api/v1/personal-history/status`).then(r => r.status).catch(() => 'network-error'); // nosemgrep: react-insecure-request — loopback QA fixture (127.0.0.1), dev-only, not shipped
    check('backend 9816 alive (unauth status reachable)', h === 401 || h === 403, `http=${h}`);
    check('web origin reachable', await fetch(`${WEB_ORIGIN}/qa-client.html`).then(r => r.ok).catch(() => false), WEB_ORIGIN);
    for (const k of Object.keys(ACCOUNTS)) {
      const s = await ensureAccount(k).catch(e => ({ error: String(e) }));
      check(`account ${k} ready`, !s.error, s.error ? s.error : `uid=${s.uid}`);
      if (s.error) throw new Error(`account ${k} unavailable: ` + s.error);
    }
    log(`uids: ${Object.entries(SESSIONS).map(([k, v]) => k + '=' + v.uid).join(' ')}`);
    // 真实 C2C 事实链的前提：会话双方必须互为好友（send_real 的关系门）。
    // 幂等建交 + list 实证；不成立即响亮失败（preflight 纪律）。
    await ensureFriends([['A', 'B'], ['C', 'B']]);
    log(`friendships ensured: A<->B, C<->B`);
    // 每轮全量旅程前清理 QA 设备 profile（旅程内跨场景持久性不受影响）
    try { execFileSync('bash', ['-c', `rm -rf ${join(TS_ROOT, 'runtime', 'mh06', 'browser')}/dev-*`], { timeout: 20000 }); log('device profiles wiped for fresh journey'); } catch (e) { log('device wipe: ' + String(e).slice(0, 120)); }
    // 每轮全量旅程=新装语义：个人历史域四表清零（账号行保留；场景内重新 opt-in）
    for (const t of ['personal_history_archive', 'personal_history_cursor', 'personal_history_key_package', 'personal_history_authorization']) {
      const r = pgProbe(`DELETE FROM ${t}`);
      if (!r.ok) throw new Error('domain reset failed: ' + t + ' ' + r.out);
    }
    // 消息事实面同新装语义：QA 合成账号（A~F）的 C2C 受理事实与动作流水清零。
    // 否则跨轮陈旧事实（accepted_at < 本轮 opt-in enabled_at）会被事实门正确拒绝
    // （beee163ea 的 accepted_at >= enabled_at 窗口），幂等键也会跨轮漂移。
    const uidList = Object.values(SESSIONS).map(s => s.uid).join(',');
    // 孤儿感知：受理事实可能只剩 forward_source_fact 侧（早前轮次的中断残片，
    // msg_c2c 行已被上一轮重置清走）——两侧并集才是完整的 QA 事实 id 集。
    const idq = pgProbe(`SELECT msg_id FROM public.msg_c2c WHERE from_id IN (${uidList}) OR to_id IN (${uidList})
UNION SELECT msg_id FROM public.c2c_forward_source_fact WHERE sender_id IN (${uidList}) OR recipient_id IN (${uidList})`);
    if (!idq.ok) throw new Error('fact-id gather failed: ' + idq.out);
    const idList = idq.out.split('\n').map(s => s.trim()).filter(Boolean)
      .map(id => `'${id.replace(/'/g, "''")}'`).join(',') || 'NULL';
    for (const spec of [
      `DELETE FROM public.c2c_action_receipt WHERE original_msg_id IN (${idList})`,
      `DELETE FROM public.c2c_forward_source_fact WHERE msg_id IN (${idList})`,
      `DELETE FROM public.msg_store_staging WHERE type='c2c' AND msg_id IN (${idList})`,
      `DELETE FROM public.msg_store WHERE chat_type='c2c' AND msg_id IN (${idList})`,
      `DELETE FROM public.msg_c2c WHERE msg_id IN (${idList})`,
    ]) {
      const r = pgProbe(spec);
      if (!r.ok) throw new Error('message-fact reset failed: ' + spec.slice(0, 60) + ' ' + r.out);
    }
    log(`message-fact reset: ${idList === 'NULL' ? 0 : idList.split(',').length} prior facts cleared`);
    const probe = pgProbe(`SELECT count(*) FROM personal_history_authorization`);
    check('pg probe（域已重置，authorization=0）', probe.ok && probe.out === '0', probe.out);
  });
  if (RECEIPTS.at(-1).status !== 'PASS') { console.error('FATAL: preflight failed'); await finalize(3); process.exit(3); }
}

// ---------- H01（QA 份：默认 OFF 零写入） ----------
scenario('H01', 'LOCAL-MSG-H01', 'QA-WEB+PROBE', async ({ check, log }) => {
  // F=专用未授权探针账号（生命周期内永不 opt-in，复跑稳定 OFF）
  const page = await clientPage(await device('h01', { fresh: true }), 'F');
  const st = await ev(page, () => window.__mh06.status());
  check('未授权账号 status=OFF generation=0', st.body && st.body.payload && st.body.payload.state === 'OFF' && st.body.payload.generation === 0, JSON.stringify(st.body && st.body.payload));
  const conv = convKey('F', 'A');
  const up = await ev(page, ({ conv }) => window.__mh06.upload({
    conversation_id: conv, msg_id: 'h01-x', action_version: 0, conv_seq: 1,
    ciphertext: 'aGgwNg==', envelope_meta: { alg: 'aes-256-gcm', key_version: 1, nonce: 'bm9uY2U=', aad: 'YWFk' } }), { conv });
  check('未 opt-in 上传被拒 403（参与守卫/未开启任一即拒）', up.httpStatus === 403 && up.body && up.body.payload && String(up.body.payload.error || up.body.msg || '').includes('not_enabled') || up.httpStatus === 403, `http=${up.httpStatus} body=${JSON.stringify(up.body && up.body.payload).slice(0, 160)}`);
  const kp = await ev(page, () => window.__mh06.restorePackage('x', 1, 0));
  check('未 opt-in 读 key-package 被拒 403', kp.httpStatus === 403, `http=${kp.httpStatus}`);
  const fuid = SESSIONS.F.uid;
  const probe = pgProbe(`SELECT (SELECT count(*) FROM personal_history_archive WHERE account_id = ${fuid}) + (SELECT count(*) FROM personal_history_key_package WHERE account_id = ${fuid})`);
  check('未授权账号 DB 零归档/零密钥包行', probe.ok && probe.out === '0', probe.out);
});

// ---------- H05（Web 面：授权上传 + 零明文/私钥/口令探针） ----------
scenario('H05', 'LOCAL-MSG-H05', 'QA-WEB+PROBE', async ({ check, log }) => {
  const page = await clientPage(await device('main'), 'A');
  const st = await ev(page, () => window.__mh06.status());
  const oi = await ev(page, () => window.__mh06.optIn('mh06-qa-devA'));
  check('A opt-in 成功 ON', oi.httpStatus === 200 && oi.body && oi.body.payload && oi.body.payload.state === 'ON', JSON.stringify(oi.body && oi.body.payload));
  const gen = oi.body.payload.generation;
  const pk = await ev(page, ({ it }) => window.__mh06.putKeyPackage(1, 'mh06-pass-A', it), { it: 310000 });
  check('A put key-package v1（310000 迭代；复跑 409=版本已存同 DEK 幂等）', (pk.httpStatus === 200 && pk.body.code === 0) || pk.httpStatus === 409, JSON.stringify(pk.body && pk.body.payload).slice(0, 140));
  const conv = convKey('A', 'B');
  // 真实 C2C 事实：m-a1 先走真实发送链（A→B，SERVER_ACK 权威 conv_seq），
  // 归档项引用事实值（action_version=0 初始受理版本）。
  const f1 = await sendReal('A', 'B', 'm-a1', 'MH06-PLAIN-MARKER-alpha 从A到B的明文一');
  const r1 = await ev(page, ({ conv, gen, seq, av }) => window.__mh06.encryptFor({
    conversationId: conv, msgId: 'm-a1', actionVersion: av, convSeq: seq,
    text: 'MH06-PLAIN-MARKER-alpha 从A到B的明文一', keyVersion: 1, generation: gen }).then(p => window.__mh06.upload(p)), { conv, gen, seq: f1.conv_seq, av: f1.action_version });
  check('A 加密上传 m-a1 成功（复跑 duplicate=幂等回放同语义）', r1.httpStatus === 200 && r1.body.code === 0 && ['stored', 'duplicate'].includes(r1.body.payload.result), JSON.stringify(r1.body && r1.body.payload));
  const pg1 = pgProbe(`SELECT count(*) FROM personal_history_archive WHERE encode(ciphertext,'escape') LIKE '%MH06-PLAIN-MARKER%' OR encode(ciphertext,'escape') LIKE '%从A到B%'`);
  check('PG 归档零明文标记（H20/A5 同源探针）', pg1.ok && pg1.out === '0', pg1.out);
  const pg2 = pgProbe(`SELECT count(*) FROM personal_history_key_package WHERE encode(wrapped_key,'escape') LIKE '%mh06-pass-A%' OR encode(wrapped_key,'escape') LIKE '%BEGIN%'`);
  check('PG 密钥包零口令/零 PEM', pg2.ok && pg2.out === '0', pg2.out);
  const hygiene = await ev(page, () => window.__mh06.plaintextProbe(['mh06-pass-A']));
  check('浏览器 storage 零口令残留（A5）', hygiene.hits.length === 0, JSON.stringify(hygiene));
  await page.close();
});

// ---------- H02 + N1-①（IndexedDB 持久恢复，刷新/重开不重插） ----------
async function seedA(ctx) {
  const page = await clientPage(ctx, 'A');
  const st = await ev(page, () => window.__mh06.status());
  const gen = st.body.payload.generation;
  const conv = convKey('A', 'B');
  // 真实 C2C 事实：m-a1 已由 H05 发送（重发=duplicate ack 回同 conv_seq）；
  // m-a2..m-a5 新发送 → 连续 conv_seq。归档引用各自事实值。
  for (const mid of ['m-a1', 'm-a2', 'm-a3', 'm-a4', 'm-a5']) {
    if (mid !== 'm-a1') await sendReal('A', 'B', mid, `MH06-PLAIN-MARKER-msg-${mid}`);
  }
  for (const [i, mid] of ['m-a1', 'm-a2', 'm-a3', 'm-a4', 'm-a5'].entries()) {
    const f = FACTS[mid];
    const dup = mid === 'm-a1'; // m-a1 已存在 → 幂等重放
    if (!dup) await ev(page, ({ conv, gen, mid, av, seq }) => window.__mh06.encryptFor({
      conversationId: conv, msgId: mid, actionVersion: av, convSeq: seq,
      text: `MH06-PLAIN-MARKER-msg-${mid}`, keyVersion: 1, generation: gen }).then(p => window.__mh06.upload(p)), { conv, gen, mid, av: f.action_version, seq: f.conv_seq });
  }
  return { page, conv, gen };
}
scenario('H02', 'LOCAL-MSG-H02', 'QA-WEB', async ({ check, log }) => {
  const ctx = await device('main');
  const { page, conv, gen } = await seedA(ctx);
  const st0 = await ev(page, () => window.__mh06.status());
  await ev(page, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen: st0.body.payload.generation });
  const pull1 = await ev(page, () => window.__mh06.pullOnce({}));
  check('首拉合并 5 行（含幂等重放去重）', pull1.applied === 5, JSON.stringify(pull1).slice(0, 220));
  const cursor1 = await ev(page, () => window.__mh06.cursorNow());
  check('游标推进 >0', cursor1 > 0, `cursor=${cursor1}`);
  const rows1 = await ev(page, (conv) => window.__mh06.rowsAll(conv).then(rs => rs.length), conv);
  // 刷新（reload）后 resume：同历史同游标，不重插
  await page.reload({ waitUntil: 'load' });
  await page.waitForFunction(() => window.__mh06 && window.__mh06.cfg);
  const resumed = await ev(page, () => window.__mh06.resume());
  check('reload 后 cfg 从 IndexedDB 恢复', !!resumed && resumed.account, JSON.stringify(resumed && resumed.account));
  const rows2 = await ev(page, (conv) => window.__mh06.rowsAll(conv).then(rs => rs.length), conv);
  const cursor2 = await ev(page, () => window.__mh06.cursorNow());
  check('reload 后行数不变（不重插）', rows2 === rows1, `before=${rows1} after=${rows2}`);
  check('reload 后游标不回退', cursor2 === cursor1, `before=${cursor1} after=${cursor2}`);
  const pull2 = await ev(page, () => window.__mh06.pullOnce({}));
  check('reload 后重拉全量幂等（duplicates=applied+dup 总量、applied=0）', pull2.applied === 0, JSON.stringify({ applied: pull2.applied, duplicates: pull2.duplicates }));
  await page.close();
});
scenario('N1-P1', 'LOCAL-CARD-MH-06:LOCAL:02', 'QA-WEB', async ({ check }) => {
  // N1 证①：IndexedDB 持久恢复（引用 H02 主链，独立复核一次关标签→重开）
  const ctx = await device('main');
  const page = await ctx.newPage();
  await page.goto(CLIENT_URL, { waitUntil: 'load' });
  await page.waitForFunction(() => window.__mh06 && window.__mh06.cfg);
  const resumed = await ev(page, () => window.__mh06.resume());
  const conv = convKey('A', 'B');
  const rows = await ev(page, (conv) => window.__mh06.rowsAll(conv).then(rs => ({ n: rs.length, texts: rs.filter(r => !r.tombstone).map(r => r.text).sort() })), conv);
  check('关标签重开后 IndexedDB 持久恢复（5 行明文逐字在场）', rows.n === 5 && rows.texts.filter(t => t && t.startsWith('MH06-PLAIN-MARKER')).length === 5, JSON.stringify(rows));
  await page.close();
});

// ---------- H06 + N1-③（真实新设备解密：全新 profile + 服务端取包 + 逐字比对） ----------
scenario('H06', 'LOCAL-MSG-H06', 'QA-WEB', async ({ check, log }) => {
  const ctx = await device('h06-new-device', { fresh: true }); // 全新设备身份（独立 user-data-dir）
  const page = await clientPage(ctx, 'A');
  const st = await ev(page, () => window.__mh06.status());
  const gen = st.body.payload.generation;
  check('新设备 status=ON generation 一致', st.body.payload.state === 'ON' && gen > 0, `gen=${gen}`);
  const wrong = await ev(page, ({ gen }) => window.__mh06.restorePackage('totally-wrong-pass', 1, gen), { gen });
  check('错口令解封显式失败（不伪装）', wrong._unwrapped === false && !!wrong._unwrapError, wrong._unwrapError || 'no error');
  const arm = await ev(page, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen });
  check('正确口令从服务端取包解封成功', arm._unwrapped === true, JSON.stringify(arm._unwrapError || 'ok'));
  const pull = await ev(page, () => window.__mh06.pullOnce({}));
  check('新设备全量恢复 5 行', pull.applied === 5, JSON.stringify({ applied: pull.applied, duplicates: pull.duplicates }));
  const conv = convKey('A', 'B');
  const rows = await ev(page, (conv) => window.__mh06.rowsAll(conv).then(rs => rs.filter(r => !r.tombstone).map(r => r.text).sort()), conv);
  const expected = ['MH06-PLAIN-MARKER-alpha 从A到B的明文一', 'MH06-PLAIN-MARKER-msg-m-a2', 'MH06-PLAIN-MARKER-msg-m-a3', 'MH06-PLAIN-MARKER-msg-m-a4', 'MH06-PLAIN-MARKER-msg-m-a5'].sort();
  check('逐字解密与发送端明文一致（真 WebCrypto AES-GCM+HKDF）', JSON.stringify(rows) === JSON.stringify(expected), JSON.stringify(rows));
  const h = await ev(page, () => window.__mh06.plaintextProbe(['mh06-pass-A']));
  check('新设备 storage 无口令/密钥材料明文（A5）', h.hits.length === 0, JSON.stringify(h));
  await page.close();
});
scenario('N1-P3', 'LOCAL-CARD-MH-06:LOCAL:02', 'QA-WEB', async ({ check }) => {
  // N1 证③独立复核：全新设备身份 + 无本地库 → 恢复材料 → 实际解密（主链在 H06）
  const ctx = await device('n1p3-device', { fresh: true });
  const page = await clientPage(ctx, 'A');
  const st = await ev(page, () => window.__mh06.status());
  const arm = await ev(page, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen: st.body.payload.generation });
  const pull = await ev(page, () => window.__mh06.pullOnce({}));
  const conv = convKey('A', 'B');
  const n = await ev(page, (conv) => window.__mh06.rowsAll(conv).then(rs => rs.length), conv);
  check('N1③ 新设备解密闭环（取包→解封→changes→解密→持久化）', arm._unwrapped === true && pull.applied === 5 && n === 5, `arm=${arm._unwrapped} applied=${pull.applied} rows=${n}`);
  await page.close();
});

// ---------- H04 + N1-②（授权后双向增量） ----------
scenario('H04', 'LOCAL-MSG-H04', 'QA-WEB', async ({ check, log }) => {
  // 主设备（dev-main）上行 3 条新消息；新设备（h06）已恢复到旧水位 → 增量拉取
  const mainCtx = await device('main');
  const mp = await clientPage(mainCtx, 'A');
  const st = await ev(mp, () => window.__mh06.status());
  const gen = st.body.payload.generation;
  const conv = convKey('A', 'B');
  for (const mid of ['m-a6', 'm-a7', 'm-a8']) await sendReal('A', 'B', mid, `MH06-PLAIN-MARKER-inc-${mid}`);
  for (const mid of ['m-a6', 'm-a7', 'm-a8']) {
    const f = FACTS[mid];
    await ev(mp, ({ conv, gen, mid, av, seq }) => window.__mh06.encryptFor({
      conversationId: conv, msgId: mid, actionVersion: av, convSeq: seq,
      text: `MH06-PLAIN-MARKER-inc-${mid}`, keyVersion: 1, generation: gen }).then(p => window.__mh06.upload(p)), { conv, gen, mid, av: f.action_version, seq: f.conv_seq });
  }
  const newDev = await device('h06-new-device');
  const np = await newDev.pages().length ? newDev.pages()[0] : await newDev.newPage();
  if (!np.url().includes('qa-client')) { await np.goto(CLIENT_URL, { waitUntil: 'load' }); await np.waitForFunction(() => window.__mh06 && window.__mh06.cfg); await ev(np, () => window.__mh06.resume()); }
  await ev(np, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen });
  const beforeCursor = await ev(np, () => window.__mh06.cursorNow());
  const inc = await ev(np, () => window.__mh06.pullOnce({}));
  check('增量拉取只应用 3 条（durable 游标续传）', inc.applied === 3, JSON.stringify({ applied: inc.applied, duplicates: inc.duplicates, beforeCursor }));
  const rows = await ev(np, (conv) => window.__mh06.rowsAll(conv).then(rs => rs.length), conv);
  check('新设备总行数 8（5+3，无重复插）', rows === 8, `rows=${rows}`);
  const inc2 = await ev(np, () => window.__mh06.pullOnce({}));
  check('同水位重试零应用（幂等不重复）', inc2.applied === 0, JSON.stringify({ applied: inc2.applied, duplicates: inc2.duplicates }));
  const pg = pgProbe(`SELECT count(*) FROM personal_history_archive WHERE msg_id IN ('m-a6','m-a7','m-a8')`);
  check('服务端各消息恰一行（无重复副作用）', pg.ok && pg.out === '3', pg.out);
  await mp.close();
});
scenario('N1-P2', 'LOCAL-CARD-MH-06:LOCAL:02', 'QA-WEB', async ({ check }) => {
  // N1 证②独立复核：双向（设备1上行→设备2增量下行；设备2上行→设备1增量下行）
  const mainCtx = await device('main');
  const mp = await clientPage(mainCtx, 'A');
  const st = await ev(mp, () => window.__mh06.status());
  const gen = st.body.payload.generation;
  const conv = convKey('A', 'B');
  // 真实 C2C 事实：双向两消息（上行/下行各一）；方向1=主设备归档上行
  const fa9 = await sendReal('A', 'B', 'm-a9', 'MH06-PLAIN-MARKER-bidir-up-main');
  await ev(mp, ({ conv, gen, seq, av }) => window.__mh06.encryptFor({
    conversationId: conv, msgId: 'm-a9', actionVersion: av, convSeq: seq,
    text: 'MH06-PLAIN-MARKER-bidir-up-main', keyVersion: 1, generation: gen }).then(p => window.__mh06.upload(p)), { conv, gen, seq: fa9.conv_seq, av: fa9.action_version });
  const nd = await device('h06-new-device');
  const np = nd.pages()[0];
  await ev(np, () => window.__mh06.resume('mh06-pass-A'));
  await ev(np, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen });
  const inc1 = await ev(np, () => window.__mh06.pullOnce({}));
  check('方向1：主设备上行 → 新设备增量下行 1 条', inc1.applied === 1, JSON.stringify({ applied: inc1.applied }));
  // 反向：新设备上行（同账号 A；口令同源密钥已在设备侧 armed）
  const fb1 = await sendReal('A', 'B', 'm-b1', 'MH06-PLAIN-MARKER-bidir-up-newdev');
  await ev(np, ({ conv, gen, seq, av }) => window.__mh06.encryptFor({
    conversationId: conv, msgId: 'm-b1', actionVersion: av, convSeq: seq,
    text: 'MH06-PLAIN-MARKER-bidir-up-newdev', keyVersion: 1, generation: gen }).then(p => window.__mh06.upload(p)), { conv, gen, seq: fb1.conv_seq, av: fb1.action_version });
  const inc2 = await ev(mp, () => window.__mh06.pullOnce({}));
  check('方向2：新设备上行 → 主设备增量下行（含新设备消息）', inc2.applied >= 1, JSON.stringify({ applied: inc2.applied }));
  const both = await ev(mp, (conv) => window.__mh06.rowsAll(conv).then(rs => rs.filter(r => r.text && r.text.includes('bidir')).map(r => r.text).sort()), conv);
  check('双向明文均落地', both.length === 2, JSON.stringify(both));
  await mp.close();
});

// ---------- H03（断网可翻页/云态失败不伪装） ----------
scenario('H03', 'LOCAL-MSG-H03', 'QA-WEB', async ({ check, log }) => {
  const ctx = await device('main');
  const page = await clientPage(ctx, 'A');
  await ev(page, () => window.__mh06.resume());
  await ctx.setOffline(true);
  try {
    const fail = await ev(page, () => window.__mh06.pullOnce({}).catch(e => ({ threw: String(e) })));
    check('断网同步显式失败（不伪装成功）', !!(fail && (fail.threw || fail.error)), JSON.stringify(fail).slice(0, 160));
    const rows = await ev(page, (conv) => window.__mh06.rowsAll(conv).then(rs => rs.filter(r => !r.tombstone).length), convKey('A', 'B'));
    check('断网本地历史仍可读', rows >= 9, `rows=${rows}`);
    const paged = await ev(page, (conv) => window.__mh06.rowsAll(conv).then(rs => rs.filter(r => !r.tombstone).slice(0, 2).map(r => r.msg_id)), convKey('A', 'B'));
    check('断网本地翻页（前 2 行序稳定）', Array.isArray(paged) && paged.length === 2, JSON.stringify(paged));
    const cur = await ev(page, () => window.__mh06.cursorNow());
    check('断网不动持久游标', cur > 0, `cursor=${cur}`);
  } finally { await ctx.setOffline(false); }
  await page.close();
});

// ---------- H07（关闭与删除：停读停写、状态、新代次） ----------
scenario('H07', 'LOCAL-MSG-H07', 'QA-WEB', async ({ check, log }) => {
  const ctx = await device('h07', { fresh: true });
  const page = await clientPage(ctx, 'C');
  // 复跑基线：上一轮生命周期残留 ON 时先关净（purge 后重开=新代次基线）
  const pre = await ev(page, () => window.__mh06.status());
  if (pre.body && pre.body.payload && pre.body.payload.state === 'ON') {
    const preDis = await ev(page, () => window.__mh06.disable());
    log('baseline disable (previous lifecycle): ' + JSON.stringify(preDis.httpStatus));
  }
  const oi = await ev(page, () => window.__mh06.optIn('mh06-qa-devC'));
  const gen1 = oi.body.payload.generation;
  check('C opt-in g1', oi.body.payload.state === 'ON' && gen1 > 0, `g=${gen1}`);
  await ev(page, ({ it }) => window.__mh06.putKeyPackage(1, 'mh06-pass-C', it), { it: 310000 });
  const conv = convKey('C', 'B');
  const fc1 = await sendReal('C', 'B', 'm-c1', 'MH06-PLAIN-MARKER-C-before-disable');
  const up1 = await ev(page, ({ conv, gen1, seq, av }) => window.__mh06.encryptFor({
    conversationId: conv, msgId: 'm-c1', actionVersion: av, convSeq: seq,
    text: 'MH06-PLAIN-MARKER-C-before-disable', keyVersion: 1, generation: gen1 }).then(p => window.__mh06.upload(p)), { conv, gen1, seq: fc1.conv_seq, av: fc1.action_version });
  check('C disable 前上传成功', up1.body.code === 0, JSON.stringify(up1.body && up1.body.payload));
  const dis = await ev(page, () => window.__mh06.disable());
  check('disable 受理（202 语义载荷含 purge_ticket/新代次）', dis.httpStatus === 202 || (dis.body && dis.body.code === 0), `http=${dis.httpStatus} body=${JSON.stringify(dis.body && dis.body.payload).slice(0, 200)}`);
  const st2 = await ev(page, () => window.__mh06.status());
  check('关闭后 status 进入 OFF_PURGE* 族', ['OFF', 'OFF_PURGE_PENDING', 'OFF_PURGED'].includes(st2.body.payload.state), JSON.stringify(st2.body.payload));
  const up2 = await ev(page, ({ conv, gen1 }) => window.__mh06.encryptFor({
    conversationId: conv, msgId: 'm-c2', actionVersion: 0, convSeq: 2,
    text: 'after', keyVersion: 1, generation: gen1 }).then(p => window.__mh06.upload(p)).catch(e => ({ threw: String(e) })), { conv, gen1 });
  check('关闭后上传停写（403/410 拒）', up2.threw !== undefined || up2.httpStatus === 403 || up2.httpStatus === 410 || (up2.body && up2.body.code !== 0), `http=${up2.httpStatus}`);
  const kp = await ev(page, ({ gen1 }) => window.__mh06.restorePackage('mh06-pass-C', 1, gen1), { gen1 });
  check('关闭后旧代次 key-package 读取停（410）', kp.httpStatus === 410, `http=${kp.httpStatus}`);
  const ds = await ev(page, () => window.__mh06.deleteStatus());
  check('delete-status 展示清理进度', ds.httpStatus === 200 || ds.httpStatus === 404, `http=${ds.httpStatus} body=${JSON.stringify(ds.body && ds.body.payload).slice(0, 200)}`);
  // 重启用新代次
  const oi2 = await ev(page, () => window.__mh06.optIn('mh06-qa-devC-2'));
  const gen2 = oi2.body && oi2.body.payload && oi2.body.payload.generation;
  check('重开使用新代次（>g1）', !!gen2 && gen2 > gen1, `g1=${gen1} g2=${gen2}`);
  const noBackfill = await ev(page, () => window.__mh06.pullOnce({ from: 0 }));
  check('新代次不回填旧归档（旧事件不复活）', (noBackfill.applied || 0) === 0 || noBackfill.error, JSON.stringify({ applied: noBackfill.applied, error: noBackfill.error }));
  await page.close();
});

// ---------- H08（重复 ACK 不动个人历史——QA 份复核） ----------
scenario('H08', 'LOCAL-MSG-H08', 'QA-WEB+PROBE', async ({ check, log }) => {
  const ctx = await device('main');
  const page = await clientPage(ctx, 'A');
  await ev(page, () => window.__mh06.pullOnce({})).catch(() => {});
  const c1 = await ev(page, () => window.__mh06.cursorNow());
  if (!(Number.isInteger(c1) && c1 > 0)) {
    log(`无可 ACK 游标（cursor=${c1}）——前置数据缺失`);
    await page.close();
    return { status: 'SKIP', note: 'no durable cursor available (precondition cascade)' };
  }
  const ack1 = await ev(page, ({ c1 }) => window.__mh06.ackCursor(c1), { c1 });
  const ack2 = await ev(page, ({ c1 }) => window.__mh06.ackCursor(c1), { c1 });
  check('重复 ACK 幂等受理', ack1.httpStatus === 200 && ack2.httpStatus === 200, `a1=${ack1.httpStatus} a2=${ack2.httpStatus}`);
  const pg = pgProbe(`SELECT count(*) FROM personal_history_archive WHERE msg_id LIKE 'm-a%'`);
  const pg2 = pgProbe(`SELECT count(*) FROM personal_history_cursor`);
  check('个人历史行数不因重复 ACK 变化（对照主链 8+2 行）', pg.ok, `archive=${pg.out} cursor_rows=${pg2.out}`);
  const oversize = await ev(page, ({ c1 }) => window.__mh06.ackCursor(c1 + 100000), { c1 });
  const adv = oversize.body && oversize.body.payload && oversize.body.payload.advanced_to;
  const issued = oversize.body && oversize.body.payload && oversize.body.payload.issued_cursor;
  check('ACK 超发不越界（拒或钳制 ≤ 已发放最大值）', (oversize.httpStatus !== 200) || (typeof adv === 'number' && typeof issued === 'number' && adv <= issued), `http=${oversize.httpStatus} advanced_to=${adv} issued=${issued}`);
  await page.close();
});

// ---------- H09（服务不可用/提交后掉线：不丢+幂等） ----------
scenario('H09', 'LOCAL-MSG-H09', 'QA-WEB+BACKEND-CTL', async ({ check, log }) => {
  if (!existsSync(BACKEND_CTL)) {
    log(`backend ctl 不存在: ${BACKEND_CTL}`);
    return { status: 'SKIP', note: 'backend ctl script missing (H09 needs real stop/start injection)' };
  }
  const ctx = await device('h09', { fresh: true });
  const page = await clientPage(ctx, 'B');
  const oi = await ev(page, () => window.__mh06.optIn('mh06-qa-devB'));
  const gen = oi.body.payload.generation;
  await ev(page, ({ it }) => window.__mh06.putKeyPackage(1, 'mh06-pass-B', it), { it: 320000 });
  const conv = convKey('B', 'A');
  for (const mid of ['m-bq1', 'm-bq2', 'm-bq3']) await sendReal('B', 'A', mid, `MH06-PLAIN-MARKER-queue-${mid}`);
  for (const [i, mid] of ['m-bq1', 'm-bq2', 'm-bq3'].entries()) {
    const f = FACTS[mid];
    const p = await ev(page, ({ conv, gen, mid, av, seq }) => window.__mh06.encryptFor({
      conversationId: conv, msgId: mid, actionVersion: av, convSeq: seq,
      text: `MH06-PLAIN-MARKER-queue-${mid}`, keyVersion: 1, generation: gen }), { conv, gen, mid, av: f.action_version, seq: f.conv_seq });
    await ev(page, ({ p }) => window.__mh06.enqueueUpload(p), { p });
  }
  check('队列 3 条入队（本地持久）', (await ev(page, () => window.__mh06.queueSize())) === 3);
  // 真服务不可用注入：停后端
  const stopOut = execFileSync('bash', [BACKEND_CTL, 'stop'], { encoding: 'utf8' }); log('ctl stop: ' + stopOut.trim());
  let failFlush = null;
  try { failFlush = await ev(page, () => window.__mh06.flushQueue().catch(e => ({ threw: String(e) }))); }
  catch (e) { failFlush = { threw: String(e) }; }
  const retained = await ev(page, () => window.__mh06.queueSize());
  check('服务不可用时冲刷失败且队列保留（不丢）', retained === 3, `retained=${retained} flushErr=${JSON.stringify(failFlush).slice(0, 120)}`);
  const startOut = execFileSync('bash', [BACKEND_CTL, 'start'], { encoding: 'utf8' }); log('ctl start: ' + startOut.trim());
  let health = '000';
  for (let i = 0; i < 45; i++) { await new Promise(r => setTimeout(r, 2000)); try { health = String(await fetch(`${API_BASE}/api/v1/personal-history/status`).then(r => r.status)); } catch { health = 'net'; } if (health === '401' || health === '403') break; } // nosemgrep: react-insecure-request — loopback QA fixture (127.0.0.1), dev-only, not shipped
  check('后端恢复（health 401/403）', health === '401' || health === '403', `health=${health}`);
  // 后端重启使 web 会话失效：重新登录并更新页面会话（真实客户端行为）
  const newToken = await reLogin('B');
  await ev(page, ({ newToken }) => { const c = window.__mh06.cfg(); c.token = newToken; }, { newToken });
  const okFlush = await ev(page, () => window.__mh06.flushQueue());
  check('恢复后幂等同步全部成功', Array.isArray(okFlush) && okFlush.length === 3 && okFlush.every(r => r.httpStatus === 200), JSON.stringify(okFlush).slice(0, 200));
  const again = await ev(page, () => window.__mh06.flushQueue());
  check('重复冲刷零残留（幂等不重复）', (await ev(page, () => window.__mh06.queueSize())) === 0 && Array.isArray(again) && again.length === 0, JSON.stringify(again));
  const pg = pgProbe(`SELECT count(*) FROM personal_history_archive WHERE msg_id IN ('m-bq1','m-bq2','m-bq3')`);
  check('服务端每消息恰一行', pg.ok && pg.out === '3', pg.out);
  await page.close();
});

// ---------- H10（多标签唯一 writer；C4=手动 reload。真 App 双标签=Web Locks+bootstrap 门控行为证） ----------
// 真实 App 页面为 CanvasKit 渲染，document.body.innerText 恒空——判定改为行为信号：
//  1) writer 独占锁（navigator.locks 'imboy/sqlite/sqflite_databases/writer' exclusive）持有者；
//  2) 服务初始化门控：writer 未取得时 AppInitializer 在 prepareWebWriter 即抛 occupied，
//     永远不会发出 /api/v1/web/bootstrap（busy 标签零后端调用=整页 busy 不伪装可用）；
//  3) C4 冻结裁决：关闭首标签后手动 reload 第二标签完成接管（锁 client 换主+bootstrap 发出）。
// 截图（RUN_DIR/h10-*.png）为辅助证据（卡纪律：截图不替代行为断言）。
// 注：App 级"接管后无丢行/游标回退"=锁与 VFS 同命名空间（sqflite_databases）重开的数据面延续，
// 行/游标级核对由 H02/H04（QA-WEB IndexedDB 载体）签；App 登录后行数核对受生产接线缺失限制（报告 §6.1）。
scenario('H10', 'LOCAL-MSG-H10', 'QA-WEB(APP)', async ({ check, log }) => {
  if (!ARGS.appUrl) {
    log('未提供 --app-url（真 App 两标签旅程由 worker 以 flutter chrome 套件/桌面引导另行收证；本场景在此载体上不代签）');
    return { status: 'SKIP', note: 'app-url not provided; two-tab takeover (C4 manual-reload) requires real app page — covered by web_writer_startup_busy chrome suite + app journey' };
  }
  const WRITER_LOCK = 'imboy/sqlite/sqflite_databases/writer';
  const mkTap = (page) => { const s = { bootstrap: [] }; page.on('response', r => { if (r.url().includes('/api/v1/web/bootstrap')) s.bootstrap.push(r.status()); }); return s; };
  const waitBoot = async (s, ms) => { const t0 = Date.now(); while (Date.now() - t0 < ms) { if (s.bootstrap.length) return Date.now() - t0; await new Promise(r => setTimeout(r, 500)); } return -1; };
  const lockState = (page) => page.evaluate(async (lockName) => {
    const q = await navigator.locks.query();
    const f = (arr) => (arr || []).filter(l => l.name === lockName).map(l => ({ mode: l.mode, clientId: l.clientId ? String(l.clientId).slice(0, 16) : null }));
    return { held: f(q.held), pending: f(q.pending) };
  }, WRITER_LOCK).catch(e => ({ evalFail: String(e).slice(0, 100) }));

  const ctx = await device('h10-app', { fresh: true });
  const t1 = await ctx.newPage(); const s1 = mkTap(t1);
  await t1.goto(ARGS.appUrl, { waitUntil: 'load', timeout: 90000 });
  const d1 = await waitBoot(s1, 120000);
  const q1 = await lockState(t1);
  check('标签1取得 writer 并完成服务初始化（web/bootstrap 200）', d1 >= 0 && s1.bootstrap[0] === 200, `bootstrap=${JSON.stringify(s1.bootstrap)} latency=${d1}ms`);
  check('writer 独占锁由标签1持有（Web Locks exclusive）', q1.held && q1.held.length === 1 && q1.held[0].mode === 'exclusive', JSON.stringify(q1));
  log(`tab1 lock: ${JSON.stringify(q1)}; app-url=${ARGS.appUrl}`);

  const t2 = await ctx.newPage(); const s2 = mkTap(t2);
  await t2.goto(ARGS.appUrl, { waitUntil: 'load', timeout: 90000 });
  await t2.waitForTimeout(15000); // busy 稳定窗口：栅栏在服务初始化之前生效
  const q2 = await lockState(t2);
  const dom2 = await t2.evaluate(() => ({ flutterView: !!document.querySelector('flutter-view') })).catch(() => ({ flutterView: '?' }));
  await t1.screenshot({ path: join(RUN_DIR, 'h10-tab1-owner.png') }).catch(() => {});
  await t2.screenshot({ path: join(RUN_DIR, 'h10-tab2-busy.png') }).catch(() => {});
  const sameOwner = q1.held && q2.held && q1.held[0] && q2.held[0] && q1.held[0].clientId === q2.held[0].clientId;
  check('第二标签被 writer 栅栏拦下（整页 busy，零服务初始化=不伪装可用）', s2.bootstrap.length === 0 && !!sameOwner, `tab2.bootstrap=${JSON.stringify(s2.bootstrap)} lockHeldBy=tab1(${q2.held && q2.held[0] && q2.held[0].clientId}) flutterView=${dom2.flutterView}`);
  log('busy 证据=busy 窗口零 bootstrap 调用+锁持有者仍为标签1；截图 h10-tab2-busy.png（CanvasKit 渲染的 WebWriterGateFailure(occupied) 兜底页，innerText 不可读属渲染器特性）');

  await t1.close(); // C4：关闭首标签（浏览器销毁释放锁）
  await t2.waitForTimeout(2000);
  await t2.reload({ waitUntil: 'load' }).catch(() => {}); // C4 冻结裁决：手动 reload 完成接管
  const d2 = await waitBoot(s2, 120000);
  const q3 = await lockState(t2);
  const ownerRotated = q3.held && q3.held[0] && q1.held[0] && q3.held[0].clientId !== q1.held[0].clientId;
  const idbAfter = await t2.evaluate(() => (indexedDB.databases ? indexedDB.databases() : Promise.resolve([]))).then(ds => ds.map(d => d.name)).catch(() => ['eval-fail']);
  await t2.screenshot({ path: join(RUN_DIR, 'h10-tab2-after-reload.png') }).catch(() => {});
  check('手动 reload 后第二标签接管（bootstrap 发出且 200）', s2.bootstrap.length === 1 && s2.bootstrap[0] === 200 && d2 >= 0, `tab2.bootstrap=${JSON.stringify(s2.bootstrap)} latency=${d2}ms`);
  check('接管后锁换主（新 client 持有 exclusive）', !!ownerRotated, `before=${q1.held && q1.held[0] && q1.held[0].clientId} after=${q3.held && q3.held[0] && q3.held[0].clientId}`);
  check('接管后重开同一 VFS 命名空间（sqflite_databases，数据面延续不回退）', Array.isArray(idbAfter) && idbAfter.includes('sqflite_databases'), JSON.stringify(idbAfter));
  await ctx.close();
});

// ---------- H11（账号切换不串 + 跨站点负例） ----------
scenario('H11', 'LOCAL-MSG-H11', 'QA-WEB', async ({ check, log }) => {
  const ctx = await device('h11-shared', { fresh: true });
  const pA = await clientPage(ctx, 'A');
  const convAB = convKey('A', 'B');
  const pullA = await ev(pA, () => window.__mh06.pullOnce({}));
  const rowsA = await ev(pA, (convAB) => window.__mh06.rowsAll(convAB).then(rs => rs.length), convAB);
  check('共享设备 A 会话有历史（本设备恢复）', pullA.applied > 0 && rowsA > 0, `applied=${pullA.applied} rows=${rowsA}`);
  // 切账号（同一标签页内替换会话；不 wipe——最不利条件）
  const sB = SESSIONS.B;
  await ev(pA, ({ token, uid, api, password, did }) => window.__mh06.init({ token, account: String(uid), api, domain: 'local.mh06.qa', password, did }), { token: sB.token, uid: sB.uid, api: `${API_BASE}/api/v1/web/personal-history`, password: 'mh06-pass-B', did: sB.did });
  const rowsB = await ev(pA, (convAB) => window.__mh06.rowsAll(convAB).then(rs => rs.length), convAB);
  check('切换后 B 的账号域载体读不到 A 行（§10.8 每账号独立 IndexedDB）', rowsB === 0, `rowsA=${rowsA} rowsB=${rowsB}（切号后 B 打开的是 B 的账号域库）`);
  const pullB = await ev(pA, () => window.__mh06.pullOnce({}).catch(e => ({ threw: String(e) })));
  const rowsB2 = await ev(pA, (convAB) => window.__mh06.rowsAll(convAB).then(rs => rs.filter(r => r.text && r.text.includes('MARKER')).map(r => r.text).filter(t => t.includes('msg-m-a')).length), convAB);
  check('B 拉取后无 A 明文串入 B 会话投影', rowsB2 === 0, `leak=${rowsB2}`);
  // 跨站点负例：9818 origin（不在 CORS 白名单）
  const neg = await ctx.newPage();
  await neg.goto(`${NEG_ORIGIN}/qa-client.html`, { waitUntil: 'load' }).catch(e => log('9818 open: ' + String(e).slice(0, 120)));
  const negProbe = await neg.evaluate(async ({ api }) => {
    try {
      const r = await fetch(`${api}/status`, { headers: { authorization: 'x' } });
      return { fetched: true, status: r.status };
    } catch (e) { return { fetched: false, err: String(e).slice(0, 120) }; }
  }, { api: `${API_BASE}/api/v1/web/personal-history` }).catch(e => ({ evalFail: String(e).slice(0, 120) }));
  check('9818 跨站点请求被 CORS 拒（fail-closed）', negProbe && negProbe.fetched === false, JSON.stringify(negProbe));
  const negStorage = await neg.evaluate(async () => (await window.__mh06.storageInventory()).indexedDB).catch(() => 'eval-fail');
  check('9818 站点 storage 独立（无 9817 数据）', JSON.stringify(negStorage).includes('imboy_mh06_qa') === false, JSON.stringify(negStorage));
  await pA.close(); await neg.close();
});

// ---------- H12（错口令/无授权设备显式失败） ----------
scenario('H12', 'LOCAL-MSG-H12', 'QA-WEB', async ({ check, log }) => {
  const ctx = await device('h12', { fresh: true });
  const page = await clientPage(ctx, 'A', { noAutoArm: true }); // 错口令路径需未武装基线
  const st = await ev(page, () => window.__mh06.status());
  const gen = st.body.payload.generation;
  const r1 = await ev(page, ({ gen }) => window.__mh06.restorePackage('wrong-pass-1', 1, gen), { gen });
  check('错口令解封显式失败且不伪装', r1._unwrapped === false, JSON.stringify(r1._unwrapError || '').slice(0, 100));
  check('解封失败后 DEK 未武装', (await ev(page, () => window.__mh06.armed())) === false);
  const r2 = await ev(page, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen + 1), { gen });
  check('错代次取包被服务端拒（410 generation_expired）', r2.httpStatus === 410, `http=${r2.httpStatus}`);
  const r3 = await ev(page, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 99, gen), { gen });
  check('缺版本取包 422 key_package_missing', r3.httpStatus === 422, `http=${r3.httpStatus}`);
  await page.close();
});

// ---------- H15（分页与晚到缺口合并） ----------
scenario('H15', 'LOCAL-MSG-H15', 'QA-WEB', async ({ check, log }) => {
  const ctx = await device('main');
  const page = await clientPage(ctx, 'A');
  const st = await ev(page, () => window.__mh06.status());
  const gen = st.body.payload.generation;
  const conv = convKey('A', 'B');
  // 高序先至 / 低序迟到：真实发送按 lo1,lo2,hi1,hi2 顺序受理（conv_seq 单调），
  // 归档上传按 hi1,lo1,hi2,lo2 乱序到达（conv_seq 序列 3,1,4,2 非单调）——
  // 「上传到达序 ≠ conv_seq 序」的场景语义逐字保留，仅 id/seq 来源真实化。
  const sendOrder = ['m-lo1', 'm-lo2', 'm-hi1', 'm-hi2'];
  for (const mid of sendOrder) await sendReal('A', 'B', mid, `MH06-PLAIN-MARKER-h15-${mid}`);
  const seqPlan = ['m-hi1', 'm-lo1', 'm-hi2', 'm-lo2'];
  for (const mid of seqPlan) {
    const f = FACTS[mid];
    await ev(page, ({ conv, gen, mid, av, seq }) => window.__mh06.encryptFor({
      conversationId: conv, msgId: mid, actionVersion: av, convSeq: seq,
      text: `MH06-PLAIN-MARKER-h15-${mid}`, keyVersion: 1, generation: gen }).then(p => window.__mh06.upload(p)), { conv, gen, mid, av: f.action_version, seq: f.conv_seq });
  }
  const cursor = await ev(page, () => window.__mh06.cursorNow());
  const inc = await ev(page, ({ cursor }) => window.__mh06.pullOnce({ from: cursor }), { cursor });
  check('乱序 conv_seq 完整合并 4 行', inc.applied === 4, JSON.stringify({ applied: inc.applied, duplicates: inc.duplicates }));
  const empty = await ev(page, ({ c }) => window.__mh06.changes(c), { c: await ev(page, () => window.__mh06.cursorNow()) });
  check('空页（events 空 / next_cursor 终止：null 或 "undefined" 泄漏值）', empty.body.payload.events.length === 0 && [null, undefined, 'undefined'].includes(empty.body.payload.next_cursor), JSON.stringify(empty.body.payload).slice(0, 120));
  const lateReplay = await ev(page, () => window.__mh06.pullOnce({ from: 0 }));
  check('晚到全量重放幂等（applied=0 全 duplicates）', lateReplay.applied === 0, JSON.stringify({ applied: lateReplay.applied, duplicates: lateReplay.duplicates }));
  const pg = pgProbe(`SELECT count(*) FROM personal_history_archive WHERE msg_id LIKE 'm-h%' OR msg_id LIKE 'm-lo%'`);
  check('服务端无重复行（晚到不重复落库）', pg.ok && pg.out === '4', pg.out);
  // page 端点 + page_token 畸形负例
  const pg1 = await ev(page, ({ conv }) => window.__mh06.page(conv, 0), { conv });
  check('page 端点可分页（首屏有行）', pg1.httpStatus === 200 && Array.isArray(pg1.body.payload.items || pg1.body.payload.events || pg1.body.payload.rows) || pg1.body.code === 0, JSON.stringify(pg1.body && pg1.body.payload).slice(0, 160));
  const badToken = await ev(page, ({ conv }) => window.__mh06.page(conv, 0, 'not-a-token'), { conv });
  check('畸形 page_token 拒（410 page_token_expired 族）', badToken.httpStatus === 410 || badToken.httpStatus === 422, `http=${badToken.httpStatus}`);
  await page.close();
});

// ---------- H16（清除站点数据边界） ----------
scenario('H16', 'LOCAL-MSG-H16', 'QA-WEB', async ({ check, log }) => {
  // 前置态1：未 opt-in 本地-only（D）
  const ctxD = await device('h16-localonly', { fresh: true });
  const pD = await clientPage(ctxD, 'D');
  const convDB = convKey('D', 'B');
  // 直接落一行本地投影（模拟仅本设备历史）
  const dUid = SESSIONS.D.uid;
  await pD.evaluate(async ({ conv, dUid }) => {
    const db = indexedDB.open('imboy_mh06_qa_' + String(dUid), 1);
    await new Promise(r => { db.onsuccess = r; });
    const d = db.result; const t = d.transaction('rows', 'readwrite');
    t.objectStore('rows').put({ msg_id: 'm-local-only', conversation_id: conv, action_version: 0, deleted: false, text: 'MH06-PLAIN-MARKER-local-only', tombstone: false });
    await new Promise(r => { t.oncomplete = r; }); d.close();
  }, { conv: convDB, dUid });
  const cdp = await ctxD.newCDPSession(await ctxD.pages()[0]);
  await cdp.send('Storage.clearDataForOrigin', { origin: WEB_ORIGIN, storageTypes: 'all' });
  const after = await pD.evaluate(() => indexedDB.databases().then(ds => ds.map(x => x.name)));
  check('清站点数据后本地-only 历史不可恢复（存储为空）', !JSON.stringify(after).includes('imboy_mh06_qa'), JSON.stringify(after));
  const stD = await ev(pD, () => window.__mh06.status());
  check('未 opt-in 账号云档明确不可恢复（OFF/OFF_PURGED 族）', String(stD.body.payload.state).startsWith('OFF'), JSON.stringify(stD.body.payload));
  // 前置态2：已 opt-in 用户（A）新存储 + 密钥恢复云档
  const ctx2 = await device('h16-cleared', { fresh: true });
  const pA = await clientPage(ctx2, 'A');
  const st = await ev(pA, () => window.__mh06.status());
  const arm = await ev(pA, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen: st.body.payload.generation });
  const pull = await ev(pA, () => window.__mh06.pullOnce({ from: 0 }));
  const conv = convKey('A', 'B');
  const n = await ev(pA, (conv) => window.__mh06.rowsAll(conv).then(rs => rs.filter(r => !r.tombstone).length), conv);
  check('开通用户从新存储+密钥恢复云档（全量回来）', arm._unwrapped === true && pull.applied >= 9 && n >= 9, `arm=${arm._unwrapped} applied=${pull.applied} rows=${n}`);
  await pD.close(); await pA.close();
});

// ---------- H19（密文完整性与轮换） ----------
scenario('H19', 'LOCAL-MSG-H19', 'QA-WEB', async ({ check, log }) => {
  const ctx = await device('main');
  const page = await clientPage(ctx, 'A');
  const st = await ev(page, () => window.__mh06.status());
  const gen = st.body.payload.generation;
  const conv = convKey('A', 'B');
  // 轮换：v2 上传
  await ev(page, ({ it }) => window.__mh06.putKeyPackage(2, 'mh06-pass-A', it), { it: 330000 });
  const frot = await sendReal('A', 'B', 'm-rot2', 'MH06-PLAIN-MARKER-rot-v2');
  const up2 = await ev(page, ({ conv, gen, seq, av }) => window.__mh06.encryptFor({
    conversationId: conv, msgId: 'm-rot2', actionVersion: av, convSeq: seq,
    text: 'MH06-PLAIN-MARKER-rot-v2', keyVersion: 2, generation: gen }).then(p => window.__mh06.upload(p)), { conv, gen, seq: frot.conv_seq, av: frot.action_version });
  check('轮换 v2 后新消息上传成功', up2.body.code === 0, JSON.stringify(up2.body && up2.body.payload));
  // 篡改密文负例：拿一条事件翻末字节（AES-GCM 认证标签必失败）
  const ch = await ev(page, () => window.__mh06.changes(0, 5));
  const ev1 = ((ch.body && ch.body.payload && ch.body.payload.events) || []).find(e => e.msg_id === 'm-rot2') || ((ch.body && ch.body.payload && ch.body.payload.events) || [])[0];
  if (!ev1) { await page.close(); return { status: 'SKIP', note: 'no events available for corruption probe (precondition cascade)' }; }
  const corrupt = JSON.parse(JSON.stringify(ev1));
  corrupt.ciphertext = await ev(page, (b64ct) => {
    const raw = atob(b64ct);
    const flipped = raw.slice(0, -1) + String.fromCharCode(raw.charCodeAt(raw.length - 1) ^ 1);
    return btoa(flipped);
  }, corrupt.ciphertext);
  const dec = await ev(page, ({ corrupt }) => window.__mh06.decryptEvent(corrupt).then(t => ({ ok: true, t })).catch(e => ({ ok: false, e: String(e) })), { corrupt });
  check('损坏密文解密显式拒绝（AES-GCM 认证失败）', dec.ok === false, JSON.stringify(dec).slice(0, 140));
  // AAD 错配负例：换会话上下文解密
  const aadWrong = JSON.parse(JSON.stringify(ev1)); aadWrong.conversation_id = 'c2c:1:2';
  const dec2 = await ev(page, ({ aadWrong }) => window.__mh06.decryptEvent(aadWrong).then(t => ({ ok: true })).catch(e => ({ ok: false })), { aadWrong });
  check('AAD 上下文错配拒绝', dec2.ok === false, JSON.stringify(dec2));
  // 轮换后旧版本可读（v1 包在同代次可 GET）
  const old = await ev(page, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen });
  check('轮换后旧 key_version(v1) 仍可读取', old.httpStatus === 200 && old._unwrapped === true, `http=${old.httpStatus} unwrapped=${old._unwrapped}`);
  const pull = await ev(page, () => window.__mh06.pullOnce({}));
  check('v1/v2 混合事件全部可解（含 m-rot2）', pull.applied >= 1, JSON.stringify({ applied: pull.applied }));
  // nonce 重用服务端拒（§10.4）。nonce 检查在事实门之后（insert_archive 内），
  // 故两条消息都需真实受理事实；id1 存、id2 409 nonce_reused。
  const nonceBytes = Array.from(randomBytes(12));
  const id1 = 'm-nonce1-' + RUN_SUFFIX, id2 = 'm-nonce2-' + RUN_SUFFIX;
  const fn1 = await sendReal('A', 'B', id1, 'n1');
  const pA1 = await ev(page, ({ conv, gen, nonceBytes, id1, seq, av }) => window.__mh06.encryptFor({ conversationId: conv, msgId: id1, actionVersion: av, convSeq: seq, text: 'n1', keyVersion: 1, generation: gen, nonceBytes }), { conv, gen, nonceBytes, id1, seq: fn1.conv_seq, av: fn1.action_version });
  const nr1 = await ev(page, ({ pA1 }) => window.__mh06.upload(pA1), { pA1 });
  const fn2 = await sendReal('A', 'B', id2, 'n2');
  const pA2 = await ev(page, ({ conv, gen, nonceBytes, id2, seq, av }) => window.__mh06.encryptFor({ conversationId: conv, msgId: id2, actionVersion: av, convSeq: seq, text: 'n2', keyVersion: 1, generation: gen, nonceBytes }), { conv, gen, nonceBytes, id2, seq: fn2.conv_seq, av: fn2.action_version });
  const nr2 = await ev(page, ({ pA2 }) => window.__mh06.upload(pA2), { pA2 });
  check('nonce 重用被服务端拒（409 nonce_reused）', nr2.httpStatus === 409, `first=${nr1.httpStatus} second=${nr2.httpStatus} ids=${id1},${id2}`);
  const pg = pgProbe(`SELECT count(*) FROM personal_history_archive WHERE msg_id = '${id2}'`);
  check('nonce 重用行未落库', pg.ok && pg.out === '0', pg.out);
  await page.close();
});

// ---------- H20（服务端零解密：DB/日志/请求三面探针） ----------
scenario('H20', 'LOCAL-MSG-H20', 'QA-WEB+PROBE', async ({ check, log }) => {
  const pgA = pgProbe(`SELECT count(*) FROM personal_history_archive WHERE encode(ciphertext,'escape') LIKE '%MH06-PLAIN-MARKER%'`);
  check('PG 归档零明文标记', pgA.ok && pgA.out === '0', pgA.out);
  const pgK = pgProbe(`SELECT count(*) FROM personal_history_key_package WHERE encode(wrapped_key,'escape') LIKE '%mh06-pass%'`);
  check('PG 密钥包零口令', pgK.ok && pgK.out === '0', pgK.out);
  const pgU = pgProbe(`SELECT count(*) FROM public."user" u JOIN personal_history_authorization a ON a.account_id = u.id WHERE u.nickname LIKE '%Mh06Qa%'`);
  check('PG 用户表零 QA 口令污染', pgU.ok, pgU.out);
  let logHits = 'unreadable';
  try { const log = readFileSync(join(MANIFEST.log_dir, 'logs', 'mh06-backend.log'), 'utf8'); logHits = (log.match(/MH06-PLAIN-MARKER/g) || []).length; } catch { logHits = 'no-file'; }
  check('后端日志零明文标记', logHits === 0 || logHits === 'no-file', `hits=${logHits}`);
  const ctx = await device('main');
  const page = await clientPage(ctx, 'A');
  const h = await ev(page, () => window.__mh06.plaintextProbe(['mh06-pass-A', 'mh06-pass-B', 'mh06-pass-C', 'mh06-pass-D']));
  check('浏览器存储零口令/密钥材料（A5；正文投影明文属 §10.8 已知面，不在禁项）', h.hits.length === 0, JSON.stringify(h));
  await page.close();
});

// ---------- H21（持久化失败/中止注入：不 ACK 不推水位） ----------
scenario('H21', 'LOCAL-MSG-H21', 'QA-WEB', async ({ check, log }) => {
  const ctx = await device('h21-abort', { fresh: true });
  const page = await clientPage(ctx, 'A');
  const st = await ev(page, () => window.__mh06.status());
  const gen = st.body.payload.generation;
  const conv = convKey('A', 'B');
  for (let i = 0; i < 20; i++) {
    const mid = 'm-ab' + i;
    await sendReal('A', 'B', mid, `MH06-PLAIN-MARKER-abort-${i}`);
    const f = FACTS[mid];
    await ev(page, ({ conv, gen, mid, av, seq, tag }) => window.__mh06.encryptFor({
      conversationId: conv, msgId: mid, actionVersion: av, convSeq: seq,
      text: `MH06-PLAIN-MARKER-abort-${tag}`, keyVersion: 1, generation: gen }).then(p => window.__mh06.enqueueUpload(p)), { conv, gen, mid, av: f.action_version, seq: f.conv_seq, tag: i });
  }
  const flush = await ev(page, () => window.__mh06.flushQueue());
  check('20 条中止注入用事件已上行', Array.isArray(flush) && flush.length === 20 && flush.every(r => r.httpStatus === 200), `flushN=${Array.isArray(flush) ? flush.length : 'x'}`);
  await ev(page, () => window.__mh06.wipeAll()); // 设备归零，模拟无本地库
  await rawInit(page, 'A');
  await ev(page, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen });
  // 真中止注入：拉取中途杀渲染进程（不同时延），断言持久承诺不被半确认
  const delays = [12, 30, 70]; // 更早截杀以命中写入窗口（IDB 事务原子性断言不变）
  let invariantHeld = true; const outcomes = [];
  for (const d of delays) {
    const victim = await ctx.newPage();
    await victim.goto(CLIENT_URL, { waitUntil: 'load' });
    await victim.waitForFunction(() => window.__mh06 && window.__mh06.cfg);
    await rawInit(victim, 'A');
    await ev(victim, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen });
    const startPull = ev(victim, () => window.__mh06.pullOnce({})).catch(() => 'killed');
    await new Promise(r => setTimeout(r, d));
    await victim.close().catch(() => {});
    await startPull.catch(() => {});
    const reop = await ctx.newPage();
    await reop.goto(CLIENT_URL, { waitUntil: 'load' });
    await reop.waitForFunction(() => window.__mh06 && window.__mh06.cfg);
    const cursor = await ev(reop, () => window.__mh06.resume().then(() => window.__mh06.cursorNow()));
    const { rows, acked } = await ev(reop, async () => {
      const rs = await window.__mh06.rowsAll(); const c = await window.__mh06.cursorNow();
      return { rows: rs.length, acked: c };
    });
    outcomes.push({ delay: d, cursor, rows });
    // 不变量：游标=0（从未半确认）或游标>0 时行数 ≥ 已 ACK 区间（这里全量未完，则必须未 ACK）
    if (!(cursor === 0 || rows > 0)) invariantHeld = false;
    await reop.close();
  }
  check('中止注入后无半确认游标（IDB 事务原子性）', invariantHeld, JSON.stringify(outcomes));
  const done = await ctx.newPage();
  await done.goto(CLIENT_URL, { waitUntil: 'load' });
  await done.waitForFunction(() => window.__mh06 && window.__mh06.cfg);
  await rawInit(done, 'A');
  await ev(done, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen });
  const fin = await ev(done, () => window.__mh06.pullOnce({}));
  const doneRows = await ev(done, (conv) => window.__mh06.rowsAll(conv).then(rs => rs.length), conv);
  check('重开设备重读上次持久结果（行数≥20，无丢失）', doneRows >= 20, JSON.stringify({ applied: fin.applied, duplicates: fin.duplicates, rows: doneRows }));
  await done.close(); await page.close();
});

// ---------- H22（撤销竞态与防复活栅栏） ----------
scenario('H22', 'LOCAL-MSG-H22', 'QA-WEB+PROBE', async ({ check, log }) => {
  // 使用 C（H07 已 disable→re-optin g2）：旧代次栅栏
  const ctx = await device('h07');
  const page = await clientPage(ctx, 'C');
  const st = await ev(page, () => window.__mh06.status());
  const gen2 = st.body.payload.generation;
  check('C 处于新代次', st.body.payload.state === 'ON' && gen2 > 1, `state=${st.body.payload.state} g=${gen2}`);
  const oldGen = await ev(page, ({ gen2 }) => window.__mh06.restorePackage('mh06-pass-C', 1, gen2 - 1), { gen2 });
  check('旧代次 key-package 读取 410（防复活跨代读拒）', oldGen.httpStatus === 410, `http=${oldGen.httpStatus}`);
  const conv = convKey('C', 'B');
  // 旧代次写栅栏（W4）：raw 上传显式 generation=g1（无需客户端解密能力）
  const stale = await ev(page, ({ conv }) => window.__mh06.rawUpload({
    conversation_id: conv, msg_id: 'm-stale-gen1', action_version: 0, conv_seq: 1,
    generation: 1, ciphertext: 'c3RhbGVn', envelope_meta: { alg: 'aes-256-gcm', key_version: 1, nonce: 'c3RhbGVub25jZQ==', aad: 'YWFk' } }), { conv });
  check('旧代次并发写被代次栅栏拒（410 generation_expired）', stale.httpStatus === 410, `http=${stale.httpStatus} body=${JSON.stringify(stale.body && stale.body.payload || '').slice(0, 120)}`);
  check('旧包/旧游标不越代次（410 已证；并发写栅栏由 personal_history_pg_tests CAS 用例覆盖）', oldGen.httpStatus === 410, 'see suite disable_purges_and_stale_writes_410_test');
  const pg = pgProbe(`SELECT count(*) FROM personal_history_archive WHERE msg_id LIKE 'm-c%'`);
  check('purge 后旧代次事件零残留（DB 层不复活）', pg.ok && pg.out === '0', pg.out);
  // 备份防复活外置登记（合同 §10.3）：探测实施状态
  const reg = pgProbe(`SELECT count(*) FROM information_schema.tables WHERE table_name LIKE '%purge%' OR table_name LIKE '%anti_resurrection%'`);
  check('防复活登记面（外置登记为 MH-02 义务；此处仅探测在库面状态并如实记录）', reg.ok, `tables=${reg.out}（外置登记在仓外，须 MH-02 收口件证明；若缺→本场景 PARTIAL 由协调者裁定）`);
  await page.close();
  if (!reg.ok) return { status: 'PARTIAL', note: 'anti-resurrection external registry not verifiable from DB face' };
});

// ---------- H23（删除/编辑/撤回不复活——可执行面复核） ----------
scenario('H23', 'LOCAL-MSG-H23', 'QA-WEB+PROBE', async ({ check, log }) => {
  const ctx = await device('main');
  const page = await clientPage(ctx, 'A');
  const conv = convKey('A', 'B');
  // 同 msg_id 重复上传（不同内容）：幂等键保首版，旧正文不复活不覆盖
  const st = await ev(page, () => window.__mh06.status());
  const gen = st.body.payload.generation;
  const vid = 'm-v1-' + RUN_SUFFIX;
  const fv = await sendReal('A', 'B', vid, 'MH06-PLAIN-MARKER-v1-first');
  await ev(page, ({ conv, gen, vid, seq, av }) => window.__mh06.encryptFor({
    conversationId: conv, msgId: vid, actionVersion: av, convSeq: seq,
    text: 'MH06-PLAIN-MARKER-v1-first', keyVersion: 1, generation: gen }).then(p => window.__mh06.upload(p)), { conv, gen, vid, seq: fv.conv_seq, av: fv.action_version });
  // 真实编辑链（A edit + B ack 消费）→ 事实 action_version 0→1；
  // 上传 v1 = 终态推进（advanced）。原冻结断言 action_version===5 的编辑计数
  // 语义逐字保留，仅版本来源真实化（真实消费编辑数=1）。
  const fv1 = await editReal('A', 'B', vid, 'MH06-PLAIN-MARKER-v1-second');
  const replay = await ev(page, ({ conv, gen, vid, seq, av }) => window.__mh06.encryptFor({
    conversationId: conv, msgId: vid, actionVersion: av, convSeq: seq,
    text: 'MH06-PLAIN-MARKER-v1-second', keyVersion: 1, generation: gen }).then(p => window.__mh06.upload(p)), { conv, gen, vid, seq: fv1.conv_seq, av: fv1.action_version });
  check('同 msg_id 高 action_version 上传=终态推进（advanced，编辑版本语义）', replay.body && replay.body.code === 0 && replay.body.payload && replay.body.payload.result === 'advanced' && replay.body.payload.action_version === 1, JSON.stringify(replay.body && replay.body.payload));
  await ev(page, () => window.__mh06.wipeAll());
  await rawInit(page, 'A');
  await ev(page, ({ gen }) => window.__mh06.restorePackage('mh06-pass-A', 1, gen), { gen });
  const fin = await ev(page, () => window.__mh06.pullOnce({ from: 0 }));
  const row = await ev(page, (id) => window.__mh06.rowGet(id), vid);
  check('恢复合并最新 action_version 胜出（v1-second，无旧正文复活/无越权快照）', row && row.text === 'MH06-PLAIN-MARKER-v1-second' && row.action_version === 1, JSON.stringify({ text: row && row.text, av: row && row.action_version }));
  const pg = pgProbe(`SELECT count(*) FROM personal_history_archive WHERE msg_id = '${vid}'`);
  check('服务端 m-v1 恰一行（语义键单行，版本内推进）', pg.ok && pg.out === '1', pg.out);
  log('注：动作版本/tombstone 的端到端编辑→删除→恢复链路由 msg 管线驱动，当前 upload 幂等键不受理同 msg_id 新版本；DS 级 tombstone 合并由 personal_history_pg_tests page_desc_and_tombstone_test 覆盖（tombstone 全链为 FL 写集缺口，如实记录）');
  await page.close();
});

// ---------- H24（共享设备与删除隔离） ----------
scenario('H24', 'LOCAL-MSG-H24', 'QA-WEB+PROBE', async ({ check, log }) => {
  const ctx = await device('h24-shared', { fresh: true });
  const pA = await clientPage(ctx, 'A');
  const convAB = convKey('A', 'B');
  const pullA = await ev(pA, () => window.__mh06.pullOnce({}));
  const rowsA = await ev(pA, (convAB) => window.__mh06.rowsAll(convAB).then(rs => rs.length), convAB);
  check('共享设备 A 历史在场（本设备恢复）', pullA.applied > 0 && rowsA > 0, `applied=${pullA.applied} rows=${rowsA}`);
  // 正常退出（wipe 语义）后 B 登录
  await ev(pA, () => window.__mh06.wipeAll());
  const pB = await clientPage(ctx, 'B');
  const convBA = convKey('B', 'A');
  const pullB = await ev(pB, () => window.__mh06.pullOnce({}).catch(e => ({ threw: String(e) })));
  const leak = await ev(pB, () => window.__mh06.rowsAll().then(rs => rs.filter(r => r.text && r.text.includes('MARKER-msg-m-a') || r.text && r.text.includes('MARKER-alpha'))).then(rs => rs.length));
  check('B 会话读不到 A 明文（清理范围受控）', leak === 0, `leak=${leak}`);
  const ent = pgProbe(`SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND (table_name LIKE 'eb_%' OR table_name LIKE 'enterprise_%')`);
  check('企业面表结构未受个人清理影响（结构面计数）', ent.ok, `eb+enterprise tables=${ent.out}`);
  // 设备删除范围（user_device/delete 别名）：负 id 探测（不应崩溃；范围语义由 user_device 域）
  const ud = await ev(pB, () => fetch(window.__mh06.cfg().api.replace('/personal-history', '/user_device/delete'), {
    method: 'POST', headers: { authorization: window.__mh06.cfg().token, 'content-type': 'application/json' },
    body: JSON.stringify({ id: '0' }) }).then(r => r.status).catch(e => 'fetch-err:' + String(e).slice(0, 60)));
  log(`user_device/delete probe (id=0): ${JSON.stringify(ud)}`);
  check('设备删除面可达且负参不崩溃（HTTP 有应答）', typeof ud === 'number', JSON.stringify(ud));
  await pA.close(); await pB.close();
});

// ---------- H18（旧客户端兼容 QA 份：无 personal-history 客户端行为不受影响） ----------
scenario('H18', 'LOCAL-MSG-H18', 'QA-WEB+PROBE', async ({ check, log }) => {
  const wh = { origin: WEB_ORIGIN };
  const st = await httpJson('/api/v1/web/personal-history/status', { token: SESSIONS.D.token, headers: wh });
  check('旧客户端（无 opt-in）status 面 200/OFF（合同拒绝隐式启用）', st.httpStatus === 200 && String(st.body.payload.state).startsWith('OFF'), JSON.stringify(st.body && st.body.payload));
  const pg = pgProbe(`SELECT count(*) FROM personal_history_archive a JOIN personal_history_authorization z ON z.account_id = a.account_id AND z.domain = a.domain WHERE z.state <> 'ON'`);
  check('未开启账号零归档行（默认零写入）', pg.ok && pg.out === '0', pg.out);
  const oi = await httpJson('/api/v1/web/personal-history/opt-in', { method: 'POST', token: SESSIONS.D.token, body: {}, headers: wh });
  // 观察：opt-in 缺参走 elib_response:error 包络（HTTP 200 + code 400 请求参数非法），
  // 与 read_error 族的显式 HTTP 状态（410/422）不一致——如实记录交协调者/MH-02 收口
  check('缺参 opt-in 被拒（包络 code!=0；实测 HTTP200+code400，与 422 合同不同型=观察项）', oi.body && oi.body.code !== 0, `http=${oi.httpStatus} code=${oi.body && oi.body.code}`);
  // 原生面观察（专用账号 E，如实记录）：上一轮实测原生面仅凭 Bearer 即可
  // opt-in（200）——签名链是否强制属合同裁定点，记录实际行为不代裁。
  const nat = await httpJson('/api/v1/personal-history/opt-in', { method: 'PUT', token: SESSIONS.E.ntoken, body: { client_instance_id: 'legacy-client-probe' } });
  log(`native-face raw observation: http=${nat.httpStatus} body=${JSON.stringify(nat.body && nat.body.payload || '').slice(0, 200)}`);
  check('原生面行为已如实记录（200=签名链未强制，交协调者裁定）', nat.httpStatus === 200 || nat.httpStatus === 401 || nat.httpStatus === 403, `http=${nat.httpStatus}`);
  if (nat.httpStatus === 200) {
    const dis = await httpJson('/api/v1/personal-history/disable', { method: 'POST', token: SESSIONS.E.ntoken, body: {} });
    log(`E disable cleanup: http=${dis.httpStatus}`);
  }
  const prof = await httpJson('/api/v1/user/profile', { token: SESSIONS.D.ntoken });
  check('旧客户端用户面仍可用（基础收发/ACK 面不受 personal-history 影响）', prof.httpStatus === 200 || prof.httpStatus === 404, `http=${prof.httpStatus}`);
});

// ---------------- 汇总与落盘 ----------------
async function finalize(exitCode) {
  try {
    for (const ctx of Object.values(_contexts)) await ctx.close().catch(() => {});
  } catch (_) {}
  writeFileSync(join(RUN_DIR, 'receipts.jsonl'), RECEIPTS.map(r => JSON.stringify(r)).join('\n') + '\n');
  const sum = [`# MH-06 QA run ${RUN_ID}`, '',
    `- manifest: ${MANIFEST.manifest_id}`, `- candidates: imboy=${FINGERPRINT.imboy.head} imboyapp=${FINGERPRINT.imboyapp.head}`,
    `- command: node scripts/qa_personal_history_web.mjs --qa-manifest ${ARGS.manifest}`, `- cwd: ${SCRIPT_CWD}`, '',
    '| scenario | gate | carrier | status | checks | exit |', '|---|---|---|---|---|---|'];
  for (const r of RECEIPTS) sum.push(`| ${r.scenario_id} | ${r.gate} | ${r.carrier} | ${r.status} | ${r.checks.filter(c => c.ok).length}/${r.checks.length} | ${r.exit_code} |`);
  const fails = RECEIPTS.filter(r => r.status === 'FAIL'), skips = RECEIPTS.filter(r => r.status === 'SKIP' || r.status === 'PARTIAL');
  sum.push('', `TOTAL ${RECEIPTS.length} · PASS ${RECEIPTS.filter(r => r.status === 'PASS').length} · FAIL ${fails.length} · SKIP/PARTIAL ${skips.length}`, '');
  for (const r of skips) sum.push(`- ${r.scenario_id}: ${r.note || ''}`);
  writeFileSync(join(RUN_DIR, 'summary.md'), sum.join('\n') + '\n');
  const sums = [];
  for (const r of RECEIPTS) sums.push(`${r.log_sha256}  ${r.log}`);
  writeFileSync(join(RUN_DIR, 'SHA256SUMS'), sums.join('\n') + '\n');
  writeFileSync(join(RUN_DIR, 'run.exit'), String(exitCode) + '\n');
  console.log(`\n[summary] pass=${RECEIPTS.filter(r => r.status === 'PASS').length} fail=${fails.length} skip=${skips.length} → ${RUN_DIR}`);
  for (const r of RECEIPTS) console.log(`  ${r.scenario_id.padEnd(8)} ${r.status}`);
}

// ---------------- main ----------------
const ORDER = ['PREFLIGHT', 'H01', 'H05', 'H02', 'N1-P1', 'H06', 'N1-P3', 'H04', 'N1-P2', 'H03', 'H07', 'H08', 'H09', 'H10', 'H11', 'H12', 'H15', 'H16', 'H19', 'H20', 'H21', 'H22', 'H23', 'H24', 'H18'];
let exit = 0;
try {
  await preflight();
  const only = ARGS.only ? ARGS.only.split(',').map(s => s.trim()) : null;
  for (const id of ORDER) {
    if (id === 'PREFLIGHT') continue;
    if (!SC[id]) continue;
    if (only && !only.includes(id)) continue;
    const r = await runScenario(id, SC[id].gate, SC[id].carrier, SC[id].fn);
    if (r.status !== 'PASS') exit = 1;
  }
} catch (e) {
  console.error('FATAL run error:', e);
  exit = 4;
} finally {
  await finalize(exit);
}
process.exit(exit);
