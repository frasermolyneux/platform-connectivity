const statusSites = { mx: 'https://mxstatus.io/', xi: 'https://status.xtremeidiots.com/' };
const escapeHtml = text => text.replace(/[&<>"']/g, character =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);

export default {
  async fetch(request, environment) {
    const hostname = new URL(request.url).hostname.toLowerCase();
    const hosts = JSON.parse(environment.HOSTS);
    const site = hosts.find(host => host.hostname === hostname)?.site;
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
    if (statusUrl && browser && environment.MODE === 'redirect') {
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
