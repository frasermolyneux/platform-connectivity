import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import worker from './worker.mjs';

const hosts = JSON.parse(readFileSync(new URL('../terraform/tests/fixtures/maintenance-hosts-baseline.json', import.meta.url)));
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
  const navigation = request('bishopsbees.co.uk');
  navigation.headers.set('Sec-Fetch-Mode', 'navigate');
  navigation.headers.set('Sec-Fetch-Dest', 'document');
  const response = await worker.fetch(navigation, redirect);
  assert.equal(response.status, 302);
  assert.equal(response.headers.get('Location'), 'https://mxstatus.io/');
  for (const [method, accept] of [['POST', 'text/html'], ['GET', '*/*'], ['GET', 'application/json']]) {
    const blocked = await worker.fetch(request('redirect.xtremeidiots.net', method, accept), redirect);
    assert.equal(blocked.status, 503);
    assert.equal(blocked.headers.get('Location'), null);
    assert.equal((await blocked.json()).statusPage, 'https://status.xtremeidiots.com/');
  }
});

test('HTML subrequests and clients without top-level navigation metadata stay at 503 in redirect mode', async () => {
  for (const [mode, destination] of [['cors', 'empty'], ['no-cors', 'iframe'], ['', '']]) {
    const html = request('www.xtremeidiots.com');
    if (mode) html.headers.set('Sec-Fetch-Mode', mode);
    if (destination) html.headers.set('Sec-Fetch-Dest', destination);
    const response = await worker.fetch(html, { ...environment, MODE: 'redirect' });
    assert.equal(response.status, 503);
    assert.equal(response.headers.get('Location'), null);
  }
});

test('HEAD keeps response semantics without a body; unregistered hosts never fall through', async () => {
  const response = await worker.fetch(request('maps.xtremeidiots.com', 'HEAD'), environment);
  assert.equal(response.status, 503);
  assert.equal(await response.text(), '');
  const unknown = await worker.fetch(request('unknown.example'), { ...environment, MODE: 'redirect' });
  assert.equal(unknown.status, 503);
  assert.equal(unknown.headers.get('Location'), null);
});

test('IDP and Radar bypass maintenance for API, OAuth and credential-bearing requests', async () => {
  const registered = { HOSTS: JSON.stringify([
    ...hosts,
    { hostname: 'idp.molyneux.io', site: 'mx' },
    { hostname: 'radar.molyneux.io', site: 'mx' },
  ]) };
  const cases = [
    ['idp.molyneux.io', 'POST', '/signin-oidc'],
    ['idp.molyneux.io', 'GET', '/signin-oidc'],
    ['idp.molyneux.io', 'GET', '/auth/login'],
    ['idp.molyneux.io', 'GET', '/api/collector/identity'],
    ['idp.molyneux.io', 'GET', '/api/collector/catalog'],
    ['idp.molyneux.io', 'GET', '/API/collector/identity'],
    ['idp.molyneux.io', 'GET', '/api/inventory/v1/workload-membership'],
    ['idp.molyneux.io', 'GET', '/api/inventory/v1/workloads/one/documents'],
    ['idp.molyneux.io', 'POST', '/api/inventory/runtime'],
    ['idp.molyneux.io', 'POST', '/api/evidence'],
    ['radar.molyneux.io', 'POST', '/signin-oidc'],
    ['radar.molyneux.io', 'GET', '/auth/login'],
    ['radar.molyneux.io', 'GET', '/auth/github/callback'],
    ['radar.molyneux.io', 'POST', '/api/inventory/events'],
    ['radar.molyneux.io', 'POST', '/api/collector/cyclonedx'],
    ['radar.molyneux.io', 'POST', '/api/evaluations'],
    ['radar.molyneux.io', 'GET', '/api/evaluations'],
    ['radar.molyneux.io', 'GET', '/api/evaluations/one'],
    ['idp.molyneux.io', 'GET', '/dashboard', { Cookie: '__Host-MxIdp=session' }],
    ['radar.molyneux.io', 'GET', '/dashboard', { Cookie: 'other=x; __Host-Radar=session' }],
    ['radar.molyneux.io', 'GET', '/dashboard', { Authorization: 'Bearer token' }],
    ['idp.molyneux.io', 'GET', '/unrelated', { Cookie: '__Host-MxIdp=unverified' }],
  ];
  const original = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async forwarded => {
    calls.push(forwarded);
    return new Response('origin', { status: 302, headers: { Location: 'https://other.example/' } });
  };
  try {
    for (const mode of ['page', 'redirect']) {
      for (const [hostname, method, path, headers = {}] of cases) {
        const incoming = new Request(`https://${hostname}${path}?q=one%2Btwo`, {
          method, headers: { Accept: 'text/html', 'X-Signature': 'signature', ...headers },
          ...(method === 'POST' ? { body: 'signed=payload' } : {}),
        });
        const response = await worker.fetch(incoming, { ...registered, MODE: mode });
        const forwarded = calls.at(-1);
        assert.equal(response.status, 302);
        assert.equal(response.headers.get('Location'), 'https://other.example/');
        assert.equal(forwarded.url, incoming.url);
        assert.equal(forwarded.method, method);
        assert.equal(forwarded.redirect, 'manual');
        assert.equal(forwarded.headers.get('X-Signature'), 'signature');
        assert.equal(forwarded.headers.get('Cookie'), incoming.headers.get('Cookie'));
        assert.equal(forwarded.headers.get('Authorization'), incoming.headers.get('Authorization'));
        if (method === 'POST') assert.equal(await forwarded.text(), 'signed=payload');
      }
    }
    assert.equal(calls.length, cases.length * 2);
  } finally { globalThis.fetch = original; }
});

