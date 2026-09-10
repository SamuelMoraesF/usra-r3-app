import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../data/database.dart';
import '../grid_locator.dart';
import 'contact_aggregation.dart';
import 'pmtiles_registration_stub.dart'
    if (dart.library.js_interop) 'pmtiles_registration_web.dart';
import 'offline_map_style_stub.dart'
    if (dart.library.io) 'offline_map_style_io.dart';

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
        circleColor: '#F36F21',
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
        circleColor: '#B84E18',
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
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 18),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.primary,
                      child: const Icon(Icons.radio, size: 25),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(contact.latest.callsign, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          Text(contact.latest.operatorName, style: TextStyle(color: colors.onSurfaceVariant)),
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
                    _detailChip(Icons.cell_tower, contact.latest.stationType),
                    _detailChip(Icons.swap_calls, contact.latest.traffic),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Histórico do ponto', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Primeiro contato  ${_formatDate(contact.first.createdAt)}', style: TextStyle(color: colors.onSurfaceVariant)),
                Text('Último contato     ${_formatDate(contact.last.createdAt)}', style: TextStyle(color: colors.onSurfaceVariant)),
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
  bool _webReady = false;
}

Future<String> loadOfflineMapStyle() async {
  final nativeStyle = await prepareNativeOfflineMapStyle();
  return nativeStyle ?? rootBundle.loadString('assets/maps/santa-maria-style.json');
}
