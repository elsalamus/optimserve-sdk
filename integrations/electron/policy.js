const base = 'https://p2p.optimserve.agency';
export function createHeaderPolicy(webContentsId, pageURL) {
  const page = new URL(pageURL); page.hash = '';
  const capabilities = new Set();
  function trusted(details) {
    try {const url = new URL(details.frame?.url); url.hash = ''; return details.webContentsId === webContentsId && url.href === page.href && details.frame?.parent == null;} catch {return false;}
  }
  function capability(address) {
    try {
      const url = new URL(address);
      if (!['https:','wss:'].includes(url.protocol) || url.hostname !== 'p2p.optimserve.agency' || url.port || url.username || url.password || url.hash) return null;
      const match = url.pathname.match(/^\/api\/native\/(?:sessions\/([a-f\d]{64})\/(?:renew|reports|configuration|stop|lease|v1(?:\/channel(?:\/[^/]+\/node\/[^/]+\/(?:peers|stats))?)?)|signal\/([a-f\d]{64}))$/);
      if (!match || (url.protocol === 'wss:') !== url.pathname.startsWith('/api/native/signal/')) return null;
      return match[1] || match[2];
    } catch {return null;}
  }
  function allowed(details) {return trusted(details) && capabilities.has(capability(details.url));}
  return {
    learn(grant) {
      const cap = capability(grant?.renew);
      if (!cap || !['p2p','http'].includes(grant.mode) || grant.expiresIn !== 600) throw new Error('Invalid native session.');
      for (const key of ['renew','report','configuration','stop']) if (capability(grant[key]) !== cap) throw new Error('Invalid native session endpoint.');
      if (grant.mode === 'p2p' && (capability(grant.announce) !== cap || capability(grant.lease) !== cap || capability(grant.signalConfig?.main) !== cap)) throw new Error('Invalid native transport endpoint.');
      capabilities.add(cap); if (capabilities.size > 16) capabilities.delete(capabilities.values().next().value);
      return grant;
    },
    request(details) {
      const headers = {...details.requestHeaders};
      if (allowed(details)) for (const key of Object.keys(headers)) if (['origin','cookie','authorization'].includes(key.toLowerCase())) delete headers[key];
      return {requestHeaders:headers};
    },
    response(details) {
      if (!allowed(details)) return {responseHeaders:details.responseHeaders};
      const headers = Object.fromEntries(Object.entries(details.responseHeaders || {}).filter(([key]) => !['access-control-allow-origin','access-control-allow-headers','access-control-allow-methods','set-cookie'].includes(key.toLowerCase())));
      headers['Access-Control-Allow-Origin'] = [page.origin];
      headers['Access-Control-Allow-Methods'] = ['POST, GET, OPTIONS'];
      headers['Access-Control-Allow-Headers'] = ['Content-Type'];
      headers['Vary'] = [...(headers['Vary'] || []),'Origin'];
      return {responseHeaders:headers,...(details.method === 'OPTIONS' ? {statusLine:'HTTP/1.1 204 No Content'} : {})};
    },
    close() {capabilities.clear();},
    get stops() {return [...capabilities].map(cap => `${base}/api/native/sessions/${cap}/stop`);}
  };
}