test('bypass never changes anonymous navigation or unrelated and unregistered hosts', async () => {
  const registered = { HOSTS: JSON.stringify([
    ...hosts,
    { hostname: 'idp.molyneux.io', site: 'mx' },
    { hostname: 'radar.molyneux.io', site: 'mx' },
  ]), MODE: 'redirect' };
  const original = globalThis.fetch;
  globalThis.fetch = () => { throw new Error('Unexpected origin request'); };
  try {
    for (const [hostname, path, headers, method] of [
      ['idp.molyneux.io', '/dashboard', {}, 'GET'],
      ['radar.molyneux.io', '/dashboard', { Cookie: '__Host-Radar-CSRF=csrf' }, 'GET'],
      ['idp.molyneux.io', '/dashboard', { Cookie: '__Host-MxIdp=' }, 'GET'],
      ['idp.molyneux.io', '/dashboard', { Cookie: '__Host-Radar=session' }, 'GET'],
      ['idp.molyneux.io', '/apiculture', {}, 'GET'],
      ['idp.molyneux.io', '/auth/login', {}, 'POST'],
      ['radar.molyneux.io', '/auth/github/callback-extra', {}, 'GET'],
      ['radar.molyneux.io', '/auth/github/callback', {}, 'POST'],
      ['idp.molyneux.io', '/signin-oidc', {}, 'DELETE'],
      ['www.xtremeidiots.com', '/api/evidence', { Authorization: 'Bearer token' }, 'POST'],
      ['unknown.example', '/api/evidence', { Authorization: 'Bearer token' }, 'POST'],
    ]) {
      const response = await worker.fetch(new Request(`https://${hostname}${path}`, {
        method, headers: { Accept: 'text/html', ...headers },
      }), registered);
      assert.equal(response.status, 503);
    }
    const unregistered = new Request('https://idp.molyneux.io/api/collector/identity');
    assert.equal((await worker.fetch(unregistered, environment)).status, 503);
    const navigation = new Request('https://radar.molyneux.io/', {
      headers: { Accept: 'text/html', 'Sec-Fetch-Mode': 'navigate', 'Sec-Fetch-Dest': 'document' },
    });
    assert.equal((await worker.fetch(navigation, registered)).status, 302);
  } finally { globalThis.fetch = original; }
});

test('origin failures propagate instead of returning a maintenance response', async () => {
  const original = globalThis.fetch;
  const error = new Error('origin unavailable');
  globalThis.fetch = async () => { throw error; };
  try {
    const registered = { HOSTS: JSON.stringify([{ hostname: 'idp.molyneux.io', site: 'mx' }]) };
    await assert.rejects(worker.fetch(new Request('https://idp.molyneux.io/api/evidence'), registered), error);
  } finally { globalThis.fetch = original; }
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
  assert.ok(seen.has('maps.xtremeidiots.com'));
  assert.ok(!seen.has('maps.xtremeidiots.net'));
});

test('edge alias redirects preserve catalog canonical destinations, paths, queries and methods', () => {
  const catalog = JSON.parse(readFileSync(new URL('./ingress-catalog.json', import.meta.url)));
  for (const zoneName of ['tripsidekick.app', 'tripsidekick.net', 'talkwithtiles.com', 'bqba.co.uk', 'dm-electricalservices.co.uk']) {
    const zone = JSON.parse(readFileSync(new URL(`../terraform/zones/${zoneName}.json`, import.meta.url)));
    const alias = catalog.hosts.find(host => host.zone === zoneName && host.target.alias_to !== null);
    const rules = zone.rulesets.http_request_dynamic_redirect.rules;
    assert.equal(rules.length, 1);
    if (['tripsidekick.app', 'tripsidekick.net', 'talkwithtiles.com'].includes(zoneName)) {
      assert.equal(alias.current.status, false);
    }
    assert.equal(rules[0].expression, `http.host eq "${alias.hostname}"`);
    assert.equal(rules[0].action, 'redirect');
    assert.equal(rules[0].enabled, true);
    const redirect = rules[0].action_parameters.from_value;
    assert.equal(redirect.status_code, 308);
    assert.equal(redirect.preserve_query_string, true);
    assert.equal(redirect.target_url.expression, `concat("https://${alias.target.alias_to}", http.request.uri.path)`);
    assert.equal(zone.settings.always_use_https, 'on');
  }
});
