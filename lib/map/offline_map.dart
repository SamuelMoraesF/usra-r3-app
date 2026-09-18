import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../data/database.dart';
import '../time_display.dart';
import '../grid_locator.dart';
import 'contact_aggregation.dart';
import 'contact_scene.dart';
import 'station_presence.dart';
import 'map_settings.dart';
import 'route_distance.dart';
import 'map_palette.dart';
import 'map_compass.dart';
import 'elevation.dart';
import '../browser_fullscreen_stub.dart'
    if (dart.library.js_interop) '../browser_fullscreen_web.dart';
import 'pmtiles_registration_stub.dart'
    if (dart.library.js_interop) 'pmtiles_registration_web.dart';
import 'offline_map_style_stub.dart'
    if (dart.library.io) 'offline_map_style_io.dart';

class OfflineContactsMap extends StatefulWidget {
  const OfflineContactsMap({
    super.key,
    required this.entries,
    required this.operatorGrid,
    this.operatorCallsign = '',
    this.focusGrid = '',
    this.focusRequest = 0,
    this.hoveredCallsign = '',
    this.mergePrecision = true,
    this.lastOnly = false,
    this.maxAgeHours = defaultContactMaxAgeHours,
    this.warningMinutes = defaultContactWarningMinutes,
    this.sessionStartedAt,
    this.disconnections,
    this.onDisconnect,
    this.entriesLoaded = true,
    this.selectedMode = 'repeater',
    this.selectedFrequencyMhz = 145.37,
    this.settings = const MapSettings(),
    this.onSettingsChanged,
    this.onBearingChanged,
    this.onElevationRangeChanged,
    this.onResetNorthChanged,
    this.controlsInMap = true,
    this.onExportPng,
    this.onInitialSnapshot,
    this.onInitialSnapshotUnavailable,
    this.asOf,
    this.includeClosedSession = false,
    this.fitPadding = 80,
  });
  final List<LogEntry> entries;
  final String operatorGrid;
  final String operatorCallsign;
  final String focusGrid;
  final int focusRequest;
  final String hoveredCallsign;
  final bool mergePrecision;
  final bool lastOnly;
  final int maxAgeHours;
  final int warningMinutes;
  final DateTime? sessionStartedAt;
  final StationDisconnections? disconnections;
  final Future<void> Function(LogEntry)? onDisconnect;
  final bool entriesLoaded;
  final String selectedMode;
  final double selectedFrequencyMhz;
  final MapSettings settings;
  final ValueChanged<MapSettings>? onSettingsChanged;
  final ValueChanged<double>? onBearingChanged;
  final ValueChanged<ElevationRange?>? onElevationRangeChanged;
  final ValueChanged<Future<void> Function()>? onResetNorthChanged;
  final bool controlsInMap;
  final Future<void> Function(Uint8List bytes)? onExportPng;
  final Future<void> Function(Uint8List bytes)? onInitialSnapshot;
  final Future<void> Function()? onInitialSnapshotUnavailable;
  final DateTime? asOf;
  final bool includeClosedSession;
  final double fitPadding;

  @override
  State<OfflineContactsMap> createState() => _OfflineContactsMapState();
}

class _RenderedContactMarker {
  const _RenderedContactMarker(this.group, {this.circle, this.symbol});

  final _MarkerRenderGroup group;
  final Circle? circle;
  final Symbol? symbol;

  ContactMarker get marker => group.marker;
}

class _MarkerRenderGroup {
  const _MarkerRenderGroup({
    required this.marker,
    required this.position,
    this.contactIndices = const [],
  });

  final ContactMarker marker;
  final LatLng position;
  final List<int> contactIndices;

  bool get isCluster => contactIndices.length > 1;
}

class _ProjectedMarker {
  const _ProjectedMarker({
    required this.marker,
    required this.position,
    required this.screen,
  });

  final ContactMarker marker;
  final LatLng position;
  final math.Point<num> screen;
}

class _CallsignLabelCandidate {
  const _CallsignLabelCandidate({
    required this.position,
    required this.callsigns,
    required this.screen,
  });

  final LatLng position;
  final List<String> callsigns;
  final math.Point<num> screen;
}

