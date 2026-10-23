import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import worker from './worker.mjs';

const hosts = JSON.parse(readFileSync(new URL('./hosts.json', import.meta.url)));
const environment = { HOSTS: JSON.stringify(hosts), MODE: 'page' };
const request = (hostname, method = 'GET', accept = 'text/html') =>
  new Request(`https://${hostname}/private/path?token=do-not-forward`, { method, headers: { Accept: accept } });

test('page mode is a self-contained noncacheable 503 without accessing the origin or status service', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = () => { throw new Error('Maintenance must not make subrequests.'); };
  try {
    const response = await worker.fetch(request('www.xtremeidiots.com'), environment);
    assert.equal(response.status, 503);
    assert.equal(response.headers.get('Retry-After'), '300');
    assert.match(response.headers.get('Cache-Control'), /no-store/);
    assert.equal(response.headers.get('X-Platform-Maintenance'), 'v1');
    const body = await response.text();
    assert.match(body, /https:\/\/status.xtremeidiots.com\//);
    assert.doesNotMatch(body, /do-not-forward|private\/path|<script|https:\/\/mxstatus.io/);
  } finally { globalThis.fetch = original; }
});

test('redirect mode redirects browser navigation only, without forwarding paths or queries', async () => {
  const redirect = { ...environment, MODE: 'redirect' };
  const response = await worker.fetch(request('bishopsbees.co.uk'), redirect);
  assert.equal(response.status, 302);
  assert.equal(response.headers.get('Location'), 'https://mxstatus.io/');
  for (const [method, accept] of [['POST', 'text/html'], ['GET', '*/*'], ['GET', 'application/json']]) {
    const blocked = await worker.fetch(request('redirect.xtremeidiots.net', method, accept), redirect);
    assert.equal(blocked.status, 503);
    assert.equal(blocked.headers.get('Location'), null);
    assert.equal((await blocked.json()).statusPage, 'https://status.xtremeidiots.com/');
  }
});

test('HEAD keeps response semantics without a body; unregistered hosts never fall through', async () => {
  const response = await worker.fetch(request('maps.xtremeidiots.net', 'HEAD'), environment);
  assert.equal(response.status, 503);
  assert.equal(await response.text(), '');
  const unknown = await worker.fetch(request('unknown.example'), { ...environment, MODE: 'redirect' });
  assert.equal(unknown.status, 503);
  assert.equal(unknown.headers.get('Location'), null);
});

test('registry admits exact proxied web hosts only and never includes status or wildcard hostnames', () => {
  const seen = new Set();
  for (const host of hosts) {
    assert.ok(!seen.has(host.hostname));
    seen.add(host.hostname);
    assert.match(host.hostname, /^[a-z0-9.-]+$/);
    assert.ok(host.hostname === host.zone || host.hostname.endsWith(`.${host.zone}`));
    assert.ok(['mx', 'xi'].includes(host.site));
    assert.ok(!['mxstatus.io', 'status.xtremeidiots.com'].includes(host.hostname));
    const zone = JSON.parse(readFileSync(new URL(`../terraform/zones/${host.zone}.json`, import.meta.url)));
    assert.ok(host.canary && host.hostname === 'maintenance-check.bishopsbees.co.uk'
      || zone.records.some(record => record.proxied && ['A', 'AAAA', 'CNAME'].includes(record.type)
      && (record.name === '@' ? zone.name : `${record.name}.${zone.name}`) === host.hostname));
  }
});
