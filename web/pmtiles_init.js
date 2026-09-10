window.registerUsraPmtiles = function registerUsraPmtiles() {
  if (window.__usraPmtilesRegistered) return;
  if (!window.maplibregl || !window.pmtiles) {
    return;
  }
  const protocol = new window.pmtiles.Protocol();
  window.maplibregl.addProtocol('pmtiles', protocol.tile);
  window.__usraPmtilesRegistered = true;
};

// The Flutter development server can answer a ranged request with 304 when
// the browser sends If-None-Match. PMTiles requires the requested byte range
// in the response, so bypass conditional caching for this one archive.
(function patchPmtilesFetch() {
  const originalFetch = window.fetch.bind(window);
  window.fetch = function(input, init) {
    const url = typeof input === 'string' ? input : input && input.url;
    if (!url || !url.includes('santa-maria-rs.pmtiles')) {
      return originalFetch(input, init);
    }
    const request = input instanceof Request ? input : new Request(input, init);
    const headers = new Headers(request.headers);
    headers.delete('If-None-Match');
    headers.delete('If-Modified-Since');
    return originalFetch(new Request(request, {headers, cache: 'no-store'}));
  };
})();
