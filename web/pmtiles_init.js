const USRA_PMTILES_URL = 'assets/assets/maps/santa-maria-rs.pmtiles';

window.registerUsraPmtiles = async function registerUsraPmtiles() {
  if (window.__usraPmtilesRegistered) return;
  if (!window.maplibregl || !window.pmtiles) {
    return;
  }

  // Load the archive once. The service worker supplies the complete cached
  // response when offline; the PMTiles protocol then reads byte ranges from
  // this in-memory source without issuing HTTP requests for individual tiles.
  const response = await fetch(USRA_PMTILES_URL);
  if (!response.ok) {
    throw new Error(`Unable to load offline PMTiles archive (${response.status})`);
  }
  const archive = await response.arrayBuffer();
  const source = {
    getKey: () => USRA_PMTILES_URL,
    getBytes: async (offset, length, signal) => {
      if (signal?.aborted) throw new DOMException('Aborted', 'AbortError');
      return {data: archive.slice(offset, offset + length)};
    },
  };

  const protocol = new window.pmtiles.Protocol();
  window.maplibregl.addProtocol('pmtiles', protocol.tile);
  protocol.add(new window.pmtiles.PMTiles(source));
  window.__usraPmtilesRegistered = true;
};
