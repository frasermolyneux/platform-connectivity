export default {
  fetch(request) {
    return new Response(request.method === 'HEAD' ? null : 'Maintenance control acceptance endpoint.\n', {
      status: 200,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Cache-Control': 'no-store',
        'X-Robots-Tag': 'noindex, noarchive',
        'X-Platform-Maintenance-Canary': 'v1',
      },
    });
  },
};
