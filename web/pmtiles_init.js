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
    const range = headers.get('Range') || headers.get('range');
    headers.delete('If-None-Match');
    headers.delete('If-Modified-Since');
    if (!range) {
      return originalFetch(new Request(request, {headers, cache: 'no-store'}));
    }

    // Flutter's development server ignores Range and returns 200 with the
    // complete asset. Adapt that response to the 206 contract PMTiles needs.
    headers.delete('Range');
    return originalFetch(new Request(request, {headers, cache: 'no-store'}))
      .then(response => response.arrayBuffer())
      .then(buffer => {
        const match = /bytes=(\d+)-(\d*)/i.exec(range);
        if (!match) return new Response(buffer);
        const start = Number(match[1]);
        const requestedEnd = match[2] ? Number(match[2]) : buffer.byteLength - 1;
        const end = Math.min(requestedEnd, buffer.byteLength - 1);
        const body = buffer.slice(start, end + 1);
        return new Response(body, {
          status: 206,
          headers: {
            'Content-Length': String(body.byteLength),
            'Content-Range': `bytes ${start}-${end}/${buffer.byteLength}`,
            'Content-Type': 'application/octet-stream',
          },
        });
      });
  };
})();
