import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database.dart';
import 'grid_locator.dart';
import 'widgets/grid_locator_field.dart';
import 'map/offline_map.dart';

void main() => runApp(const UsraR3App());

enum AppTheme { system, light, dark }

class OperatorProfile {
  const OperatorProfile({this.callsign = '', this.name = '', this.grid = ''});
  final String callsign;
  final String name;
  final String grid;
}

class UsraR3App extends StatefulWidget {
  const UsraR3App({super.key});

  @override
  State<UsraR3App> createState() => _UsraR3AppState();
}

class _UsraR3AppState extends State<UsraR3App> {
  final database = UsraDatabase();
  final navigatorKey = GlobalKey<NavigatorState>();
  AppTheme theme = AppTheme.system;
  OperatorProfile profile = const OperatorProfile();
  bool setupDone = false;
  bool loading = true;
  bool mergePrecision = true;
  bool lastOnly = false;
  int mapMaxAgeHours = 24;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USRA R3',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: switch (theme) {
        AppTheme.system => ThemeMode.system,
        AppTheme.light => ThemeMode.light,
        AppTheme.dark => ThemeMode.dark,
      },
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : setupDone
          ? HomePage(
              profile: profile,
              database: database,
              mergePrecision: mergePrecision,
              lastOnly: lastOnly,
              mapMaxAgeHours: mapMaxAgeHours,
              onOpenSettings: _openSettings,
            )
          : SetupWizard(onComplete: _completeSetup),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF18181B),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: dark
          ? const Color(0xFF09090B)
          : const Color(0xFFFAFAFA),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF18181B) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final callsign = preferences.getString('operator.callsign') ?? '';
    final name = preferences.getString('operator.name') ?? '';
    final grid = preferences.getString('operator.grid') ?? '';
    final savedTheme = preferences.getString('theme');
    if (!mounted) return;
    setState(() {
      profile = OperatorProfile(callsign: callsign, name: name, grid: grid);
      setupDone = callsign.isNotEmpty && name.isNotEmpty;
      theme = AppTheme.values.firstWhere(
        (value) => value.name == savedTheme,
        orElse: () => AppTheme.system,
      );
      mergePrecision = preferences.getBool('map.mergePrecision') ?? true;
      lastOnly = preferences.getBool('map.lastOnly') ?? false;
      mapMaxAgeHours = preferences.getInt('map.maxAgeHours') ?? 24;
      loading = false;
    });
  }

  Future<void> _completeSetup(OperatorProfile value) async {
    await _saveProfile(value);
    if (mounted) {
      setState(() {
        profile = value;
        setupDone = true;
      });
    }
  }

  Future<void> _saveProfile(OperatorProfile value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('operator.callsign', value.callsign);
    await preferences.setString('operator.name', value.name);
    await preferences.setString('operator.grid', value.grid);
  }

  Future<void> _openSettings() async {
    final result = await navigatorKey.currentState!.push<_SettingsResult>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          profile: profile,
          theme: theme,
          mergePrecision: mergePrecision,
          lastOnly: lastOnly,
          mapMaxAgeHours: mapMaxAgeHours,
        ),
      ),
    );
    if (result != null) {
      await _saveProfile(result.profile);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('theme', result.theme.name);
      await preferences.setBool('map.mergePrecision', result.mergePrecision);
      await preferences.setBool('map.lastOnly', result.lastOnly);
      await preferences.setInt('map.maxAgeHours', result.mapMaxAgeHours);
      if (mounted) {
        setState(() {
          profile = result.profile;
          theme = result.theme;
          mergePrecision = result.mergePrecision;
          lastOnly = result.lastOnly;
          mapMaxAgeHours = result.mapMaxAgeHours;
        });
      }
    }
  }
}

