import 'dart:async';
import 'dart:ui' as ui;
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
    this.onExportPng,
  });
  final List<LogEntry> entries;
  final String operatorGrid;
  final String operatorCallsign;
  final String focusGrid;
  final int focusRequest;
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
  final Future<void> Function(Uint8List bytes)? onExportPng;

  @override
  State<OfflineContactsMap> createState() => _OfflineContactsMapState();
}

class _OfflineContactsMapState extends State<OfflineContactsMap>
    with WidgetsBindingObserver {
  MapLibreMapController? controller;
  List<MapContact> contacts = const [];
  ColorScheme? _mapColors;
  bool _styleReady = false;
  bool _initialCameraSet = false;
  late ContactScene _scene;
  Timer? _expiryTimer;
  bool _drawing = false;
  bool _redrawRequested = false;
  bool _distanceLayerReady = false;
  bool _callsignLayerReady = false;
  final _labelImages = <String, String>{};
  final _warningImages = <String>{};
  final _mapBearing = ValueNotifier<double>(0);
  final _elevationRange = ValueNotifier<ElevationRange?>(null);
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
    if (_mapColors == colors) return;
    _mapColors = colors;
    final source = _sourceStyle;
    if (source != null) {
      _styleReady = false;
      _cachedStyle = themedMapStyle(source, colors);
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
    if (oldWidget.entries != widget.entries ||
        oldWidget.operatorGrid != widget.operatorGrid ||
        oldWidget.operatorCallsign != widget.operatorCallsign ||
        oldWidget.mergePrecision != widget.mergePrecision ||
        oldWidget.lastOnly != widget.lastOnly ||
        oldWidget.selectedMode != widget.selectedMode ||
        oldWidget.selectedFrequencyMhz != widget.selectedFrequencyMhz ||
        oldWidget.settings != widget.settings ||
        oldWidget.sessionStartedAt != widget.sessionStartedAt ||
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
        left: 80,
        top: 80,
        right: 80,
        bottom: 80,
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
        13,
      ),
    );
  }

  void _refreshContacts() {
    final now = DateTime.now().toUtc();
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
    );
    contacts = _scene.contacts;
    _expiryTimer?.cancel();
    _elevationDebounce?.cancel();
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
    ).nextChange;
    if (next != null) {
      _expiryTimer = Timer(next.difference(now), () {
        if (!mounted) return;
        _refreshContacts();
        _drawContacts();
      });
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
      return const Center(child: CircularProgressIndicator());
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
            onStyleLoadedCallback: () {
              _distanceLayerReady = false;
              _callsignLayerReady = false;
              _labelImages.clear();
              _warningImages.clear();
              _elevationLayerReady = false;
              _elevationRange.value = null;
              _styleReady = true;
              _drawContacts();
              _fitInitialPoints();
            },
          ),
        ),
        if (widget.settings.showCompass)
          Positioned(
            left: 12,
            bottom: 12,
            child: ValueListenableBuilder<double>(
              valueListenable: _mapBearing,
              builder: (context, bearing, child) =>
                  MapCompass(bearing: bearing, onTap: _resetMapNorth),
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
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
                      _animateToGrid(widget.operatorGrid, zoom: 14),
                ),
                IconButton(
                  tooltip: 'Exportar mapa como PNG',
                  icon: const Icon(Icons.image_outlined),
                  onPressed: controller == null || widget.onExportPng == null
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
              ],
            ),
          ),
        ),
        if (widget.settings.showElevation)
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
    value.onCircleTapped.add(_onCircleTapped);
    value.onSymbolTapped.add(_onSymbolTapped);
    value.addListener(_onMapControllerChanged);
    _onMapControllerChanged();
  }

  void _onCameraMove(CameraPosition position) {
    if (!mounted) return;
    _updateMapBearing(position.bearing);
    _scheduleElevationRedraw();
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
      return;
    }
    // Keep the compass working on platform implementations that do not cache
    // camera positions unless tracking is enabled.
    map.queryCameraPosition().then((position) {
      if (mounted && position != null) {
        _updateMapBearing(position.bearing);
        _scheduleElevationRedraw(immediate: true);
      }
    });
  }

  void _updateMapBearing(double rawBearing) {
    final bearing = normalizeBearing(rawBearing);
    if ((_mapBearing.value - bearing).abs() >= 0.1) {
      _mapBearing.value = bearing;
    }
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
    await MapLibreMap.ensureWebLibraryLoaded();
    await registerPmtilesProtocol();
    if (mounted) setState(() => _webReady = true);
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
    }
  }

  Future<void> _renderScene(
    MapLibreMapController map,
    ContactScene scene,
  ) async {
    final colors = _mapColors!;
    await map.clearCircles();
    await map.clearSymbols();
    await map.clearLines();
    await map.clearFills();
    if (widget.settings.showPrecision) {
      await _drawPrecisionAreas(map, scene);
    }
    await _drawElevation();
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
    for (final marker in scene.markers) {
      final bounds = GridLocator.bounds(marker.grid);
      if (bounds == null) continue;
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
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          await map.addImage(imageId, bytes!.buffer.asUint8List());
          bitmap.dispose();
          picture.dispose();
          _warningImages.add(imageId);
        }
        await map.setSymbolIconAllowOverlap(true);
        await map.setSymbolIconIgnorePlacement(true);
        await map.addSymbol(
          SymbolOptions(
            geometry: LatLng(bounds.centerLatitude, bounds.centerLongitude),
            iconImage: imageId,
            iconSize: 0.65,
          ),
          {'contactIndex': marker.contactIndex},
        );
        continue;
      }
      final circle = await map.addCircle(
        CircleOptions(
          geometry: LatLng(bounds.centerLatitude, bounds.centerLongitude),
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
      assert(circle.id.isNotEmpty);
    }
    await _drawCallsigns(map, scene);
  }

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
      _elevationRange.value = null;
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
          _elevationRange.value = null;
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
        _elevationRange.value = ElevationRange(minimum, maximum);
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
                8,
                18,
                12,
                28,
                15,
                42,
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
              heatmapOpacity: .60,
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

  Future<String> _labelImage(MapLibreMapController map, String label) async {
    var imageId = _labelImages[label];
    if (imageId == null) {
      imageId = 'map-label-${_labelImages.length}';
      // Rasterize locally: the offline map has no network glyph source.
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 16,
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
      _labelImages[label] = imageId;
    }
    return imageId;
  }

  Future<void> _drawCallsigns(
    MapLibreMapController map,
    ContactScene scene,
  ) async {
    if (!widget.settings.showCallsigns && !_callsignLayerReady) return;
    final features = <Map<String, dynamic>>[];
    if (widget.settings.showCallsigns) {
      for (final contact in scene.callsignContacts(widget.operatorCallsign)) {
        final bounds = contact.bounds;
        if (bounds == null) continue;
        final imageId = await _labelImage(
          map,
          contact.latest.callsign.trim().toUpperCase(),
        );
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [bounds.centerLongitude, bounds.centerLatitude],
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
          iconOffset: [0, -12],
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
      final imageId = await _labelImage(map, distance.label);
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
                if (widget.onDisconnect != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Desligar estação da rede'),
                    onPressed: () async {
                      await widget.onDisconnect!(contact.latest);
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                ],
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
}

Future<String> loadOfflineMapStyle() async {
  final nativeStyle = await prepareNativeOfflineMapStyle();
  return nativeStyle ??
      rootBundle.loadString('assets/maps/santa-maria-style.json');
}
