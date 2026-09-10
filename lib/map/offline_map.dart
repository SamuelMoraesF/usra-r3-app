import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../data/database.dart';
import '../grid_locator.dart';
import 'contact_aggregation.dart';
import 'pmtiles_registration_stub.dart'
    if (dart.library.js_interop) 'pmtiles_registration_web.dart';

class OfflineContactsMap extends StatefulWidget {
  const OfflineContactsMap({super.key, required this.entries, required this.operatorGrid, this.focusGrid = '', this.focusRequest = 0, this.mergePrecision = true, this.lastOnly = false, this.maxAgeHours = 24});
  final List<LogEntry> entries;
  final String operatorGrid;
  final String focusGrid;
  final int focusRequest;
  final bool mergePrecision;
  final bool lastOnly;
  final int maxAgeHours;

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
    if (oldWidget.focusRequest != widget.focusRequest) {
      _animateToGrid(widget.focusGrid);
    }
    if (oldWidget.entries != widget.entries || oldWidget.operatorGrid != widget.operatorGrid || oldWidget.mergePrecision != widget.mergePrecision || oldWidget.lastOnly != widget.lastOnly || oldWidget.maxAgeHours != widget.maxAgeHours) {
      _refreshContacts();
      _drawContacts();
    }
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
    final cutoff = DateTime.now().toUtc().subtract(Duration(hours: widget.maxAgeHours));
    final visibleEntries = widget.entries.where((entry) => !entry.createdAt.isBefore(cutoff)).toList();
    contacts = aggregateMapContacts(visibleEntries, mergePrecision: widget.mergePrecision, lastOnlyByCallsign: widget.lastOnly);
  }

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
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _drawContacts,
      onCameraIdle: _logCameraZoom,
    );
  }

  void _onMapCreated(MapLibreMapController value) {
    controller = value;
    value.onCircleTapped.add(_onCircleTapped);
  }

  void _onCircleTapped(Circle circle) {
    final index = circle.data?['contactIndex'];
    if (index is int && index >= 0 && index < contacts.length) {
      _showContact(contacts[index]);
    }
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
        circleRadius: 7,
        circleBlur: 0,
        circleOpacity: 1,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
        circleStrokeOpacity: 1,
      ));
    }
    for (var index = 0; index < contacts.length; index++) {
      final contact = contacts[index];
      final bounds = contact.bounds;
      if (bounds == null) continue;
      final circle = await map.addCircle(CircleOptions(
        geometry: LatLng(bounds.centerLatitude, bounds.centerLongitude),
        circleColor: '#2563EB',
        circleRadius: 5,
        circleBlur: 0,
        circleOpacity: 1,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
        circleStrokeOpacity: 1,
      ), {'contactIndex': index});
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
