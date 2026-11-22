const statusSites = { mx: 'https://mxstatus.io/', xi: 'https://status.xtremeidiots.com/' };
const escapeHtml = text => text.replace(/[&<>"']/g, character =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);

function bypassMaintenance(request, hostname, pathname) {
  pathname = pathname.toLowerCase();
  const method = request.method;
  if (!['idp.molyneux.io', 'radar.molyneux.io'].includes(hostname)) return false;
  if (pathname === '/signin-oidc' && ['GET', 'POST'].includes(method)) return true;

  if (hostname === 'idp.molyneux.io') {
    if (method === 'POST') return ['/api/inventory/runtime', '/api/evidence'].includes(pathname);
    if (method !== 'GET') return false;
    return ['/api/collector/catalog', '/api/collector/inventory/workloads',
      '/api/inventory/v1/workload-membership', '/api/inventory/v1/workloads'].includes(pathname)
      || /^\/api\/collector\/pipelines\/[^/]+$/.test(pathname)
      || /^\/api\/collector\/inventory\/workloads\/[^/]+(?:\/documents)?$/.test(pathname)
      || /^\/api\/inventory\/v1\/workloads\/[^/]+\/documents$/.test(pathname);
  }

  if (method === 'POST') {
    return ['/api/inventory/events', '/api/collector/cyclonedx', '/api/evaluations'].includes(pathname);
  }
  return method === 'GET' && (pathname === '/auth/github/callback'
    || pathname === '/api/evaluations' || /^\/api\/evaluations\/[^/]+$/.test(pathname));
}

export default {
  async fetch(request, environment) {
    const url = new URL(request.url);
    const hostname = url.hostname.toLowerCase();
    const hosts = JSON.parse(environment.HOSTS);
    const host = hosts.find(host => host.hostname === hostname);
    if (host && bypassMaintenance(request, hostname, url.pathname)) {
      return fetch(new Request(request, { redirect: 'manual' }));
    }
    const site = host?.site;
    const statusUrl = statusSites[site];
    const headers = new Headers({
      'Cache-Control': 'no-store, max-age=0',
      'Referrer-Policy': 'no-referrer',
      'X-Content-Type-Options': 'nosniff',
      'X-Robots-Tag': 'noindex, noarchive',
      'X-Platform-Maintenance': 'v1',
      'Retry-After': '300',
      'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
    });
    const browser = ['GET', 'HEAD'].includes(request.method)
      && request.headers.get('Accept')?.toLowerCase().includes('text/html');
    const navigation = browser && request.headers.get('Sec-Fetch-Mode') === 'navigate'
      && request.headers.get('Sec-Fetch-Dest') === 'document';
    if (statusUrl && navigation && environment.MODE === 'redirect') {
      headers.set('Location', statusUrl);
      return new Response(null, { status: 302, headers });
    }
    if (!browser) {
      headers.set('Content-Type', 'application/problem+json; charset=utf-8');
      return new Response(request.method === 'HEAD' ? null : JSON.stringify({
        type: 'about:blank', title: 'Service temporarily unavailable', status: 503,
        detail: 'This service is temporarily unavailable. Please try again later.',
        ...(statusUrl ? { statusPage: statusUrl } : {}),
      }), { status: 503, headers });
    }
    headers.set('Content-Type', 'text/html; charset=utf-8');
    const body = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Service temporarily unavailable</title>
<style>body{margin:0;background:#f6f8fa;color:#1f2328;font:16px/1.6 system-ui,sans-serif;display:grid;min-height:100vh;place-items:center}main{box-sizing:border-box;width:min(92%,600px);padding:40px;border:1px solid #d1d9e0;border-radius:16px;background:white}h1{font-size:28px;line-height:1.2}a{color:#0969da}small{color:#59636e}</style>
</head><body><main><small>${escapeHtml(hostname)}</small><h1>Service temporarily unavailable</h1>
<p>We are carrying out maintenance or investigating an issue. Please try again later.</p>
${statusUrl ? `<p><a href="${statusUrl}">View service status and updates</a></p>` : '<p>Please contact the site operator for updates.</p>'}
</main></body></html>`;
    return new Response(request.method === 'HEAD' ? null : body, { status: 503, headers });
  },
};