class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key, required this.onComplete});
  final ValueChanged<OperatorProfile> onComplete;

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  final formKey = GlobalKey<FormState>();
  final callsign = TextEditingController();
  final name = TextEditingController();
  final grid = TextEditingController();
  bool locating = false;

  @override
  void dispose() {
    callsign.dispose();
    name.dispose();
    grid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Brand(),
                  const SizedBox(height: 36),
                  Text(
                    'Configure seu perfil',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Essas informações identificam o operador neste dispositivo.',
                    style: TextStyle(color: Color(0xFF71717A)),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: callsign,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseFormatter()],
                    decoration: const InputDecoration(labelText: 'Indicativo'),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Informe o indicativo' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome do operador',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 14),
                  GridLocatorField(controller: grid),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: locating ? null : _useGps,
                      icon: const Icon(Icons.my_location),
                      label: Text(locating ? 'Localizando...' : 'Usar GPS'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _finish,
                    child: const Text('Começar a operar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void _finish() {
    if (formKey.currentState!.validate()) {
      widget.onComplete(
        OperatorProfile(
          callsign: callsign.text.trim().toUpperCase(),
          name: name.text.trim(),
          grid: grid.text.trim().toUpperCase(),
        ),
      );
    }
  }

  Future<void> _useGps() async {
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Ative o serviço de localização');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permissão de localização negada');
      }
      final position = await Geolocator.getCurrentPosition();
      grid.text = GridLocator.fromCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
    if (mounted) setState(() => locating = false);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.profile,
    required this.database,
    required this.onOpenSettings,
    required this.mergePrecision,
    required this.lastOnly,
    required this.mapMaxAgeHours,
  });
  final OperatorProfile profile;
  final UsraDatabase database;
  final VoidCallback onOpenSettings;
  final bool mergePrecision;
  final bool lastOnly;
  final int mapMaxAgeHours;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final formKey = GlobalKey<FormState>();
  final callsign = TextEditingController();
  final operator = TextEditingController();
  final location = TextEditingController();
  final power = TextEditingController();
  final station = TextEditingController(text: 'P');
  final traffic = TextEditingController(text: 'S');
  int _mapFocusRequest = 0;
  String _lastMapFocusGrid = '';

  @override
  void initState() {
    super.initState();
    callsign.addListener(_fillFromPreviousContact);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    callsign.removeListener(_fillFromPreviousContact);
    for (final c in [callsign, operator, location, power, station, traffic]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('USRA R3'),
      actions: [
        IconButton(
          onPressed: widget.onOpenSettings,
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Configurações',
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final panel = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Novo contato',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Registre uma comunicação rapidamente.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: callsign,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseFormatter()],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Indicativo'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: operator,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nome do operador',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              GridLocatorField(controller: location, allowInvalid: true),
              const SizedBox(height: 12),
              TextFormField(
                controller: power,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [PowerFormatter()],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Potência (W)'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              _ChoiceField(
                controller: station,
                label: 'Tipo de estação',
                values: const {'P': 'Portátil', 'M': 'Móvel', 'F': 'Fixa'},
              ),
              const SizedBox(height: 12),
              _ChoiceField(
                controller: traffic,
                label: 'Tráfego',
                values: const {'S': 'Sem tráfego', 'C': 'Com tráfego'},
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _register,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar log'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        StreamBuilder<List<LogEntry>>(
          stream: widget.database.watchLogs(),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const <LogEntry>[];
            if (entries.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Registros salvos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...entries.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.radio),
                      title: Text('${entry.callsign} · ${entry.operatorName}'),
                      subtitle: Text(
                        '${entry.location} · ${entry.powerWatts} W · ${entry.stationType} · ${entry.traffic}\n${_distanceLabel(entry)}${_distanceLabel(entry).isEmpty ? '' : '\n'}${_formatDate(entry.createdAt)}',
                      ),
                      trailing: PopupMenuButton<_LogAction>(
                        onSelected: (action) => switch (action) {
                          _LogAction.edit => _editLog(entry),
                          _LogAction.delete => _deleteLog(entry),
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: _LogAction.edit, child: Text('Editar')),
                          PopupMenuItem(value: _LogAction.delete, child: Text('Remover')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
        final showMap = kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS;
        if (!showMap) return panel;
        final map = _buildMap();
        if (constraints.maxWidth >= 700) {
          return Row(
            children: [
              Expanded(child: map),
              SizedBox(width: constraints.maxWidth.clamp(0, 480), child: panel),
            ],
          );
        }
        return Column(children: [Expanded(child: map), SizedBox(height: 390, child: panel)]);
      },
    ),
  );

  Widget _buildMap() => StreamBuilder<List<LogEntry>>(
    stream: widget.database.watchLogs(),
    builder: (context, snapshot) => Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: OfflineContactsMap(
          entries: snapshot.data ?? const [],
          operatorGrid: widget.profile.grid,
          focusGrid: _lastMapFocusGrid,
          focusRequest: _mapFocusRequest,
          maxAgeHours: widget.mapMaxAgeHours,
          mergePrecision: widget.mergePrecision,
          lastOnly: widget.lastOnly,
        ),
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obrigatório' : null;
  Future<void> _register() async {
    if (!formKey.currentState!.validate()) return;
    final savedLocation = location.text.trim();
    await widget.database.saveLog(
      callsign: callsign.text.trim().toUpperCase(),
      operatorName: operator.text.trim(),
      location: savedLocation,
      operatorGrid: widget.profile.grid,
      powerWatts: double.parse(power.text.replaceAll(',', '.')),
      stationType: station.text.trim().toUpperCase(),
      traffic: traffic.text.trim().toUpperCase(),
    );
    if (mounted) {
      setState(() {
        _lastMapFocusGrid = savedLocation;
        _mapFocusRequest++;
        callsign.clear();
        operator.clear();
        location.clear();
        power.clear();
        station.text = 'P';
        traffic.text = 'S';
      });
    }
  }

  Future<void> _fillFromPreviousContact() async {
    final value = callsign.text.trim().toUpperCase();
    if (value.isEmpty) return;
    final latest = await widget.database.latestLogForCallsign(value);
    if (!mounted || callsign.text.trim().toUpperCase() != value || latest == null) {
      return;
    }
    operator.text = latest.operatorName;
    location.text = latest.location;
    power.text = latest.powerWatts.toString();
    station.text = latest.stationType;
    traffic.text = latest.traffic;
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _distanceLabel(LogEntry entry) {
    final contact = GridLocator.bounds(entry.location);
    final operatorLocation = GridLocator.bounds(entry.operatorGrid);
    if (contact == null || operatorLocation == null) {
      return '';
    }
    const earthRadiusMeters = 6371000.0;
    final lat1 = contact.centerLatitude * math.pi / 180;
    final lat2 = operatorLocation.centerLatitude * math.pi / 180;
    final deltaLat = lat2 - lat1;
    final deltaLon =
        (operatorLocation.centerLongitude - contact.centerLongitude) * math.pi / 180;
    final a = math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLon / 2), 2);
    final distance = earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return 'Distância aproximada: ${distance.round()} m';
  }

  Future<void> _deleteLog(LogEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover contato?'),
        content: Text('O registro de ${entry.callsign} será removido permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed == true) await widget.database.deleteLog(entry.id);
  }

  Future<void> _editLog(LogEntry entry) async {
    final callsign = TextEditingController(text: entry.callsign);
    final operator = TextEditingController(text: entry.operatorName);
    final location = TextEditingController(text: entry.location);
    final power = TextEditingController(text: entry.powerWatts.toString());
    final station = TextEditingController(text: entry.stationType);
    final traffic = TextEditingController(text: entry.traffic);
    final key = GlobalKey<FormState>();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Editar contato'),
          content: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: callsign, inputFormatters: [UpperCaseFormatter()], decoration: const InputDecoration(labelText: 'Indicativo'), validator: _required),
                const SizedBox(height: 10),
                TextFormField(controller: operator, decoration: const InputDecoration(labelText: 'Nome do operador'), validator: _required),
                const SizedBox(height: 10),
                GridLocatorField(controller: location, allowInvalid: true),
                const SizedBox(height: 10),
                TextFormField(controller: power, inputFormatters: [PowerFormatter()], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Potência (W)'), validator: _required),
                const SizedBox(height: 10),
                _ChoiceField(controller: station, label: 'Tipo de estação', values: const {'P': 'Portátil', 'M': 'Móvel', 'F': 'Fixa'}),
                const SizedBox(height: 10),
                _ChoiceField(controller: traffic, label: 'Tráfego', values: const {'S': 'Sem tráfego', 'C': 'Com tráfego'}),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(onPressed: () async {
              if (!key.currentState!.validate()) return;
              await widget.database.updateLog(id: entry.id, callsign: callsign.text.trim().toUpperCase(), operatorName: operator.text.trim(), location: location.text.trim(), powerWatts: double.parse(power.text.replaceAll(',', '.')), stationType: station.text.trim().toUpperCase(), traffic: traffic.text.trim().toUpperCase());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }, child: const Text('Salvar')),
          ],
        ),
      );
    } finally {
      for (final controller in [callsign, operator, location, power, station, traffic]) {
        controller.dispose();
      }
    }
  }
}

