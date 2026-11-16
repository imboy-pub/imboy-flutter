// Explicitly prepared, isolated loopback fixture; never a product server.
const http = require('node:http');
const crypto = require('node:crypto');
const records = new Map();
const port = Number(process.env.IMBOY_CONTROL_FETCH_PORT || '0');
if (!Number.isInteger(port) || port < 0 || port > 65535) throw Error('invalid fixture port');

function offlinePage() {
  const rows = Array.from({length: 1000}, (_, i) => {
    const mid = '0000000000000000' + (i + 1).toString(32).padStart(3, '0') + '0';
    const id = 9007199254740993n + BigInt(i) * 2n;
    const content = JSON.stringify(`synthetic-${i}:` + 'x'.repeat(1400));
    return `{"id":"${mid}","from":"9007199254740993","to":"910000000001",` +
      `"action":"channel_message","msg_type":"text","created_at":${1750000000000 + i},` +
      `"payload":{"id":${id},"channel_id":9007199254740995,"author_id":9007199254740997,"content":${content}}}`;
  });
  const empty = {has_more: false, next_last_msg_at: 0, total: 0, list: []};
  return '{"code":0,"msg":"success.","payload":{' +
    `"c2c":${JSON.stringify(empty)},"c2g":${JSON.stringify({...empty, next_cursor: ''})},` +
    '"s2c":{"has_more":false,"next_last_msg_at":1750000000999,"total":1000,"list":[' + rows.join(',') + ']}}}';
}

function arrive(req, target) {
  const id = target.searchParams.get('case') || '';
  const row = {method: req.method, path: target.pathname, size: 0,
    complete: false, aborted: false, closed: false, rejected: false,
    error: false, overLimit: false, sha256: null,
    cookie: Boolean(req.headers.cookie), authorization: Boolean(req.headers.authorization),
    authorizationSha256: crypto.createHash('sha256').update(req.headers.authorization || '').digest('hex'),
    businessHeaders: Object.keys(req.headers).some(name =>
      ['authorization', 'imboy-refreshtoken', 'cos', 'vsn', 'pkg', 'did',
        'tz_offset', 'method', 'sk', 'sign', 'device-type', 'device-type-vsn'].includes(name))};
  // An arrival remains visible even if its body never completes or is rejected.
  records.set(id, [...(records.get(id) || []), row]);
  req.on('aborted', () => { row.aborted = true; });
  req.on('error', () => { row.error = true; if (!row.complete) row.aborted = true; });
  req.on('close', () => { row.closed = true; if (!row.complete) row.aborted = true; });
  return row;
}

const server = http.createServer((req, res) => {
  let target;
  try { target = new URL(req.url, 'http://127.0.0.1'); }
  catch { res.writeHead(400).end(); return; }
  const api = target.pathname.startsWith('/api/v1/');
  // OPTIONS is CORS negotiation, not the actual API request counted by /stats.
  const resource = target.pathname.startsWith('/resource/');
  const row = (api || resource) && req.method !== 'OPTIONS' ? arrive(req, target) : null;
  const origin = req.headers.origin;
  if (origin) {
    let source;
    try { source = new URL(origin); }
    catch { if (row) row.rejected = true; res.writeHead(403).end(); return; }
    if (source.protocol !== 'http:' || !['127.0.0.1', 'localhost'].includes(source.hostname)) {
      if (row) row.rejected = true;
      res.writeHead(403).end(); return;
    }
    res.setHeader('Access-Control-Allow-Origin', source.origin);
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    res.setHeader('Access-Control-Allow-Methods', 'GET,HEAD,POST,PUT,PATCH,DELETE,OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', req.headers['access-control-request-headers'] || 'content-type,authorization');
    res.setHeader('Access-Control-Expose-Headers', 'content-type,x-control-fixture');
  }
  if (req.method === 'OPTIONS') { res.writeHead(204).end(); return; }
  const id = target.searchParams.get('case') || '';
  res.setHeader('Content-Type', 'application/json');
  if (target.pathname === '/stats') {
    res.end(JSON.stringify(records.get(id) || [])); return;
  }
  if (resource) {
    row.complete = true;
    row.sha256 = crypto.createHash('sha256').update('').digest('hex');
    if (target.pathname === '/resource/redirect307' || target.pathname === '/resource/redirect308') {
      row.responseStatus = Number(target.pathname.slice(-3));
      res.writeHead(row.responseStatus, {
        Location: '/resource/data?case=' + encodeURIComponent(id + '-redirect-target')
      }).end();
      return;
    }
    if (target.pathname === '/resource/over-budget') {
      res.setHeader('Content-Length', 100 * 1024 * 1024 + 1);
      res.end(Buffer.from([1]));
      return;
    }
    const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4zwAE/wEHAAH/4iOeWQAAAABJRU5ErkJggg==', 'base64');
    const body = target.pathname === '/resource/image' ? png
      : target.pathname === '/resource/broken-image' ? Buffer.from([137, 80, 78, 71])
      : Buffer.from([0, 127, 255]);
    res.setHeader('Content-Type', target.pathname === '/resource/image' ? 'image/png' : 'application/octet-stream');
    res.setHeader('Content-Length', body.length);
    if (target.pathname === '/resource/slow') {
      res.write(body.subarray(0, 1));
      setTimeout(() => { if (!res.destroyed) res.end(body.subarray(1)); }, 500);
      return;
    }
    res.end(body);
    return;
  }
  if (!api) { res.writeHead(404).end('{}'); return; }
  const hash = crypto.createHash('sha256');
  req.on('data', chunk => {
    row.size += chunk.length;
    if (row.size > 25 * 1024 * 1024) {
      row.overLimit = true; row.aborted = true; req.destroy(); return;
    }
    hash.update(chunk);
  });
  req.on('end', () => {
    row.complete = true;
    row.sha256 = hash.digest('hex');
    if (req.method === 'GET' && target.pathname === '/api/v1/web/msg/result' && ['result-large-peer', ''].includes(id)) {
      res.end('{"code":0,"payload":{"message_id":"synthetic-id","chat_type":"c2g","peer_id":123456837222926336,"state":"committed"}}');
      return;
    }
    if (req.method === 'GET' && ['/api/v1/msg/offline', '/api/v1/web/msg/offline'].includes(target.pathname)) {
      const body = offlinePage();
      row.response_bytes = Buffer.byteLength(body, 'utf8');
      row.response_items = 1000;
      res.setHeader('Content-Length', row.response_bytes);
      res.end(body);
      return;
    }
    // Raw literal exercises the existing large-ID decoder, not JS JSON numbers.
    const reply = () => {
      if (res.destroyed || res.writableEnded) return;
      res.setHeader('x-control-fixture', 'synthetic');
      res.end('{"code":0,"payload":{"id":9007199254740993,"accepted":true}}');
    };
    if (target.pathname === '/api/v1/slow') setTimeout(reply, 1000);
    else reply();
  });
});
server.listen(port, '127.0.0.1', () => {
  process.stdout.write(JSON.stringify({ready: true, origin: `http://127.0.0.1:${server.address().port}`}) + '\n');
});
