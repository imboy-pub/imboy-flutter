'use strict';
const {spawn} = require('node:child_process');
const http = require('node:http');
const assert = require('node:assert/strict');
const {randomBytes} = require('node:crypto');
const {EventEmitter} = require('node:events');
const server = spawn(process.execPath, [require.resolve('./slow-put.cjs')], {stdio: ['ignore', 'pipe', 'inherit']});
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(fn) {
  for (let i = 0; i < 100; i++) { const result = await fn(); if (result) return result; await wait(20); }
  throw new Error('fixture wait timed out');
}
function terminationSignal(child) {
  return new Promise(resolve => {
    let done = false;
    function finish() { if (!done) { done = true; resolve(); } }
    child.once('error', finish);
    child.once('close', finish);
  });
}
async function terminate(child, terminal, timeoutMs = 3000) {
  child.kill('SIGTERM');
  if (await Promise.race([terminal.then(() => true), wait(timeoutMs).then(() => false)])) return true;
  child.kill('SIGKILL');
  return Promise.race([terminal.then(() => true), wait(timeoutMs).then(() => false)]);
}
const exited = terminationSignal(server);
async function startup() {
  return new Promise((resolve, reject) => {
    let buffer = '';
    const timeout = setTimeout(() => finish(new Error('fixture startup timed out')), 3000);
    function finish(error, value) {
      clearTimeout(timeout);
      server.stdout.off('data', onData);
      server.off('error', onError);
      server.off('exit', onExit);
      if (error) reject(error); else resolve(value);
    }
    function onError() { finish(new Error('fixture startup failed')); }
    function onExit() { finish(new Error('fixture exited before startup')); }
    function onData(chunk) {
      buffer += chunk.toString();
      if (buffer.length > 4096) { finish(new Error('fixture startup response too large')); return; }
      const index = buffer.indexOf('\n');
      if (index < 0) return;
      try { finish(null, JSON.parse(buffer.slice(0, index))); }
      catch (_) { finish(new Error('fixture startup response invalid')); }
    }
    server.stdout.on('data', onData);
    server.once('error', onError);
    server.once('exit', onExit);
  });
}
(async () => {
  // A failed spawn emits error/close, not necessarily exit.
  const failed = spawn('/nonexistent/w09-fixture-command', [], {stdio: 'ignore'});
  const failedTerminal = terminationSignal(failed);
  assert.equal(await Promise.race([failedTerminal.then(() => true), wait(1000).then(() => false)]), true);
  assert.equal(await terminate(failed, failedTerminal, 20), true);
  // Even a defective process abstraction that emits nothing must not hang cleanup.
  const stuck = new EventEmitter();
  const signals = [];
  stuck.kill = signal => signals.push(signal);
  assert.equal(await terminate(stuck, terminationSignal(stuck), 20), false);
  assert.deepEqual(signals, ['SIGTERM', 'SIGKILL']);
  const {origin, nonce} = await startup();
  const id = randomBytes(16).toString('hex');
  assert.match(nonce, /^[a-f0-9]{64}$/);
  for (const [path, method] of [['identity', 'GET'], ['put', 'PUT'], ['events', 'GET'], ['release', 'POST'], ['put', 'OPTIONS']]) {
    for (const supplied of ['', 'wrong']) {
      const result = await fetch(`${origin}/${path}?case=${id}&nonce=${supplied}`, {method});
      assert.equal(result.status, 403, `${method} ${path} rejects invalid nonce`);
    }
  }
  const identityResponse = await fetch(`${origin}/identity?nonce=${nonce}`, {headers: {Origin: 'http://127.0.0.1:12345'}});
  assert.equal(identityResponse.status, 200);
  assert.equal(identityResponse.headers.get('access-control-allow-origin'), 'http://127.0.0.1:12345');
  const identity = await identityResponse.json();
  assert.equal(identity.fixture, 'w09-slow-put-v1');
  assert.ok(identity.nonce === nonce, 'fixture identity nonce mismatch');
  const query = `case=${id}&nonce=${nonce}`;
  const event = async () => (await fetch(`${origin}/events?${query}`)).json();
  assert.deepEqual(await event(), {arrived: false, puts: 0});
  const put = http.request(`${origin}/put?${query}`, {method: 'PUT'});
  put.on('error', () => {});
  put.end('synthetic');
  await until(async () => (await event()).bodyEnded);
  const deniedRelease = await fetch(`${origin}/release?case=${id}&nonce=wrong`, {method: 'POST'});
  assert.equal(deniedRelease.status, 403);
  assert.equal((await event()).responses, 0);
  put.destroy();
  await until(async () => (await event()).closedBeforeResponse);
  await fetch(`${origin}/release?${query}`, {method: 'POST'});
  let e = await event();
  assert.equal(e.responses, 0);
  assert.equal(e.puts, 1);
  const second = await fetch(`${origin}/put?${query}`, {method: 'PUT', body: 'again'});
  assert.equal(second.status, 409);
  e = await event();
  assert.equal(e.puts, 2);
  console.log('PASS nonce rejection, arrival, aborted response, late release, duplicate PUT count');
})().catch(() => { console.error('fixture self-test failed'); process.exitCode = 1; }).finally(async () => {
  if (!await terminate(server, exited)) {
    console.error('fixture process did not terminate');
    process.exitCode = 1;
  }
});
