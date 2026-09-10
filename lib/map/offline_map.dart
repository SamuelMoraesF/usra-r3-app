import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../data/database.dart';
import '../grid_locator.dart';
import 'contact_aggregation.dart';
import 'pmtiles_registration_stub.dart'
    if (dart.library.js_interop) 'pmtiles_registration_web.dart';

class OfflineContactsMap extends StatefulWidget {
  const OfflineContactsMap({super.key, required this.entries, required this.operatorGrid, this.mergePrecision = true, this.lastOnly = false});
  final List<LogEntry> entries;
  final String operatorGrid;
  final bool mergePrecision;
  final bool lastOnly;

  @override
  State<OfflineContactsMap> createState() => _OfflineContactsMapState();
}

class _OfflineContactsMapState extends State<OfflineContactsMap> {
  MapLibreMapController? controller;
  List<MapContact> contacts = const [];

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
    if (oldWidget.entries != widget.entries || oldWidget.operatorGrid != widget.operatorGrid || oldWidget.mergePrecision != widget.mergePrecision || oldWidget.lastOnly != widget.lastOnly) {
      _refreshContacts();
      _drawContacts();
    }
  }

  void _refreshContacts() => contacts = aggregateMapContacts(widget.entries, mergePrecision: widget.mergePrecision, lastOnlyByCallsign: widget.lastOnly);

  @override
  Widget build(BuildContext context) {
    final style = _cachedStyle;
    if (style == null || !_webReady) {
      return const Center(child: CircularProgressIndicator());
    }
    return MapLibreMap(
      styleString: style,
      initialCameraPosition: const CameraPosition(target: LatLng(-29.6868, -53.8069), zoom: 12),
      minMaxZoomPreference: const MinMaxZoomPreference(12, 15),
      cameraTargetBounds: CameraTargetBounds(
        LatLngBounds(
          southwest: const LatLng(-30.15, -54.00),
          northeast: const LatLng(-29.55, -53.55),
        ),
      ),
      compassEnabled: true,
      myLocationEnabled: false,
      onMapCreated: (value) => controller = value,
      onStyleLoadedCallback: _drawContacts,
      onCameraIdle: _logCameraZoom,
    );
  }

  Future<void> _logCameraZoom() async {
    final position = await controller?.queryCameraPosition();
    if (position == null) return;
    debugPrint(
      '[USRA R3] mapa: zoom=${position.zoom.toStringAsFixed(2)} '
      'centro=${position.target.latitude.toStringAsFixed(5)},'
      '${position.target.longitude.toStringAsFixed(5)}',
    );
  }

  Future<void> _loadStyle() async {
    final style = await loadOfflineMapStyle();
    if (mounted) setState(() => _cachedStyle = style);
  }

  Future<void> _prepareWeb() async {
    await MapLibreMap.ensureWebLibraryLoaded();
    await registerPmtilesProtocol();
    if (mounted) setState(() => _webReady = true);
  }

  Future<void> _drawContacts() async {
    final map = controller;
    if (map == null || !mounted) return;
    await map.clearCircles();
    final operatorBounds = GridLocator.bounds(widget.operatorGrid);
    if (operatorBounds != null) {
      await map.addCircle(CircleOptions(
        geometry: LatLng(operatorBounds.centerLatitude, operatorBounds.centerLongitude),
        circleColor: '#DC2626',
        circleRadius: 5,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ));
    }
    for (final contact in contacts) {
      final bounds = contact.bounds;
      if (bounds == null) continue;
      final circle = await map.addCircle(CircleOptions(
        geometry: LatLng(bounds.centerLatitude, bounds.centerLongitude),
        circleColor: '#2563EB',
        circleRadius: 7,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ));
      map.onCircleTapped.add((_) => _showContact(contact));
      assert(circle.id.isNotEmpty);
    }
  }

  void _showContact(MapContact contact) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(child: ListTile(
        title: Text('${contact.latest.callsign} · ${contact.latest.operatorName}'),
        subtitle: Text('Grid ${contact.latest.location}\nPrimeiro: ${contact.first.createdAt.toLocal()}\nÚltimo: ${contact.last.createdAt.toLocal()}'),
      )),
    );
  }

  String? _cachedStyle;
  bool _webReady = false;
}

Future<String> loadOfflineMapStyle() async => rootBundle.loadString('assets/maps/santa-maria-style.json');
