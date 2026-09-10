(function registerUsraPmtiles() {
  if (window.__usraPmtilesRegistered) return;
  if (!window.maplibregl || !window.pmtiles) {
    window.setTimeout(registerUsraPmtiles, 50);
    return;
  }
  const protocol = new window.pmtiles.Protocol();
  window.maplibregl.addProtocol('pmtiles', protocol.tile);
  window.__usraPmtilesRegistered = true;
})();