class _OfflineContactsMapState extends State<OfflineContactsMap>
    with WidgetsBindingObserver {
  MapLibreMapController? controller;
  List<MapContact> contacts = const [];
  ColorScheme? _mapColors;
  ColorScheme? _appliedMapColors;
  bool _styleReady = false;
  bool _initialCameraSet = false;
  late ContactScene _scene;
  Timer? _expiryTimer;
  bool _drawing = false;
  bool _redrawRequested = false;
  bool _repositioning = false;
  bool _repositionRequested = false;
  bool _orbitingMarkersVisible = true;
  bool? _renderedShowLines;
  bool? _renderedShowPrecision;
  List<ContactRoute> _renderedRoutes = const [];
  String _renderedCallsignsKey = '';
  bool _distanceLayerReady = false;
  bool _callsignLayerReady = false;
  final _labelImages = <String, String>{};
  final _clusterImages = <int, String>{};
  final _warningImages = <String>{};
  List<_RenderedContactMarker> _renderedMarkers = const [];
  final _mapBearing = ValueNotifier<double>(0);
  final _elevationRange = ValueNotifier<ElevationRange?>(null);
  Timer? _hoverPulseTimer;
  final _hoverPulseCircles = <Circle>[];
  double _hoverPulseProgress = 0;
  ElevationGrid? _elevationGrid;
  Future<ElevationGrid?>? _elevationFuture;
  Timer? _elevationDebounce;
  bool _elevationLayerReady = false;
  bool _elevationDrawing = false;
  bool _elevationRedrawRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colors = Theme.of(context).colorScheme;
    if (_mapColors?.brightness == colors.brightness) return;
    _mapColors = colors;
    final source = _sourceStyle;
    if (source != null) {
      // Keep styleString stable: replacing it destroys annotation sources.
      // The serialized draw updates the existing basemap's paint instead.
      unawaited(_drawContacts());
    }
  }

  Future<void> _handleStyleLoaded() async {
    if (!mounted) return;
    _appliedMapColors = null;
    _distanceLayerReady = false;
    _callsignLayerReady = false;
    _labelImages.clear();
    _clusterImages.clear();
    _warningImages.clear();
    _elevationLayerReady = false;
    _updateElevationRange(null);
    _renderedMarkers = const [];
    _renderedShowLines = null;
    _renderedShowPrecision = null;
    _renderedRoutes = const [];
    _renderedCallsignsKey = '';
    _orbitingMarkersVisible = (controller?.cameraPosition?.zoom ?? 12) >= 15;
    _styleReady = true;

    // This callback runs after MapLibre has initialized annotation managers.
    // Restore custom sources and images only once the new style is ready.
    // The web implementation can leave camera/layer operations pending even
    // after the map is already rendered. Do not block snapshot capture on
    // those futures; the short render delay below lets the map settle.
    unawaited(_drawContacts());
    unawaited(_fitInitialPoints());
    final snapshotCallback = widget.onInitialSnapshot;
    final map = controller;
    if (snapshotCallback != null && map != null && _scene.markers.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        final snapshot = await _takeReportSnapshot(map);
        if (mounted) await snapshotCallback(snapshot);
      } catch (_) {
        final unavailable = widget.onInitialSnapshotUnavailable;
        if (mounted && unavailable != null) await unavailable();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshContacts();
    _loadStyle();
    _elevationFuture = _loadElevation();
    _prepareWeb();
  }

  @override
  void didUpdateWidget(covariant OfflineContactsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusRequest != widget.focusRequest) {
      _initialCameraSet = true;
      _animateToGrid(widget.focusGrid);
    }
    if (oldWidget.hoveredCallsign != widget.hoveredCallsign) {
      _hoverPulseProgress = 0;
      unawaited(_refreshHoverPulse());
    }
    if (oldWidget.entries != widget.entries ||
        oldWidget.operatorGrid != widget.operatorGrid ||
        oldWidget.operatorCallsign != widget.operatorCallsign ||
        oldWidget.mergePrecision != widget.mergePrecision ||
        oldWidget.lastOnly != widget.lastOnly ||
        oldWidget.selectedMode != widget.selectedMode ||
        oldWidget.selectedFrequencyMhz != widget.selectedFrequencyMhz ||
        oldWidget.settings != widget.settings ||
        oldWidget.sessionStartedAt != widget.sessionStartedAt ||
        oldWidget.asOf != widget.asOf ||
        oldWidget.includeClosedSession != widget.includeClosedSession ||
        oldWidget.fitPadding != widget.fitPadding ||
        oldWidget.disconnections != widget.disconnections ||
        oldWidget.warningMinutes != widget.warningMinutes ||
        oldWidget.maxAgeHours != widget.maxAgeHours) {
      _refreshContacts();
      _drawContacts();
      _scheduleElevationRedraw(immediate: true);
    }
    _fitInitialPoints();
  }

  Future<void> _fitInitialPoints() async {
    final map = controller;
    if (map == null ||
        !mounted ||
        !_styleReady ||
        !widget.entriesLoaded ||
        _initialCameraSet) {
      return;
    }
    _initialCameraSet = true;
    final bounds = [
      GridLocator.bounds(widget.operatorGrid),
      ..._scene.markers.map((marker) => GridLocator.bounds(marker.grid)),
    ].nonNulls.toList();
    if (bounds.isEmpty) return;
    var south = bounds.first.centerLatitude;
    var north = south;
    var west = bounds.first.centerLongitude;
    var east = west;
    for (final point in bounds.skip(1)) {
      if (point.centerLatitude < south) south = point.centerLatitude;
      if (point.centerLatitude > north) north = point.centerLatitude;
      if (point.centerLongitude < west) west = point.centerLongitude;
      if (point.centerLongitude > east) east = point.centerLongitude;
    }
    if (south == north && west == east) {
      await map.moveCamera(CameraUpdate.newLatLngZoom(LatLng(south, west), 13));
      return;
    }
    await map.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        left: widget.fitPadding,
        top: widget.fitPadding,
        right: widget.fitPadding,
        bottom: widget.fitPadding,
      ),
    );
  }

  Future<void> _animateToGrid(String value, {double zoom = 13}) async {
    final map = controller;
    final bounds = GridLocator.bounds(value);
    if (map == null || bounds == null) return;
    await map.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(bounds.centerLatitude, bounds.centerLongitude),
        zoom,
      ),
    );
  }

  void _refreshContacts() {
    final now = widget.asOf ?? DateTime.now().toUtc();
    _scene = buildContactScene(
      widget.entries,
      now: now,
      maxAgeHours: widget.maxAgeHours,
      sessionStartedAt: widget.sessionStartedAt,
      warningMinutes: widget.warningMinutes,
      disconnections: widget.disconnections,
      showAll: widget.settings.showAll,
      operatorGrid: widget.operatorGrid,
      repeaterGrid: widget.settings.repeaterGrid,
      selectedMode: widget.selectedMode,
      selectedFrequencyMhz: widget.selectedFrequencyMhz,
      showLines: widget.settings.showLines,
      mergePrecision: widget.mergePrecision,
      lastOnly: widget.lastOnly,
      asOf: widget.asOf,
      includeClosedSession: widget.includeClosedSession,
    );
    contacts = _scene.contacts;
    _expiryTimer?.cancel();
    _elevationDebounce?.cancel();
    _hoverPulseTimer?.cancel();
    final next = stationPresence(
      widget.entries,
      now: now,
      sessionStartedAt: widget.sessionStartedAt,
      mode: widget.selectedMode,
      frequencyMhz: widget.selectedFrequencyMhz,
      maxAgeHours: widget.maxAgeHours,
      warningMinutes: widget.warningMinutes,
      disconnections: widget.disconnections,
      includeAllFrequencies: true,
      includeClosedSession: widget.includeClosedSession,
    ).nextChange;
    if (next != null && widget.asOf == null) {
      _expiryTimer = Timer(next.difference(now), () {
        if (!mounted) return;
        _refreshContacts();
        _drawContacts();
      });
    }
  }

  Future<Uint8List> _takeReportSnapshot(MapLibreMapController map) async {
    if (!kIsWeb) {
      return map
          .takeSnapshot(width: 1124, height: 594)
          .timeout(const Duration(seconds: 10));
    }

    final originalSize = await map.setWebMapToCustomSize(
      const ui.Size(1124, 594),
    );
    try {
      map.forceResizeWebMap();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return await map.takeSnapshot().timeout(const Duration(seconds: 10));
    } finally {
      await map.setWebMapToCustomSize(originalSize);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    final map = controller;
    map?.onCircleTapped.remove(_onCircleTapped);
    map?.onSymbolTapped.remove(_onSymbolTapped);
    map?.removeListener(_onMapControllerChanged);
    _mapBearing.dispose();
    _elevationRange.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshContacts();
      _drawContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _cachedStyle;
    if (style == null || !_webReady) {
      return Center(
        child: _webLoadFailed
            ? Text(_webLoadStatus)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_webLoadStatus),
                  if (kIsWeb) ...[
                    const SizedBox(height: 8),
                    Text(
                      'O mapa será disponibilizado para uso offline.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: MapLibreMap(
            styleString: style,
            initialCameraPosition: const CameraPosition(
              target: LatLng(-29.6868, -53.8069),
              zoom: 12,
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(6, null),
            trackCameraPosition: true,
            annotationOrder: const [
              AnnotationType.fill,
              AnnotationType.line,
              AnnotationType.symbol,
              AnnotationType.circle,
            ],
            cameraTargetBounds: CameraTargetBounds(
              LatLngBounds(
                southwest: const LatLng(-30.903987, -55.171814),
                northeast: const LatLng(-28.65108, -52.481922),
              ),
            ),
            compassEnabled: false,
            myLocationEnabled: false,
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            onStyleLoadedCallback: () => unawaited(_handleStyleLoaded()),
          ),
        ),
        if (widget.controlsInMap && widget.settings.showCompass)
          Positioned(
            left: 12,
            bottom: 12,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ValueListenableBuilder<double>(
                valueListenable: _mapBearing,
                builder: (context, bearing, child) =>
                    MapCompass(bearing: bearing, onTap: _resetMapNorth),
              ),
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Centralizar na minha localização',
                    icon: const Icon(Icons.my_location),
                    onPressed: () =>
                        _animateToGrid(widget.operatorGrid, zoom: 16),
                  ),
                  if (widget.sessionStartedAt != null) ...[
                    IconButton(
                      tooltip: 'Exportar mapa como PNG',
                      icon: const Icon(Icons.image_outlined),
                      onPressed:
                          controller == null || widget.onExportPng == null
                          ? null
                          : () async {
                              final bytes = await controller!.takeSnapshot();
                              await widget.onExportPng!(bytes);
                            },
                    ),
                    IconButton(
                      tooltip: 'Mostrar linhas de distância',
                      isSelected: widget.settings.showLines,
                      color: widget.settings.showLines
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      icon: const Icon(Icons.straighten),
                      onPressed: () => widget.onSettingsChanged?.call(
                        MapSettings(
                          showLines: !widget.settings.showLines,
                          showCallsigns: widget.settings.showCallsigns,
                          showAll: widget.settings.showAll,
                          showPrecision: widget.settings.showPrecision,
                          showElevation: widget.settings.showElevation,
                          showCompass: widget.settings.showCompass,
                          repeaterGrid: widget.settings.repeaterGrid,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mostrar indicativos',
                      isSelected: widget.settings.showCallsigns,
                      color: widget.settings.showCallsigns
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      icon: const Icon(Icons.abc),
                      onPressed: () => widget.onSettingsChanged?.call(
                        MapSettings(
                          showLines: widget.settings.showLines,
                          showAll: widget.settings.showAll,
                          showPrecision: widget.settings.showPrecision,
                          showElevation: widget.settings.showElevation,
                          showCompass: widget.settings.showCompass,
                          showCallsigns: !widget.settings.showCallsigns,
                          repeaterGrid: widget.settings.repeaterGrid,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mostrar precisão dos pontos',
                      isSelected: widget.settings.showPrecision,
                      color: widget.settings.showPrecision
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      icon: const Icon(Icons.circle),
                      onPressed: () => widget.onSettingsChanged?.call(
                        MapSettings(
                          showLines: widget.settings.showLines,
                          showAll: widget.settings.showAll,
                          showPrecision: !widget.settings.showPrecision,
                          showCallsigns: widget.settings.showCallsigns,
                          showElevation: widget.settings.showElevation,
                          showCompass: widget.settings.showCompass,
                          repeaterGrid: widget.settings.repeaterGrid,
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Mostrar altitudes',
                    isSelected: widget.settings.showElevation,
                    color: widget.settings.showElevation
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    icon: const Icon(Icons.terrain),
                    onPressed: () => widget.onSettingsChanged?.call(
                      MapSettings(
                        showLines: widget.settings.showLines,
                        showAll: widget.settings.showAll,
                        showPrecision: widget.settings.showPrecision,
                        showElevation: !widget.settings.showElevation,
                        showCallsigns: widget.settings.showCallsigns,
                        showCompass: widget.settings.showCompass,
                        repeaterGrid: widget.settings.repeaterGrid,
                      ),
                    ),
                  ),
                  if (widget.sessionStartedAt != null)
                    IconButton(
                      tooltip: 'Ligar estações de todas as frequências',
                      isSelected: widget.settings.showAll,
                      color: widget.settings.showAll
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      icon: const Icon(Icons.cell_tower),
                      onPressed: () => widget.onSettingsChanged?.call(
                        MapSettings(
                          showLines: widget.settings.showLines,
                          showAll: !widget.settings.showAll,
                          showCallsigns: widget.settings.showCallsigns,
                          showPrecision: widget.settings.showPrecision,
                          showElevation: widget.settings.showElevation,
                          showCompass: widget.settings.showCompass,
                          focusNewRecord: widget.settings.focusNewRecord,
                          repeaterGrid: widget.settings.repeaterGrid,
                        ),
                      ),
                    ),
                  if (kIsWeb)
                    IconButton(
                      tooltip: 'Alternar tela cheia',
                      icon: const Icon(Icons.fullscreen),
                      onPressed: toggleBrowserFullscreen,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.controlsInMap && widget.settings.showElevation)
          Positioned(
            right: 12,
            bottom: 12,
            child: ValueListenableBuilder<ElevationRange?>(
              valueListenable: _elevationRange,
              builder: (context, range, child) => ElevationLegend(range: range),
            ),
          ),
      ],
    );
  }

  void _onMapCreated(MapLibreMapController value) {
    if (mounted) setState(() => controller = value);
    widget.onResetNorthChanged?.call(_resetMapNorth);
    value.onCircleTapped.add(_onCircleTapped);
    value.onSymbolTapped.add(_onSymbolTapped);
    value.addListener(_onMapControllerChanged);
    _onMapControllerChanged();
  }

  void _onCameraMove(CameraPosition position) {
    final map = controller;
    if (!mounted || map == null) return;
    _updateMapBearing(position.bearing);
    _scheduleElevationRedraw();
    if (_renderedMarkers.any(
      (rendered) =>
          rendered.marker.orbitCount > 1 && rendered.marker.orbitIndex > 0,
    )) {
      unawaited(_repositionContactMarkers(map));
    }
  }

  void _onMapControllerChanged() {
    if (!mounted) return;
    final position = controller?.cameraPosition;
    if (position != null) _updateMapBearing(position.bearing);
  }

  void _onCameraIdle() {
    final map = controller;
    if (!mounted || map == null) return;
    final cached = map.cameraPosition;
    if (cached != null) {
      _updateMapBearing(cached.bearing);
      _scheduleElevationRedraw(immediate: true);
      _updateOrbitingMarkerVisibility(map, cached.zoom);
      unawaited(_drawContacts());
      return;
    }
    // Keep the compass working on platform implementations that do not cache
    // camera positions unless tracking is enabled.
    map.queryCameraPosition().then((position) {
      if (mounted && position != null) {
        _updateMapBearing(position.bearing);
        _scheduleElevationRedraw(immediate: true);
        _updateOrbitingMarkerVisibility(map, position.zoom);
        unawaited(_drawContacts());
      }
    });
  }

  void _updateOrbitingMarkerVisibility(MapLibreMapController map, double zoom) {
    final visible = zoom >= 15;
    if (visible != _orbitingMarkersVisible) {
      _orbitingMarkersVisible = visible;
      unawaited(_drawContacts());
    } else {
      unawaited(_repositionContactMarkers(map));
    }
  }

  void _updateMapBearing(double rawBearing) {
    final bearing = normalizeBearing(rawBearing);
    if ((_mapBearing.value - bearing).abs() >= 0.1) {
      _mapBearing.value = bearing;
      widget.onBearingChanged?.call(bearing);
    }
  }

  void _updateElevationRange(ElevationRange? range) {
    _elevationRange.value = range;
    widget.onElevationRangeChanged?.call(range);
  }

  Future<void> _resetMapNorth() async {
    final map = controller;
    if (map == null || !mounted) return;
    await map.animateCamera(
      CameraUpdate.bearingTo(0),
      duration: const Duration(milliseconds: 250),
    );
  }

  void _onCircleTapped(Circle circle) {
    final index = circle.data?['contactIndex'];
    if (index is int && index >= 0 && index < contacts.length) {
      unawaited(_showContact(contacts[index]));
    }
  }

  void _onSymbolTapped(Symbol symbol) {
    final clusterIndices = symbol.data?['clusterIndices'];
    if (clusterIndices is List && clusterIndices.isNotEmpty) {
      final index = clusterIndices.first;
      if (index is int && index >= 0 && index < contacts.length) {
        unawaited(_animateToGrid(contacts[index].latest.location, zoom: 15));
      }
      return;
    }
    final index = symbol.data?['contactIndex'];
    if (index is int && index >= 0 && index < contacts.length) {
      unawaited(_showContact(contacts[index]));
    }
  }

  Future<void> _loadStyle() async {
    final style = await loadOfflineMapStyle();
    if (!mounted) return;
    setState(() {
      _sourceStyle = style;
      _cachedStyle = themedMapStyle(style, _mapColors!);
    });
  }

  Future<void> _prepareWeb() async {
    if (!kIsWeb) {
      if (mounted) setState(() => _webReady = true);
      return;
    }
    if (mounted) {
      setState(() => _webLoadStatus = 'Preparando o mapa offline...');
    }
    try {
      await MapLibreMap.ensureWebLibraryLoaded();
      if (mounted) {
        final cached = await isPmtilesArchiveCached();
        if (mounted) {
          setState(
            () => _webLoadStatus = cached
                ? 'Carregando o mapa offline...'
                : 'Baixando o mapa offline...',
          );
        }
      }
      await registerPmtilesProtocol();
      if (mounted) setState(() => _webReady = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _webLoadFailed = true;
          _webLoadStatus = 'Não foi possível carregar o mapa offline.';
        });
      }
    }
  }

  Future<void> _drawContacts() async {
    final map = controller;
    if (map == null || !mounted || !_styleReady) return;
    if (_drawing) {
      _redrawRequested = true;
      return;
    }
    _drawing = true;
    try {
      do {
        _redrawRequested = false;
        await _renderScene(map, _scene);
      } while (_redrawRequested && mounted && _styleReady);
    } finally {
      _drawing = false;
      if (_repositionRequested && mounted && _styleReady) {
        unawaited(_repositionContactMarkers(map));
      }
    }
  }

  Future<void> _refreshHoverPulse() async {
    final map = controller;
    if (map == null || !mounted || !_styleReady) return;
    if (_hoverPulseCircles.isNotEmpty) {
      try {
        await map.removeCircles(_hoverPulseCircles);
      } catch (_) {
        // A scene redraw may already have cleared these annotations.
      }
      _hoverPulseCircles.clear();
    }
    final callsign = widget.hoveredCallsign.trim().toUpperCase();
    if (callsign.isEmpty) {
      _hoverPulseTimer?.cancel();
      _hoverPulseTimer = null;
      return;
    }
    final markers = _renderedMarkers
        .where((rendered) {
          final marker = rendered.marker;
          final index = marker.contactIndex;
          return index != null &&
              !rendered.group.isCluster &&
              index < _scene.contacts.length &&
              _scene.contacts[index].latest.callsign.trim().toUpperCase() ==
                  callsign;
        })
        .map((rendered) => rendered.marker);
    for (final marker in markers) {
      final bounds = GridLocator.bounds(marker.grid);
      if (bounds == null) continue;
      for (var wave = 0; wave < 2; wave++) {
        _hoverPulseCircles.add(
          await map.addCircle(
            CircleOptions(
              geometry: LatLng(bounds.centerLatitude, bounds.centerLongitude),
              circleColor: marker.color,
              circleRadius: 7,
              circleOpacity: 0,
              circleStrokeColor: marker.color,
              circleStrokeWidth: 2.5,
              circleStrokeOpacity: wave == 0 ? 0.75 : 0,
            ),
          ),
        );
      }
    }
    if (_hoverPulseCircles.isEmpty) {
      _hoverPulseTimer?.cancel();
      _hoverPulseTimer = null;
      return;
    }
    if (_hoverPulseCircles.isNotEmpty && _hoverPulseTimer == null) {
      _hoverPulseTimer = Timer.periodic(
        const Duration(milliseconds: 45),
        (_) => unawaited(_animateHoverPulse()),
      );
    }
  }

  Future<void> _animateHoverPulse() async {
    final map = controller;
    if (map == null || !mounted || _hoverPulseCircles.isEmpty) return;
    _hoverPulseProgress = (_hoverPulseProgress + 0.035) % 1;
    for (var index = 0; index < _hoverPulseCircles.length; index++) {
      final circle = _hoverPulseCircles[index];
      final phase = index.isEven ? 0.0 : 0.5;
      final progress = (_hoverPulseProgress + phase) % 1;
      final radius = 7 + 18 * progress;
      final opacity = 0.75 * (1 - progress);
      try {
        await map.updateCircle(
          circle,
          CircleOptions(circleRadius: radius, circleStrokeOpacity: opacity),
        );
      } catch (_) {
        // The map can clear annotations while a redraw is in flight.
      }
    }
  }

  Future<void> _repositionContactMarkers(MapLibreMapController map) async {
    if (_renderedMarkers.isEmpty) return;
    if (_drawing || _repositioning) {
      _repositionRequested = true;
      return;
    }
    _repositioning = true;
    try {
      do {
        _repositionRequested = false;
        final orbitCenters = <String, math.Point<num>>{};
        for (final rendered in _renderedMarkers) {
          final marker = rendered.marker;
          if (rendered.group.isCluster ||
              marker.orbitCount <= 1 ||
              marker.orbitIndex == 0) {
            continue;
          }
          final bounds = GridLocator.bounds(marker.grid);
          if (bounds == null) continue;
          final center =
              orbitCenters[GridLocator.inspect(marker.grid).normalized] ??=
                  await map.toScreenLocation(rendered.group.position);
          final position = await _orbitPosition(
            map,
            center,
            marker.orbitIndex,
            marker.orbitCount,
          );
          if (rendered.circle != null) {
            await map.updateCircle(
              rendered.circle!,
              CircleOptions(geometry: position),
            );
          } else if (rendered.symbol != null) {
            await map.updateSymbol(
              rendered.symbol!,
              SymbolOptions(geometry: position),
            );
          }
        }
      } while (_repositionRequested && mounted);
    } finally {
      _repositioning = false;
    }
  }

  Future<LatLng> _orbitPosition(
    MapLibreMapController map,
    math.Point<num> center,
    int orbitIndex,
    int orbitCount,
  ) async {
    const minimumSeparation = 18.0;
    final angle = switch (orbitIndex) {
      1 => 0.0,
      2 => math.pi,
      3 => math.pi / 2,
      4 => -math.pi / 2,
      _ =>
        -math.pi / 2 +
            2 * math.pi * (orbitIndex - 5) / math.max(1, orbitCount - 4),
    };
    final radius = orbitIndex <= 4 ? minimumSeparation : 30.0;
    return map.toLatLng(
      math.Point(
        center.x + radius * math.cos(angle),
        center.y + radius * math.sin(angle),
      ),
    );
  }

  Future<List<_MarkerRenderGroup>> _markerGroups(
    MapLibreMapController map,
    ContactScene scene,
    List<ContactMarker> visibleMarkers,
  ) async {
    final contactMarkers = _orbitingMarkersVisible
        ? visibleMarkers.where((marker) => marker.contactIndex != null)
        : scene.markers.where((marker) => marker.contactIndex != null);
    final groups = <_MarkerRenderGroup>[];
    final projected = <_ProjectedMarker>[];
    for (final marker in contactMarkers) {
      final bounds = GridLocator.bounds(marker.grid);
      if (bounds == null) continue;
      final position = LatLng(bounds.centerLatitude, bounds.centerLongitude);
      math.Point<num> screen;
      try {
        screen = await map.toScreenLocation(position);
      } catch (_) {
        // Some platform fakes do not expose screen projection. The geographic
        // fallback keeps scene rendering testable without changing clustering
        // in a real map instance.
        screen = math.Point(
          position.longitude * 100000,
          position.latitude * 100000,
        );
      }
      projected.add(
        _ProjectedMarker(marker: marker, position: position, screen: screen),
      );
    }

    if (_orbitingMarkersVisible) {
      for (final item in projected) {
        groups.add(
          _MarkerRenderGroup(
            marker: item.marker,
            position: item.position,
            contactIndices: [item.marker.contactIndex!],
          ),
        );
      }
    } else {
      final remaining = projected.toList();
      while (remaining.isNotEmpty) {
        final seed = remaining.removeAt(0);
        final members = <_ProjectedMarker>[seed];
        for (var i = remaining.length - 1; i >= 0; i--) {
          final candidate = remaining[i];
          final dx = candidate.screen.x - seed.screen.x;
          final dy = candidate.screen.y - seed.screen.y;
          if (math.sqrt(dx * dx + dy * dy) <= 48) {
            members.add(candidate);
            remaining.removeAt(i);
          }
        }
        final latitude =
            members
                .map((member) => member.position.latitude)
                .reduce((a, b) => a + b) /
            members.length;
        final longitude =
            members
                .map((member) => member.position.longitude)
                .reduce((a, b) => a + b) /
            members.length;
        groups.add(
          _MarkerRenderGroup(
            marker: seed.marker,
            position: LatLng(latitude, longitude),
            contactIndices: members
                .map((member) => member.marker.contactIndex!)
                .toList(),
          ),
        );
      }
    }

    for (final marker in visibleMarkers.where(
      (marker) => marker.contactIndex == null,
    )) {
      final bounds = GridLocator.bounds(marker.grid);
      if (bounds == null) continue;
      groups.add(
        _MarkerRenderGroup(
          marker: marker,
          position: LatLng(bounds.centerLatitude, bounds.centerLongitude),
        ),
      );
    }
    return groups;
  }

  Future<void> _renderScene(
    MapLibreMapController map,
    ContactScene scene,
  ) async {
    final colors = _mapColors!;
    final mapColorsChanged = _appliedMapColors != colors;
    if (mapColorsChanged) {
      for (final layer in themedMapPaint(_sourceStyle!, colors).entries) {
        await map.setLayerProperties(layer.key, layer.value);
        if (!mounted || !_styleReady) return;
      }
      _appliedMapColors = colors;
      // Text images bake in the theme colors; generate fresh images on redraw.
      _labelImages.clear();
      _warningImages.clear();
    }
    final visibleMarkers = scene.markers
        .where(
          (marker) =>
              marker.kind == MarkerKind.selectedContact ||
              _orbitingMarkersVisible ||
              marker.orbitCount == 1 ||
              marker.orbitIndex == 0,
        )
        .toList();
    final markerGroups = await _markerGroups(map, scene, visibleMarkers);
    final markersChanged =
        mapColorsChanged || !_sameRenderedMarkers(markerGroups);
    final linesChanged =
        _renderedShowLines != widget.settings.showLines ||
        !_sameRoutes(scene.routes);
    final precisionChanged =
        markersChanged ||
        _renderedShowPrecision != widget.settings.showPrecision;
    if (markersChanged) {
      await map.clearCircles();
      await map.clearSymbols();
    }
    if (linesChanged) {
      await map.clearLines();
    }
    if (precisionChanged) {
      await map.clearFills();
    }
    if (precisionChanged && widget.settings.showPrecision) {
      await _drawPrecisionAreas(map, scene);
    }
    await _drawElevation();
    if (linesChanged) {
      for (final route in scene.routes) {
        await map.addLine(
          LineOptions(
            geometry: route.grids.map((grid) {
              final bounds = GridLocator.bounds(grid)!;
              return LatLng(bounds.centerLatitude, bounds.centerLongitude);
            }).toList(),
            lineColor: route.color,
            lineOpacity: route.opacity,
            lineWidth: 3.5,
          ),
        );
      }
      await _drawDistances(map, scene);
    }
    if (markersChanged) {
      final orbitCenters = <String, math.Point<num>>{};
      final renderedMarkers = <_RenderedContactMarker>[];
      for (final group in markerGroups) {
        final marker = group.marker;
        final bounds = GridLocator.bounds(marker.grid);
        if (bounds == null) continue;
        var position = group.position;
        if (!group.isCluster &&
            marker.orbitCount > 1 &&
            marker.orbitIndex > 0) {
          final grid = GridLocator.inspect(marker.grid).normalized;
          final center = orbitCenters[grid] ??= await map.toScreenLocation(
            group.position,
          );
          position = await _orbitPosition(
            map,
            center,
            marker.orbitIndex,
            marker.orbitCount,
          );
        }
        if (group.isCluster) {
          final imageId = await _clusterImage(map, group.contactIndices.length);
          await map.setSymbolIconAllowOverlap(true);
          await map.setSymbolIconIgnorePlacement(true);
          final symbol = await map.addSymbol(
            SymbolOptions(
              geometry: position,
              iconImage: imageId,
              iconSize: 0.8,
            ),
            {'clusterIndices': group.contactIndices},
          );
          renderedMarkers.add(_RenderedContactMarker(group, symbol: symbol));
          continue;
        }
        if (marker.warning) {
          final imageId =
              'station-warning-${marker.color}-${mapColor(colors.surface)}';
          if (!_warningImages.contains(imageId)) {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            final path = Path()
              ..moveTo(3, 4)
              ..lineTo(29, 4)
              ..lineTo(16, 28)
              ..close();
            canvas.drawPath(
              path,
              Paint()
                ..color = Color(
                  int.parse(marker.color.replaceFirst('#', 'FF'), radix: 16),
                ),
            );
            canvas.drawPath(
              path,
              Paint()
                ..color = colors.surface
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            );
            final picture = recorder.endRecording();
            final bitmap = await picture.toImage(32, 32);
            final bytes = await bitmap.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await map.addImage(imageId, bytes!.buffer.asUint8List());
            bitmap.dispose();
            picture.dispose();
            _warningImages.add(imageId);
          }
          await map.setSymbolIconAllowOverlap(true);
          await map.setSymbolIconIgnorePlacement(true);
          final symbol = await map.addSymbol(
            SymbolOptions(
              geometry: position,
              iconImage: imageId,
              iconSize: 0.65,
            ),
            {'contactIndex': marker.contactIndex},
          );
          renderedMarkers.add(_RenderedContactMarker(group, symbol: symbol));
          continue;
        }
        final circle = await map.addCircle(
          CircleOptions(
            geometry: position,
            circleColor: marker.color,
            circleRadius: marker.radius,
            circleBlur: 0,
            circleOpacity: 1,
            circleStrokeColor: mapColor(colors.surface),
            circleStrokeWidth: 2,
            circleStrokeOpacity: 1,
          ),
          {'contactIndex': marker.contactIndex},
        );
        renderedMarkers.add(_RenderedContactMarker(group, circle: circle));
        assert(circle.id.isNotEmpty);
      }
      _renderedMarkers = renderedMarkers;
    }
    final callsignsKey = _callsignsKey(scene);
    if (callsignsKey != _renderedCallsignsKey ||
        _callsignLayerReady != widget.settings.showCallsigns) {
      await _drawCallsigns(map, scene);
    }
    _renderedShowLines = widget.settings.showLines;
    _renderedShowPrecision = widget.settings.showPrecision;
    _renderedRoutes = List.unmodifiable(scene.routes);
    _renderedCallsignsKey = callsignsKey;
    await _refreshHoverPulse();
  }

  bool _sameRenderedMarkers(List<_MarkerRenderGroup> groups) {
    if (_renderedMarkers.length != groups.length) return false;
    for (var i = 0; i < groups.length; i++) {
      final previous = _renderedMarkers[i].marker;
      final current = groups[i].marker;
      final previousIndices = _renderedMarkers[i].group.contactIndices;
      final currentIndices = groups[i].contactIndices;
      if (previous.grid != current.grid ||
          previous.kind != current.kind ||
          previous.contactIndex != current.contactIndex ||
          previous.stationType != current.stationType ||
          previous.energy != current.energy ||
          previous.warning != current.warning ||
          previous.orbitIndex != current.orbitIndex ||
          previous.orbitCount != current.orbitCount ||
          previousIndices.length != currentIndices.length) {
        return false;
      }
      for (var j = 0; j < currentIndices.length; j++) {
        if (previousIndices[j] != currentIndices[j]) return false;
      }
    }
    return true;
  }

  bool _sameRoutes(List<ContactRoute> routes) {
    if (_renderedRoutes.length != routes.length) return false;
    for (var i = 0; i < routes.length; i++) {
      final previous = _renderedRoutes[i];
      final current = routes[i];
      if (previous.missingVia != current.missingVia ||
          previous.grids.length != current.grids.length) {
        return false;
      }
      for (var j = 0; j < current.grids.length; j++) {
        if (previous.grids[j] != current.grids[j]) return false;
      }
    }
    return true;
  }

  String _callsignsKey(ContactScene scene) => [
    widget.settings.showCallsigns,
    _orbitingMarkersVisible,
    controller?.cameraPosition?.zoom.toStringAsFixed(2) ?? 'unknown-zoom',
    ..._renderedMarkers.map(
      (rendered) => rendered.group.contactIndices.join(','),
    ),
    ...scene
        .callsignContacts(widget.operatorCallsign)
        .map(
          (contact) => '${contact.latest.callsign}|${contact.latest.location}',
        ),
  ].join(';');

  Future<ElevationGrid?> _loadElevation() async {
    try {
      final grid = await ElevationGrid.load();
      if (mounted) {
        _elevationGrid = grid;
        if (widget.settings.showElevation) {
          _scheduleElevationRedraw(immediate: true);
        }
      }
      return grid;
    } catch (_) {
      return null;
    }
  }

  void _scheduleElevationRedraw({bool immediate = false}) {
    if (!widget.settings.showElevation || !mounted || !_styleReady) return;
    _elevationDebounce?.cancel();
    if (immediate) {
      unawaited(_drawElevation());
    } else {
      _elevationDebounce = Timer(const Duration(milliseconds: 140), () {
        if (mounted) unawaited(_drawElevation());
      });
    }
  }

  Future<void> _drawElevation() async {
    final map = controller;
    if (map == null || !mounted || !_styleReady) {
      return;
    }
    if (!widget.settings.showElevation) {
      _updateElevationRange(null);
      if (_elevationLayerReady) {
        await map.setGeoJsonSource('elevation-grid', _emptyFeatureCollection());
      }
      return;
    }
    if (_elevationDrawing) {
      _elevationRedrawRequested = true;
      return;
    }
    _elevationDrawing = true;
    try {
      do {
        _elevationRedrawRequested = false;
        final grid = _elevationGrid ?? await _elevationFuture;
        if (grid == null || !mounted || !widget.settings.showElevation) return;
        final visible = await map.getVisibleRegion();
        final samples = grid.samplesIn(
          minLatitude: visible.southwest.latitude,
          maxLatitude: visible.northeast.latitude,
          minLongitude: visible.southwest.longitude,
          maxLongitude: visible.northeast.longitude,
        );
        if (samples.isEmpty) {
          _updateElevationRange(null);
          if (_elevationLayerReady) {
            await map.setGeoJsonSource(
              'elevation-grid',
              _emptyFeatureCollection(),
            );
          }
          continue;
        }
        var minimum = samples.first.meters;
        var maximum = minimum;
        for (final sample in samples.skip(1)) {
          if (sample.meters < minimum) minimum = sample.meters;
          if (sample.meters > maximum) maximum = sample.meters;
        }
        _updateElevationRange(ElevationRange(minimum, maximum));
        final camera = await map.queryCameraPosition();
        final zoom = camera?.zoom ?? 12;
        final latitude =
            (visible.southwest.latitude + visible.northeast.latitude) / 2;
        final metersPerPixel =
            156543.03392 * _cosine(latitude) / (1 << zoom.round());
        final intensity = metersPerPixel < 40 ? 1.15 : 1.35;
        final data = <String, dynamic>{
          'type': 'FeatureCollection',
          'features': samples
              .map(
                (sample) => <String, dynamic>{
                  'type': 'Feature',
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [sample.longitude, sample.latitude],
                  },
                  'properties': {
                    // The native heatmap aggregates nearby samples instead
                    // of rendering one visible dot per elevation cell.
                    'weight': maximum <= minimum
                        ? .5
                        : .2 +
                              ((sample.meters - minimum) /
                                      (maximum - minimum)) *
                                  .8,
                  },
                },
              )
              .toList(),
        };
        if (_elevationLayerReady) {
          await map.setGeoJsonSource('elevation-grid', data);
        } else {
          await map.addGeoJsonSource('elevation-grid', data);
          await map.addHeatmapLayer(
            'elevation-grid',
            'elevation-grid-layer',
            HeatmapLayerProperties(
              heatmapRadius: const [
                'interpolate',
                ['linear'],
                ['zoom'],
                6,
                34,
                8,
                52,
                12,
                78,
                15,
                112,
              ],
              heatmapWeight: const ['get', 'weight'],
              heatmapIntensity: intensity,
              heatmapColor: const [
                'interpolate',
                ['linear'],
                ['heatmap-density'],
                0,
                'rgba(21, 101, 192, 0)',
                .15,
                '#1565c0',
                .35,
                '#00a9c7',
                .55,
                '#43a047',
                .75,
                '#ffd600',
                1,
                '#d32f2f',
              ],
              heatmapOpacity: .42,
            ),
          );
          _elevationLayerReady = true;
        }
      } while (_elevationRedrawRequested && mounted);
    } finally {
      _elevationDrawing = false;
    }
  }

  double _cosine(double degrees) {
    final radians = degrees * 3.141592653589793 / 180;
    // A short Taylor approximation avoids adding another dependency here.
    final squared = radians * radians;
    return 1 - squared / 2 + squared * squared / 24;
  }

  Map<String, dynamic> _emptyFeatureCollection() => const {
    'type': 'FeatureCollection',
    'features': <dynamic>[],
  };

  Future<void> _drawPrecisionAreas(
    MapLibreMapController map,
    ContactScene scene,
  ) async {
    final seen = <String>{};
    final areas = <FillOptions>[];
    final grids = [
      ...scene.markers.map((marker) => marker.grid),
      ...scene.routes.expand((route) => route.grids),
    ];
    for (final rawGrid in grids) {
      final grid = GridLocator.inspect(rawGrid).normalized;
      if (!seen.add(grid)) continue;
      final bounds = GridLocator.bounds(grid);
      if (bounds == null) continue;
      // Log coordinates are Maidenhead grids, so their precision is an area
      // (the grid tile) rather than a radial accuracy value.
      areas.add(
        FillOptions(
          geometry: [
            [
              LatLng(bounds.minLatitude, bounds.minLongitude),
              LatLng(bounds.minLatitude, bounds.maxLongitude),
              LatLng(bounds.maxLatitude, bounds.maxLongitude),
              LatLng(bounds.maxLatitude, bounds.minLongitude),
              LatLng(bounds.minLatitude, bounds.minLongitude),
            ],
          ],
          fillColor: '#42A5F5',
          fillOpacity: 0.12,
          fillOutlineColor: '#64B5F6',
        ),
      );
    }
    if (areas.isNotEmpty) await map.addFills(areas);
  }

  Future<String> _labelImage(
    MapLibreMapController map,
    String label, {
    required double fontSize,
  }) async {
    final cacheKey = '$fontSize|$label';
    var imageId = _labelImages[cacheKey];
    if (imageId == null) {
      imageId = 'map-label-${_labelImages.length}';
      // Rasterize locally: the offline map has no network glyph source.
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: _mapColors!.onSurface,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(2);
      final size = Size(painter.width + 12, painter.height + 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
        Paint()..color = _mapColors!.surface.withValues(alpha: 0.94),
      );
      painter.paint(canvas, const Offset(6, 3));
      final picture = recorder.endRecording();
      final bitmap = await picture.toImage(
        (size.width * 2).ceil(),
        (size.height * 2).ceil(),
      );
      final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      await map.addImage(imageId, bytes!.buffer.asUint8List());
      bitmap.dispose();
      picture.dispose();
      painter.dispose();
      _labelImages[cacheKey] = imageId;
    }
    return imageId;
  }

  Future<String> _clusterImage(MapLibreMapController map, int count) async {
    var imageId = _clusterImages[count];
    if (imageId != null) return imageId;
    imageId = 'map-cluster-$count';
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(const Offset(16, 16), 14, Paint()..color = Colors.black);
    final painter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(16 - painter.width / 2, 16 - painter.height / 2),
    );
    final picture = recorder.endRecording();
    final bitmap = await picture.toImage(32, 32);
    final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    await map.addImage(imageId, bytes!.buffer.asUint8List());
    bitmap.dispose();
    picture.dispose();
    painter.dispose();
    _clusterImages[count] = imageId;
    return imageId;
  }

  Future<math.Point<num>> _screenPosition(
    MapLibreMapController map,
    LatLng position,
  ) async {
    try {
      return await map.toScreenLocation(position);
    } catch (_) {
      return math.Point(
        position.longitude * 100000,
        position.latitude * 100000,
      );
    }
  }

  Future<void> _drawCallsigns(
    MapLibreMapController map,
    ContactScene scene,
  ) async {
    if (!widget.settings.showCallsigns && !_callsignLayerReady) return;
    final features = <Map<String, dynamic>>[];
    if (widget.settings.showCallsigns) {
      final candidates = <_CallsignLabelCandidate>[];
      final operatorCallsign = widget.operatorCallsign.trim().toUpperCase();
      if (!_orbitingMarkersVisible) {
        for (final rendered in _renderedMarkers) {
          final indices = rendered.group.contactIndices;
          if (indices.isEmpty) continue;
          final callsigns = indices
              .map((index) => scene.contacts[index].latest.callsign)
              .where(
                (callsign) => callsign.trim().toUpperCase() != operatorCallsign,
              )
              .toList();
          if (callsigns.isEmpty) continue;
          candidates.add(
            _CallsignLabelCandidate(
              position: rendered.group.position,
              callsigns: callsigns,
              screen: await _screenPosition(map, rendered.group.position),
            ),
          );
        }
      } else {
        final contactsByGrid = <String, List<MapContact>>{};
        for (final contact in scene.callsignContacts(widget.operatorCallsign)) {
          final grid = GridLocator.inspect(contact.latest.location).normalized;
          contactsByGrid.putIfAbsent(grid, () => []).add(contact);
        }
        for (final contacts in contactsByGrid.values) {
          final bounds = contacts.first.bounds;
          if (bounds == null) continue;
          final position = LatLng(
            bounds.centerLatitude,
            bounds.centerLongitude,
          );
          candidates.add(
            _CallsignLabelCandidate(
              position: position,
              callsigns: contacts
                  .map((contact) => contact.latest.callsign)
                  .toList(),
              screen: await _screenPosition(map, position),
            ),
          );
        }
      }
      final remaining = candidates.toList();
      while (remaining.isNotEmpty) {
        final seed = remaining.removeAt(0);
        final members = <_CallsignLabelCandidate>[seed];
        for (var i = remaining.length - 1; i >= 0; i--) {
          final candidate = remaining[i];
          final dx = candidate.screen.x - seed.screen.x;
          final dy = candidate.screen.y - seed.screen.y;
          if (math.sqrt(dx * dx + dy * dy) <= 72) {
            members.add(candidate);
            remaining.removeAt(i);
          }
        }
        final latitude =
            members
                .map((member) => member.position.latitude)
                .reduce((a, b) => a + b) /
            members.length;
        final longitude =
            members
                .map((member) => member.position.longitude)
                .reduce((a, b) => a + b) /
            members.length;
        final imageId = await _labelImage(
          map,
          formatCallsignsLimited(members.expand((member) => member.callsigns)),
          fontSize: 12,
        );
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
          'properties': {'image': imageId},
        });
      }
    }
    final data = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };
    if (_callsignLayerReady) {
      await map.setGeoJsonSource('contact-callsigns', data);
    } else {
      await map.addGeoJsonSource('contact-callsigns', data);
      await map.addSymbolLayer(
        'contact-callsigns',
        'contact-callsign-labels',
        const SymbolLayerProperties(
          iconImage: ['get', 'image'],
          iconSize: [
            'interpolate',
            ['linear'],
            ['zoom'],
            11,
            0.4,
            15,
            0.625,
          ],
          iconAnchor: 'bottom',
          iconOffset: [0, -18],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
        enableInteraction: false,
      );
      _callsignLayerReady = true;
    }
  }

  Future<void> _drawDistances(
    MapLibreMapController map,
    ContactScene scene,
  ) async {
    final features = <Map<String, dynamic>>[];
    for (final distance in routeDistances(scene.routes)) {
      final imageId = await _labelImage(map, distance.label, fontSize: 10);
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [distance.longitude, distance.latitude],
        },
        'properties': {'image': imageId},
      });
    }
    final data = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };
    if (_distanceLayerReady) {
      await map.setGeoJsonSource('route-distances', data);
    } else {
      await map.addGeoJsonSource('route-distances', data);
      await map.addSymbolLayer(
        'route-distances',
        'route-distance-labels',
        const SymbolLayerProperties(
          iconImage: ['get', 'image'],
          iconSize: [
            'interpolate',
            ['linear'],
            ['zoom'],
            11,
            0.4,
            15,
            0.625,
          ],
          iconAllowOverlap: false,
          iconIgnorePlacement: false,
        ),
        minzoom: 11,
        enableInteraction: false,
      );
      _distanceLayerReady = true;
    }
  }

  Future<void> _showContact(MapContact contact) async {
    final grid = _elevationGrid ?? await _elevationFuture;
    if (!mounted) return;
    final location = GridLocator.bounds(contact.latest.location);
    final altitude = location == null
        ? null
        : grid?.elevationAt(location.centerLatitude, location.centerLongitude);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.primary,
                      child: const Icon(Icons.cell_tower, size: 25),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.latest.callsign,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            contact.latest.operatorName,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onDisconnect != null)
                      IconButton(
                        tooltip: 'Desligar estação da rede',
                        icon: const Icon(Icons.power_settings_new),
                        color: colors.onErrorContainer,
                        style: IconButton.styleFrom(
                          backgroundColor: colors.errorContainer,
                        ),
                        onPressed: () async {
                          await widget.onDisconnect!(contact.latest);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _detailChip(Icons.grid_3x3, contact.latest.location),
                    _detailChip(
                      Icons.radio,
                      '${contact.latest.frequency == 'simplex' ? 'Simplex' : 'Repetidora'} · ${contactFrequencyMhz(contact.latest)} MHz',
                    ),
                    _detailChip(
                      Icons.terrain,
                      altitude == null
                          ? 'Altitude indisponível'
                          : '${altitude.round()} m',
                    ),
                    _detailChip(Icons.bolt, '${contact.latest.powerWatts} W'),
                    _detailChip(Icons.cell_tower, switch (contact
                        .latest
                        .stationType
                        .trim()
                        .toUpperCase()) {
                      'P' => 'Portátil',
                      'M' => 'Móvel',
                      'F' => 'Fixa',
                      _ => contact.latest.stationType,
                    }),
                    _detailChip(Icons.swap_calls, switch (contact.latest.traffic
                        .trim()
                        .toUpperCase()) {
                      'S' => 'Sem tráfego',
                      'C' => 'Com tráfego',
                      _ => contact.latest.traffic,
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Histórico do ponto',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Primeiro contato: ${_formatDate(contact.first.createdAt)}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                Text(
                  'Último contato: ${_formatDate(contact.last.createdAt)}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailChip(IconData icon, String label) => Chip(
    avatar: Icon(icon, size: 16),
    label: Text(label),
    visualDensity: VisualDensity.compact,
    side: BorderSide.none,
  );

  String _formatDate(DateTime value) => TimeDisplay.of(context).format(value);

  String? _cachedStyle;
  String? _sourceStyle;
  bool _webReady = false;
  bool _webLoadFailed = false;
  String _webLoadStatus = 'Carregando o mapa...';
}

Future<String> loadOfflineMapStyle() async {
  final nativeStyle = await prepareNativeOfflineMapStyle();
  return nativeStyle ??
      rootBundle.loadString('assets/maps/santa-maria-style.json');
}
