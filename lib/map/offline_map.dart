import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../data/database.dart';
import '../grid_locator.dart';
import 'contact_aggregation.dart';
import 'contact_scene.dart';
import 'map_settings.dart';
import 'route_distance.dart';
import 'map_palette.dart';
import 'map_compass.dart';
import 'pmtiles_registration_stub.dart'
    if (dart.library.js_interop) 'pmtiles_registration_web.dart';
import 'offline_map_style_stub.dart'
    if (dart.library.io) 'offline_map_style_io.dart';

class OfflineContactsMap extends StatefulWidget {
  const OfflineContactsMap({
    super.key,
    required this.entries,
    required this.operatorGrid,
    this.focusGrid = '',
    this.focusRequest = 0,
    this.mergePrecision = true,
    this.lastOnly = false,
    this.maxAgeHours = 24,
    this.entriesLoaded = true,
    this.selectedMode = 'repeater',
    this.selectedFrequencyMhz = 145.37,
    this.settings = const MapSettings(),
    this.onSettingsChanged,
  });
  final List<LogEntry> entries;
  final String operatorGrid;
  final String focusGrid;
  final int focusRequest;
  final bool mergePrecision;
  final bool lastOnly;
  final int maxAgeHours;
  final bool entriesLoaded;
  final String selectedMode;
  final double selectedFrequencyMhz;
  final MapSettings settings;
  final ValueChanged<MapSettings>? onSettingsChanged;

  @override
  State<OfflineContactsMap> createState() => _OfflineContactsMapState();
}

class _OfflineContactsMapState extends State<OfflineContactsMap> {
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
  final _distanceImages = <String, String>{};
  final _mapBearing = ValueNotifier<double>(0);

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
    _refreshContacts();
    _loadStyle();
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
        oldWidget.mergePrecision != widget.mergePrecision ||
        oldWidget.lastOnly != widget.lastOnly ||
        oldWidget.selectedMode != widget.selectedMode ||
        oldWidget.selectedFrequencyMhz != widget.selectedFrequencyMhz ||
        oldWidget.settings != widget.settings ||
        oldWidget.maxAgeHours != widget.maxAgeHours) {
      _refreshContacts();
      _drawContacts();
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

  Future<void> _animateToGrid(String value) async {
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
      operatorGrid: widget.operatorGrid,
      repeaterGrid: widget.settings.repeaterGrid,
      selectedMode: widget.selectedMode,
      selectedFrequencyMhz: widget.selectedFrequencyMhz,
      showAll: widget.settings.showAll,
      showLines: widget.settings.showLines,
      mergePrecision: widget.mergePrecision,
      lastOnly: widget.lastOnly,
    );
    contacts = _scene.contacts;
    _expiryTimer?.cancel();
    final expirations =
        widget.entries
            .map(
              (e) => e.createdAt
                  .add(Duration(hours: widget.maxAgeHours))
                  .add(const Duration(milliseconds: 1)),
            )
            .where((time) => time.isAfter(now))
            .toList()
          ..sort();
    if (expirations.isNotEmpty) {
      _expiryTimer = Timer(expirations.first.difference(now), () {
        if (!mounted) return;
        _refreshContacts();
        _drawContacts();
      });
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    final map = controller;
    map?.onCircleTapped.remove(_onCircleTapped);
    map?.removeListener(_onMapControllerChanged);
    _mapBearing.dispose();
    super.dispose();
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
            minMaxZoomPreference: const MinMaxZoomPreference(8, 15),
            trackCameraPosition: true,
            annotationOrder: const [
              AnnotationType.fill,
              AnnotationType.line,
              AnnotationType.symbol,
              AnnotationType.circle,
            ],
            cameraTargetBounds: CameraTargetBounds(
              LatLngBounds(
                southwest: const LatLng(-30.15, -54.00),
                northeast: const LatLng(-29.55, -53.55),
              ),
            ),
            compassEnabled: false,
            myLocationEnabled: false,
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            onStyleLoadedCallback: () {
              _distanceLayerReady = false;
              _distanceImages.clear();
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
                  tooltip: 'Mostrar linhas de distância',
                  isSelected: widget.settings.showLines,
                  color: widget.settings.showLines
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  icon: const Icon(Icons.straighten),
                  onPressed: () => widget.onSettingsChanged?.call(
                    MapSettings(
                      showLines: !widget.settings.showLines,
                      showAll: widget.settings.showAll,
                      showCompass: widget.settings.showCompass,
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
                      showCompass: widget.settings.showCompass,
                      repeaterGrid: widget.settings.repeaterGrid,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mostrar todas as frequências',
                  isSelected: widget.settings.showAll,
                  color: widget.settings.showAll
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  icon: const Icon(Icons.cell_tower),
                  onPressed: () => widget.onSettingsChanged?.call(
                    MapSettings(
                      showLines: widget.settings.showLines,
                      showAll: !widget.settings.showAll,
                      showPrecision: widget.settings.showPrecision,
                      showCompass: widget.settings.showCompass,
                      repeaterGrid: widget.settings.repeaterGrid,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onMapCreated(MapLibreMapController value) {
    controller = value;
    value.onCircleTapped.add(_onCircleTapped);
    value.addListener(_onMapControllerChanged);
    _onMapControllerChanged();
  }

  void _onCameraMove(CameraPosition position) {
    if (!mounted) return;
    _updateMapBearing(position.bearing);
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
      return;
    }
    // Keep the compass working on platform implementations that do not cache
    // camera positions unless tracking is enabled.
    map.queryCameraPosition().then((position) {
      if (mounted && position != null) _updateMapBearing(position.bearing);
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
      _showContact(contacts[index]);
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
    await map.clearLines();
    await map.clearFills();
    if (widget.settings.showPrecision) {
      await _drawPrecisionAreas(map, scene);
    }
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
  }

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

  Future<void> _drawDistances(
    MapLibreMapController map,
    ContactScene scene,
  ) async {
    final features = <Map<String, dynamic>>[];
    for (final distance in routeDistances(scene.routes)) {
      final label = distance.label;
      var imageId = _distanceImages[label];
      if (imageId == null) {
        imageId = 'distance-${_distanceImages.length}';
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
        _distanceImages[label] = imageId;
      }
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
            0.625,
            13,
            0.8125,
            15,
            1.0,
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

  void _showContact(MapContact contact) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
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

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String? _cachedStyle;
  String? _sourceStyle;
  bool _webReady = false;
}

Future<String> loadOfflineMapStyle() async {
  final nativeStyle = await prepareNativeOfflineMapStyle();
  return nativeStyle ??
      rootBundle.loadString('assets/maps/santa-maria-style.json');
}
