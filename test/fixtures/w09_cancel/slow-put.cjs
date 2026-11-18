'use strict';
// Dedicated, synthetic loopback fixture. Never connects to Garage or shared DB.
const http = require('node:http');
const {randomBytes} = require('node:crypto');
const nonce = randomBytes(32).toString('hex');
const cases = new Map();
const server = http.createServer((req, res) => {
  const origin = req.headers.origin || '';
  if (/^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Methods', 'GET, PUT, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'content-type, x-amz-checksum-sha256');
  }
  const url = new URL(req.url, 'http://localhost');
  if (url.searchParams.getAll('nonce').length !== 1 || url.searchParams.get('nonce') !== nonce) {
    res.writeHead(403).end(); return;
  }
  if (req.method === 'OPTIONS') { res.writeHead(204).end(); return; }
  if (url.pathname === '/identity' && req.method === 'GET') {
    res.writeHead(200, {'Content-Type': 'application/json'}).end(JSON.stringify({fixture: 'w09-slow-put-v1', nonce}));
    return;
  }
  const id = url.searchParams.get('case');
  if (!id || !/^[a-f0-9]{32}$/.test(id)) { res.writeHead(400).end(); return; }
  if (url.pathname === '/put' && req.method === 'PUT') {
    if (cases.has(id)) { cases.get(id).puts++; res.writeHead(409).end(); return; }
    const state = { arrived: true, bodyEnded: false, closedBeforeResponse: false, responses: 0, puts: 1, response: res };
    cases.set(id, state);
    req.on('data', () => {});
    req.on('end', () => { state.bodyEnded = true; });
    res.on('close', () => { if (!res.writableFinished) state.closedBeforeResponse = true; });
    return;
  }
  const state = cases.get(id);
  if (url.pathname === '/events' && req.method === 'GET') {
    const snapshot = state ? { arrived: state.arrived, bodyEnded: state.bodyEnded, closedBeforeResponse: state.closedBeforeResponse, responses: state.responses, puts: state.puts } : { arrived: false, puts: 0 };
    res.writeHead(200, {'Content-Type': 'application/json'}).end(JSON.stringify(snapshot));
    return;
  }
  if (url.pathname === '/release' && req.method === 'POST' && state) {
    if (!state.response.destroyed && !state.response.writableEnded) {
      state.responses++;
      state.response.writeHead(200).end();
    }
    res.writeHead(204).end(); return;
  }
  res.writeHead(404).end();
});
server.listen(0, '127.0.0.1', () => console.log(JSON.stringify({ origin: `http://127.0.0.1:${server.address().port}`, nonce })));
