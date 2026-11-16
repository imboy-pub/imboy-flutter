// Test-only counters: private origin and synthetic data only. Values never leave the page.
(() => {
  const counts = Object.create(null);
  const bump = k => { counts[k] = (counts[k] || 0) + 1; };
  function wrap(target, name, label) {
    const original = target[name];
    target[name] = function (...args) { bump(label); return Reflect.apply(original, this, args); };
  }
  for (const n of ['setItem', 'removeItem', 'clear']) wrap(Storage.prototype, n, 'storage_write');
  for (const n of ['open', 'deleteDatabase']) wrap(IDBFactory.prototype, n, 'idb_open_delete');
  wrap(window, 'fetch', 'fetch');
  wrap(XMLHttpRequest.prototype, 'send', 'xhr_send');
  for (const name of ['WebSocket', 'EventSource']) {
    const original = window[name];
    window[name] = new Proxy(original, { construct(target, args, newTarget) {
      bump(name); return Reflect.construct(target, args, newTarget);
    }});
  }
  // Positive controls run only on a fresh private origin and remove their own data.
  window.startupBusySelfTest = async () => {
    const id = crypto.randomUUID();
    const key = `startup-busy-selftest-${id}`;
    const dbName = `startup-busy-selftest-${id}`;
    if (localStorage.getItem(key) !== null || sessionStorage.getItem(key) !== null) {
      throw Error('self-test key collision');
    }
    localStorage.setItem(key, 'synthetic');
    sessionStorage.setItem(key, 'synthetic');
    localStorage.removeItem(key);
    sessionStorage.removeItem(key);
    const open = indexedDB.open(dbName, 1);
    const db = await new Promise((resolve, reject) => {
      open.onsuccess = () => resolve(open.result);
      open.onerror = () => reject(Error('self-test IDB open failed'));
    });
    db.close();
    const deletion = indexedDB.deleteDatabase(dbName);
    await new Promise((resolve, reject) => {
      deletion.onsuccess = () => resolve();
      deletion.onerror = () => reject(Error('self-test IDB delete failed'));
      deletion.onblocked = () => reject(Error('self-test IDB delete blocked'));
    });
    const response = await fetch('/fixtures/startup_busy_counter.js');
    if (!response.ok) throw Error('self-test fetch failed');
    await response.arrayBuffer();
    await new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('GET', '/fixtures/startup_busy_counter.js');
      xhr.onload = () => xhr.status === 200 ? resolve() : reject(Error('self-test XHR status'));
      xhr.onerror = () => reject(Error('self-test XHR failed'));
      xhr.send();
    });
    // Invalid URL exercises constructor interception without opening a socket.
    for (const ctor of [WebSocket, EventSource]) {
      let rejected = false;
      try { new ctor('http://[invalid'); } catch (_) { rejected = true; }
      if (!rejected) throw Error('self-test constructor unexpectedly accepted invalid URL');
    }
    return JSON.stringify(counts);
  };
  window.startupBusyReset = () => { for (const key of Object.keys(counts)) delete counts[key]; };
  window.startupBusyCounts = () => JSON.stringify(counts);
  const snapshot = storage => Object.keys(storage).sort().map(k => [k, storage.getItem(k)]);
  window.startupBusyStorageSnapshot = () => JSON.stringify([snapshot(localStorage), snapshot(sessionStorage)]);
})();