enum _LogAction { edit, delete }

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.controller,
    required this.label,
    required this.values,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final Map<String, String> values;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    onFieldSubmitted: onSubmitted,
    textCapitalization: TextCapitalization.characters,
    inputFormatters: [
      UpperCaseFormatter(),
      LengthLimitingTextInputFormatter(1),
    ],
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: PopupMenuButton<String>(
        onSelected: (value) => controller.text = value,
        itemBuilder: (_) => values.entries
            .map(
              (e) => PopupMenuItem(
                value: e.key,
                child: Text('${e.key} — ${e.value}'),
              ),
            )
            .toList(),
      ),
    ),
    validator: (value) => values.containsKey(value?.trim().toUpperCase())
        ? null
        : 'Use ${values.keys.join(', ')}',
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.profile, required this.theme, required this.mergePrecision, required this.lastOnly, required this.mapMaxAgeHours});
  final OperatorProfile profile;
  final AppTheme theme;
  final bool mergePrecision;
  final bool lastOnly;
  final int mapMaxAgeHours;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final callsign = TextEditingController(text: widget.profile.callsign);
  late final name = TextEditingController(text: widget.profile.name);
  late final grid = TextEditingController(text: widget.profile.grid);
  late AppTheme theme = widget.theme;
  bool locating = false;
  late bool mergePrecision = widget.mergePrecision;
  late bool lastOnly = widget.lastOnly;
  late final maxAgeHours = TextEditingController(text: widget.mapMaxAgeHours.toString());
  @override
  void dispose() {
    callsign.dispose();
    name.dispose();
    grid.dispose();
    maxAgeHours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configurações')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Aparência',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        SegmentedButton<AppTheme>(
          segments: const [
            ButtonSegment(value: AppTheme.system, label: Text('Sistema')),
            ButtonSegment(value: AppTheme.light, label: Text('Claro')),
            ButtonSegment(value: AppTheme.dark, label: Text('Escuro')),
          ],
          selected: {theme},
          onSelectionChanged: (value) => setState(() => theme = value.first),
        ),
        const SizedBox(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Agrupar grids de precisões diferentes'),
          subtitle: const Text('Usa o grid mais preciso para a mesma área e indicativo.'),
          value: mergePrecision,
          onChanged: (value) => setState(() => mergePrecision = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar somente o último contato por pessoa'),
          subtitle: const Text('Exibe apenas um marcador para cada indicativo.'),
          value: lastOnly,
          onChanged: (value) => setState(() => lastOnly = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: maxAgeHours,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Exibir contatos das últimas (horas)',
            helperText: 'Contatos mais antigos continuam salvos, mas não aparecem no mapa.',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Dados do operador',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: callsign,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseFormatter()],
          decoration: const InputDecoration(labelText: 'Indicativo'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        const SizedBox(height: 12),
        GridLocatorField(controller: grid),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: locating ? null : _useGps,
            icon: const Icon(Icons.my_location),
            label: Text(locating ? 'Localizando...' : 'Usar GPS'),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: _save, child: const Text('Salvar alterações')),
      ],
    ),
  );
  void _save() => Navigator.pop(
    context,
    _SettingsResult(
      OperatorProfile(
        callsign: callsign.text.trim().toUpperCase(),
        name: name.text.trim(),
        grid: grid.text.trim().toUpperCase(),
      ),
      theme,
      mergePrecision,
      lastOnly,
      math.max(1, int.tryParse(maxAgeHours.text.trim()) ?? widget.mapMaxAgeHours),
    ),
  );
  Future<void> _useGps() async {
    setState(() => locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permissão de localização negada');
      }
      final p = await Geolocator.getCurrentPosition();
      grid.text = GridLocator.fromCoordinates(p.latitude, p.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
    if (mounted) setState(() => locating = false);
  }
}

class _SettingsResult {
  const _SettingsResult(this.profile, this.theme, this.mergePrecision, this.lastOnly, this.mapMaxAgeHours);
  final OperatorProfile profile;
  final AppTheme theme;
  final bool mergePrecision;
  final bool lastOnly;
  final int mapMaxAgeHours;
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.wifi_tethering, size: 28),
      SizedBox(width: 10),
      Text(
        'USRA R3',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(
    text: newValue.text.toUpperCase(),
    selection: newValue.selection,
  );
}

class PowerFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(
    text: newValue.text.replaceAll(',', '.'),
    selection: newValue.selection,
  );
}
