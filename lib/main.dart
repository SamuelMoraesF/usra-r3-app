import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'data/database.dart';
import 'time_display.dart';
import 'data/csv_transfer.dart';
import 'branding.dart';
import 'grid_locator.dart';
import 'widgets/grid_locator_field.dart';
import 'widgets/contact_workspace.dart';
import 'widgets/contact_form_layout.dart';
import 'map/offline_map.dart';
import 'map/map_settings.dart';

bool _defaultKeyboardOptimized() =>
    kIsWeb ||
    (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapLibreMap.useHybridComposition = true;
  const dsn = String.fromEnvironment('SENTRY_DSN');
  const release = String.fromEnvironment('SENTRY_RELEASE');
  const dist = String.fromEnvironment('SENTRY_DIST');
  const environment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: 'production',
  );
  if (dsn.trim().isEmpty) {
    runApp(const UsraR3App());
    return;
  }
  await SentryFlutter.init((options) {
    options.dsn = dsn;
    options.sendDefaultPii = false;
    options.environment = environment;
    if (release.trim().isNotEmpty) options.release = release;
    if (dist.trim().isNotEmpty) options.dist = dist;
    options.tracesSampleRate = 0.0;
    // Profiling is disabled; this option is experimental in the SDK.
    // ignore: experimental_member_use
    options.profilesSampleRate = 0.0;
  }, appRunner: () => runApp(const UsraR3App()));
}

enum AppTheme { system, light, dark }

enum HomeLayout { bottomPanels, sidebar }

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
  DisplayTimeZone displayTimeZone = DisplayTimeZone.brasilia;
  OperatorProfile profile = const OperatorProfile();
  bool setupDone = false;
  bool loading = true;
  bool mergePrecision = true;
  bool lastOnly = false;
  int mapMaxAgeHours = 24;
  bool keepScreenOn = true;
  bool keyboardOptimized = _defaultKeyboardOptimized();
  HomeLayout homeLayout = HomeLayout.bottomPanels;
  MapSettings mapSettings = const MapSettings();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBranding.name,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: dark
                ? Brightness.light
                : Brightness.dark,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
          ),
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              maintainBottomViewPadding: true,
              child: TimeDisplay(
                zone: displayTimeZone,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
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
              mapSettings: mapSettings,
              keyboardOptimized: keyboardOptimized,
              homeLayout: homeLayout,
              onMapSettingsChanged: _setMapSettings,
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
        seedColor: const Color(0xFFF36F21),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: dark
          ? const Color(0xFF17120F)
          : const Color(0xFFFFFBF7),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF241B16) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF3A2A21) : const Color(0xFFEADFD7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: const Color(0xFFF36F21), width: 1.5),
        ),
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
      mapSettings = MapSettings.read(preferences);
      displayTimeZone = DisplayTimeZone.read(preferences);
      keepScreenOn = preferences.getBool('keepScreenOn') ?? true;
      keyboardOptimized =
          preferences.getBool('keyboardOptimized') ??
          _defaultKeyboardOptimized();
      homeLayout = HomeLayout.values.firstWhere(
        (value) => value.name == preferences.getString('homeLayout'),
        orElse: () => HomeLayout.bottomPanels,
      );
      loading = false;
    });
    await WakelockPlus.toggle(enable: keepScreenOn);
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
          displayTimeZone: displayTimeZone,
          mergePrecision: mergePrecision,
          lastOnly: lastOnly,
          mapMaxAgeHours: mapMaxAgeHours,
          keepScreenOn: keepScreenOn,
          keyboardOptimized: keyboardOptimized,
          homeLayout: homeLayout,
          showCompass: mapSettings.showCompass,
          focusNewRecord: mapSettings.focusNewRecord,
          database: database,
          repeaterGrid: mapSettings.repeaterGrid,
        ),
      ),
    );
    if (result != null) {
      await _saveProfile(result.profile);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('theme', result.theme.name);
      await result.displayTimeZone.save(preferences);
      await preferences.setBool('map.mergePrecision', result.mergePrecision);
      await preferences.setBool('map.lastOnly', result.lastOnly);
      await preferences.setInt('map.maxAgeHours', result.mapMaxAgeHours);
      await preferences.setBool('keepScreenOn', result.keepScreenOn);
      await preferences.setBool('keyboardOptimized', result.keyboardOptimized);
      await preferences.setString('homeLayout', result.homeLayout.name);
      await _setMapSettings(
        MapSettings(
          showLines: mapSettings.showLines,
          showAll: mapSettings.showAll,
          showPrecision: mapSettings.showPrecision,
          showElevation: mapSettings.showElevation,
          showCompass: result.showCompass,
          focusNewRecord: result.focusNewRecord,
          showCallsigns: mapSettings.showCallsigns,
          repeaterGrid: result.repeaterGrid,
        ),
      );
      await WakelockPlus.toggle(enable: result.keepScreenOn);
      if (mounted) {
        setState(() {
          profile = result.profile;
          theme = result.theme;
          displayTimeZone = result.displayTimeZone;
          mergePrecision = result.mergePrecision;
          lastOnly = result.lastOnly;
          mapMaxAgeHours = result.mapMaxAgeHours;
          keepScreenOn = result.keepScreenOn;
          keyboardOptimized = result.keyboardOptimized;
          homeLayout = result.homeLayout;
        });
      }
    }
  }

  Future<void> _setMapSettings(MapSettings value) async {
    setState(() => mapSettings = value);
    await value.save(await SharedPreferences.getInstance());
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
                    inputFormatters: [CapitalizeWordsFormatter()],
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
          name: capitalizeWordInitials(name.text.trim()),
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
    this.keyboardOptimized = false,
    this.homeLayout = HomeLayout.bottomPanels,
    this.mapSettings = const MapSettings(),
    this.onMapSettingsChanged,
  });
  final OperatorProfile profile;
  final UsraDatabase database;
  final VoidCallback onOpenSettings;
  final bool mergePrecision;
  final bool lastOnly;
  final int mapMaxAgeHours;
  final bool keyboardOptimized;
  final HomeLayout homeLayout;
  final MapSettings mapSettings;
  final ValueChanged<MapSettings>? onMapSettingsChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _repeaterFrequency = 'repeater';
  static const _simplexFrequency = 'simplex';
  final formKey = GlobalKey<FormState>();
  final _callsignFocusNode = FocusNode();
  final _viaFocusNode = FocusNode();
  final _operatorFocusNode = FocusNode();
  final _locationFocusNode = FocusNode();
  final _powerFocusNode = FocusNode();
  final _stationFocusNode = FocusNode();
  final _energyFocusNode = FocusNode();
  final _trafficFocusNode = FocusNode();
  final _trafficMessageFocusNode = FocusNode();
  final callsign = TextEditingController();
  final via = TextEditingController();
  String frequency = _repeaterFrequency;
  final operator = TextEditingController();
  final location = TextEditingController();
  final power = TextEditingController();
  final station = TextEditingController(text: 'P - Portátil');
  final traffic = TextEditingController(text: 'S - Sem tráfego');
  final energy = TextEditingController(text: 'B - Bateria');
  final trafficMessage = TextEditingController();
  final _panelScrollController = ScrollController();
  double? _scrollOffsetBeforeKeyboard;
  bool _keyboardWasOpen = false;
  double _lastKeyboardInset = 0;
  int _mapFocusRequest = 0;
  String _lastMapFocusGrid = '';
  DateTime? _networkStartedAt;

  @override
  void initState() {
    super.initState();
    _callsignFocusNode.addListener(_onCallsignFocusChanged);
    FocusManager.instance.addListener(_scrollToFocusedField);
    WidgetsBinding.instance.addObserver(this);
    _loadFrequency();
    _loadNetworkState();
  }

  Future<void> _loadNetworkState() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('network.startedAt');
    final closed = preferences.getString('network.closedAt');
    final started = raw == null || closed != null
        ? null
        : DateTime.tryParse(raw)?.toUtc();
    if (mounted) setState(() => _networkStartedAt = started);
  }

  Future<void> _openNetwork() async {
    final started = DateTime.now().toUtc();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('network.startedAt', started.toIso8601String());
    await preferences.remove('network.closedAt');
    if (mounted) setState(() => _networkStartedAt = started);
  }

  Future<void> _closeNetwork() async {
    final started = _networkStartedAt;
    if (started == null) return;
    final confirmed = await _confirmCloseNetwork();
    if (!confirmed) return;
    final ended = DateTime.now().toUtc();
    await widget.database.closeNetwork(started, ended);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('network.closedAt', ended.toIso8601String());
    if (mounted) setState(() => _networkStartedAt = null);
  }

  Future<bool> _confirmCloseNetwork() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Encerrar rede?'),
            content: const Text(
              'A rede será encerrada e não será mais possível registrar novos contatos nela.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Encerrar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _scrollToFocusedField() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.mounted && _keyboardIsOpen) {
        if (!_keyboardWasOpen) {
          _keyboardWasOpen = true;
          _scrollOffsetBeforeKeyboard = _panelScrollController.hasClients
              ? _panelScrollController.offset
              : null;
        }
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  bool get _keyboardIsOpen => MediaQuery.viewInsetsOf(context).bottom > 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if ((inset - _lastKeyboardInset).abs() < 0.5) return;
    _lastKeyboardInset = inset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateKeyboardScroll();
    });
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateKeyboardScroll();
    });
  }

  void _updateKeyboardScroll() {
    final keyboardOpen = _keyboardIsOpen;
    if (keyboardOpen && !_keyboardWasOpen) {
      _keyboardWasOpen = true;
      _scrollOffsetBeforeKeyboard = _panelScrollController.hasClients
          ? _panelScrollController.offset
          : null;
    } else if (!keyboardOpen && _keyboardWasOpen) {
      _keyboardWasOpen = false;
      final offset = _scrollOffsetBeforeKeyboard;
      _scrollOffsetBeforeKeyboard = null;
      if (offset != null && _panelScrollController.hasClients) {
        _panelScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
    if (keyboardOpen) {
      _scrollToFocusedField();
      // The keyboard and the temporary list spacer can animate/layout in
      // separate frames. Retry after both have settled so the final fields
      // are not left just above the keyboard edge.
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted && _keyboardIsOpen) _scrollToFocusedField();
      });
    }
  }

  Future<void> _loadFrequency() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => frequency =
            preferences.getString('contact.frequency') ?? _repeaterFrequency,
      );
    }
  }

  Future<void> _setFrequency(String value) async {
    setState(() => frequency = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('contact.frequency', value);
  }

  void _newContact() {
    formKey.currentState?.reset();
    setState(() {
      callsign.clear();
      via.clear();
      operator.clear();
      location.clear();
      power.clear();
      station.text = 'P - Portátil';
      energy.text = 'B - Bateria';
      traffic.text = 'S - Sem tráfego';
      trafficMessage.clear();
    });
    _callsignFocusNode.requestFocus();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _callsignFocusNode.removeListener(_onCallsignFocusChanged);
    FocusManager.instance.removeListener(_scrollToFocusedField);
    WidgetsBinding.instance.removeObserver(this);
    _panelScrollController.dispose();
    _callsignFocusNode.dispose();
    _viaFocusNode.dispose();
    for (final node in [
      _operatorFocusNode,
      _locationFocusNode,
      _powerFocusNode,
      _stationFocusNode,
      _energyFocusNode,
      _trafficFocusNode,
      _trafficMessageFocusNode,
    ]) {
      node.dispose();
    }
    for (final c in [
      callsign,
      via,
      operator,
      location,
      power,
      station,
      traffic,
      energy,
      trafficMessage,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          _newContact,
    },
    child: Focus(autofocus: true, child: _buildScaffold(context)),
  );

  Widget _buildScaffold(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final view = View.of(context);
    // SafeArea already reserves the navigation bar below this page. Only
    // subtract the part of the keyboard that overlaps the page itself.
    final keyboardOverlap = math.max(
      0.0,
      mediaQuery.viewInsets.bottom -
          view.viewPadding.bottom / view.devicePixelRatio,
    );
    return MediaQuery(
      data: mediaQuery.copyWith(
        viewInsets: mediaQuery.viewInsets.copyWith(bottom: keyboardOverlap),
      ),
      child: _buildPageScaffold(context),
    );
  }

  Widget _buildPageScaffold(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: MediaQuery.sizeOf(context).width < 700,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final mobile =
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS;
        final showMap = kIsWeb || mobile;
        final screen = MediaQuery.sizeOf(context);
        final useBottomPanels =
            showMap &&
            widget.homeLayout == HomeLayout.bottomPanels &&
            constraints.maxWidth >= 700 &&
            (!mobile ||
                (screen.shortestSide >= 600 && screen.width > screen.height));
        final header = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppBranding.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            IconButton(
              onPressed: widget.onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configurações',
            ),
          ],
        );
        final contactTitle = Text(
          'Novo contato',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        );
        final frequencySwitch = SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: _repeaterFrequency,
              label: _FrequencyLabel('Repetidora', '145.37'),
            ),
            ButtonSegment(
              value: _simplexFrequency,
              label: _FrequencyLabel('Simplex', '146.52'),
            ),
          ],
          selected: {frequency},
          onSelectionChanged: (value) => _setFrequency(value.first),
        );
        final formChildren = <Widget>[
          if (useBottomPanels)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: contactTitle),
                const SizedBox(width: 12),
                Flexible(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: frequencySwitch,
                    ),
                  ),
                ),
              ],
            )
          else
            contactTitle,
          const SizedBox(height: 6),
          Text(
            'Registre uma comunicação rapidamente.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          if (_networkStartedAt == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openNetwork,
                icon: const Icon(Icons.cell_tower),
                label: const Text('Fazer abertura da rede'),
              ),
            ),
          if (!useBottomPanels) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: frequencySwitch),
            if (_networkStartedAt != null) const SizedBox(height: 12),
          ],
          if (_networkStartedAt != null) _buildContactForm(useBottomPanels),
        ];
        final logs = StreamBuilder<List<LogEntry>>(
          stream: widget.database.watchLogs(),
          builder: (context, snapshot) {
            final allEntries = snapshot.data ?? const <LogEntry>[];
            final entries = allEntries
                .where((entry) => entry.frequency == frequency)
                .toList();
            final openNetworkIsEmpty =
                _networkStartedAt != null &&
                !entries.any(
                  (entry) => entry.networkStartedAt == _networkStartedAt,
                );
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
                if (entries.isEmpty && !openNetworkIsEmpty)
                  Text(
                    'Não há registros recentes.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (openNetworkIsEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(
                      _networkTitle(_networkStartedAt),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'Ainda não houve nenhum contato.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                ...entries.asMap().entries.map((indexed) {
                  final entry = indexed.value;
                  final previous = indexed.key == 0
                      ? null
                      : entries[indexed.key - 1];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (previous == null ||
                          previous.networkStartedAt != entry.networkStartedAt)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Text(
                            _networkTitle(
                              entry.networkStartedAt,
                              entry.networkEndedAt,
                            ),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      Dismissible(
                        key: ValueKey('saved-log-${entry.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          final confirmed = await _confirmDeleteLog(entry);
                          if (confirmed) {
                            await widget.database.deleteLog(entry.id);
                          }
                          return confirmed;
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.55),
                            ),
                          ),
                          child: ListTile(
                            onTap: () => _editLog(entry),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: RichText(
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: [
                                        TextSpan(
                                          text:
                                              '${entry.callsign} · ${entry.operatorName}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if (entry.via.trim().isNotEmpty) ...[
                                          const TextSpan(text: '  '),
                                          _viaTitleSpan(
                                            context,
                                            allEntries,
                                            entry.via,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.schedule,
                                  size: 15,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatDate(entry.createdAt),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.power, size: 16),
                                    const SizedBox(width: 4),
                                    Text(_energyLabel(entry.energy)),
                                    const SizedBox(width: 8),
                                    const Text('·'),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.bolt, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${entry.powerWatts} W'),
                                    const SizedBox(width: 8),
                                    const Text('·'),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.radio, size: 16),
                                    const SizedBox(width: 4),
                                    Text(_stationLabel(entry.stationType)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _contactMeta(entry),
                                if (entry.traffic == 'C' &&
                                    entry.trafficMessage.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.only(top: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    width: double.infinity,
                                    child: Text(
                                      entry.trafficMessage,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            );
          },
        );
        final panel = ListView(
          controller: _panelScrollController,
          padding: const EdgeInsets.all(20),
          children: [
            header,
            const SizedBox(height: 8),
            ...formChildren,
            const SizedBox(height: 28),
            logs,
            // Reserve only a minimal scroll range for the last field. This
            // spacer disappears when the keyboard closes.
            if (keyboardInset > 0) const SizedBox(height: 40),
          ],
        );
        final panelForLayout = constraints.maxWidth >= 700 && keyboardInset > 0
            ? SizedBox(
                height: (constraints.maxHeight - keyboardInset).clamp(
                  0.0,
                  constraints.maxHeight,
                ),
                child: panel,
              )
            : panel;
        if (!showMap) return panel;
        final map = _buildMap();
        if (useBottomPanels) {
          return Padding(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: ContactWorkspace(
              map: map,
              form: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: formChildren,
              ),
              logs: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header, const SizedBox(height: 20), logs],
              ),
              formScrollController: _panelScrollController,
            ),
          );
        }
        if (constraints.maxWidth >= 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: map),
              SizedBox(
                width: constraints.maxWidth.clamp(0, 480),
                child: panelForLayout,
              ),
            ],
          );
        }
        final keyboardOpen = keyboardInset > 0;
        final availableHeight = constraints.maxHeight + keyboardInset;
        final panelHeight = 390.0.clamp(0.0, availableHeight * 0.65);
        return Column(
          children: [
            // Keep the map mounted and at its original size while typing so
            // dismissing the keyboard restores the same camera and zoom.
            Offstage(
              offstage: keyboardOpen,
              child: SizedBox(
                height: availableHeight - panelHeight,
                child: map,
              ),
            ),
            Expanded(child: panel),
          ],
        );
      },
    ),
  );

  Widget _buildContactForm(bool fourColumns) => Form(
    key: formKey,
    child: ContactFormLayout(
      fourColumns: fourColumns,
      fields: [
        TextFormField(
          controller: callsign,
          focusNode: _callsignFocusNode,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseFormatter()],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Indicativo'),
          onFieldSubmitted: (_) => _viaFocusNode.requestFocus(),
          validator: _required,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        TextFormField(
          controller: via,
          focusNode: _viaFocusNode,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseFormatter()],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Via'),
          onFieldSubmitted: (_) => _operatorFocusNode.requestFocus(),
        ),
        TextFormField(
          controller: operator,
          focusNode: _operatorFocusNode,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [CapitalizeWordsFormatter()],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: fourColumns ? 'Nome' : 'Nome do operador',
          ),
          onFieldSubmitted: (_) => _locationFocusNode.requestFocus(),
          validator: _required,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        GridLocatorField(
          controller: location,
          labelText: fourColumns ? 'Grid' : 'Localização ou grid',
          focusNode: _locationFocusNode,
          allowInvalid: true,
          onSubmitted: (_) => _powerFocusNode.requestFocus(),
        ),
        TextFormField(
          controller: power,
          focusNode: _powerFocusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [PowerFormatter()],
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _stationFocusNode.requestFocus(),
          decoration: const InputDecoration(labelText: 'Potência (W)'),
          validator: _required,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        _ChoiceField(
          controller: station,
          focusNode: _stationFocusNode,
          label: 'Estação',
          keyboardOptimized: widget.keyboardOptimized,
          values: const {'P': 'Portátil', 'M': 'Móvel', 'F': 'Fixa'},
          onSubmitted: (_) => _energyFocusNode.requestFocus(),
        ),
        _ChoiceField(
          controller: energy,
          focusNode: _energyFocusNode,
          label: 'Energia',
          keyboardOptimized: widget.keyboardOptimized,
          values: const {'B': 'Bateria', 'G': 'Gerador', 'AC': 'Rede elétrica'},
          onSubmitted: (_) => _trafficFocusNode.requestFocus(),
        ),
        _ChoiceField(
          controller: traffic,
          focusNode: _trafficFocusNode,
          textInputAction: TextInputAction.next,
          label: 'Tráfego',
          keyboardOptimized: widget.keyboardOptimized,
          values: const {'S': 'Sem tráfego', 'C': 'Com tráfego'},
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _choiceCode(traffic.text) == 'C'
              ? _trafficMessageFocusNode.requestFocus()
              : FocusScope.of(context).nextFocus(),
        ),
      ],
      message: _choiceCode(traffic.text) == 'C'
          ? TextFormField(
              controller: trafficMessage,
              focusNode: _trafficMessageFocusNode,
              textInputAction: TextInputAction.done,
              inputFormatters: [UpperCaseFormatter()],
              decoration: const InputDecoration(
                labelText: 'Mensagem (tráfego)',
              ),
              validator: _required,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            )
          : null,
      closeButton: OutlinedButton.icon(
        onPressed: _closeNetwork,
        icon: const Icon(Icons.power_settings_new),
        label: Text(fourColumns ? 'Fechar rede' : 'Fazer encerramento da rede'),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      submitButton: FilledButton.icon(
        onPressed: _register,
        icon: const Icon(Icons.add),
        label: Text(fourColumns ? 'Adicionar log' : 'Registrar log'),
      ),
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
          entriesLoaded: snapshot.hasData,
          operatorGrid: widget.profile.grid,
          operatorCallsign: widget.profile.callsign,
          focusGrid: _lastMapFocusGrid,
          focusRequest: _mapFocusRequest,
          maxAgeHours: widget.mapMaxAgeHours,
          mergePrecision: widget.mergePrecision,
          lastOnly: widget.lastOnly,
          selectedMode: frequency,
          selectedFrequencyMhz: frequency == _simplexFrequency
              ? 146.52
              : 145.37,
          settings: widget.mapSettings,
          onSettingsChanged: widget.onMapSettingsChanged,
        ),
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obrigatório' : null;

  Future<void> _register() async {
    if (!formKey.currentState!.validate()) return;
    final savedLocation = location.text.trim();
    if (_rejectInvalidGrid(savedLocation, 'localização')) return;
    if (_rejectInvalidGrid(widget.profile.grid, 'grid do operador')) return;
    await widget.database.saveLog(
      callsign: callsign.text.trim().toUpperCase(),
      via: via.text.trim().toUpperCase(),
      frequency: frequency,
      frequencyMhz: frequency == _simplexFrequency ? 146.52 : 145.37,
      repeaterGrid: widget.mapSettings.repeaterGrid,
      energy: _choiceCode(energy.text),
      operatorName: capitalizeWordInitials(operator.text.trim()),
      location: savedLocation,
      operatorGrid: widget.profile.grid,
      powerWatts: double.parse(power.text.replaceAll(',', '.')),
      stationType: _choiceCode(station.text),
      traffic: _choiceCode(traffic.text),
      trafficMessage: trafficMessage.text.trim(),
      networkStartedAt: _networkStartedAt,
    );
    if (mounted) {
      setState(() {
        if (widget.mapSettings.focusNewRecord) {
          _lastMapFocusGrid = savedLocation;
          _mapFocusRequest++;
        }
        callsign.clear();
        via.clear();
        operator.clear();
        location.clear();
        power.clear();
        station.text = 'P - Portátil';
        traffic.text = 'S - Sem tráfego';
        trafficMessage.clear();
      });
    }
  }

  bool _rejectInvalidGrid(String value, String label) {
    if (!GridLocator.looksLikeGrid(value) ||
        GridLocator.inspect(value).isValid) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Informe um $label Maidenhead válido.')),
    );
    return true;
  }

  void _onCallsignFocusChanged() {
    if (!_callsignFocusNode.hasFocus) {
      _fillFromPreviousContact();
    }
  }

  Future<void> _fillFromPreviousContact() async {
    final value = callsign.text.trim().toUpperCase();
    if (value.isEmpty) return;
    final selectedFrequency = frequency;
    final latest = await widget.database.latestLogForCallsign(value);
    final latestOnFrequency = await widget.database.latestLogForCallsign(
      value,
      frequency: selectedFrequency,
    );
    if (!mounted ||
        callsign.text.trim().toUpperCase() != value ||
        frequency != selectedFrequency ||
        latest == null) {
      return;
    }
    operator.text = capitalizeWordInitials(latest.operatorName);
    location.text = latest.location;
    power.text = latestOnFrequency?.powerWatts.toString() ?? '';
    station.text = latest.stationType;
    energy.text = latest.energy;
  }

  String _formatDate(DateTime value) =>
      TimeDisplay.of(context).format(value, compact: true);

  String _networkTitle(DateTime? startedAt, [DateTime? endedAt]) =>
      TimeDisplay.of(context).formatNetworkTitle(startedAt, endedAt);

  String _operatorNameFor(List<LogEntry> entries, String callsign) {
    final match = entries
        .where(
          (e) =>
              e.callsign.trim().toUpperCase() == callsign.trim().toUpperCase(),
        )
        .toList();
    return match.isEmpty ? '' : match.first.operatorName;
  }

  TextSpan _viaTitleSpan(
    BuildContext context,
    List<LogEntry> entries,
    String callsign,
  ) {
    final normalized = callsign.trim().toUpperCase();
    final name = _operatorNameFor(entries, normalized).trim();
    return TextSpan(
      text: name.isEmpty ? 'via $normalized' : 'via $normalized · $name',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.normal,
      ),
    );
  }

  String _stationLabel(String code) => switch (code.trim().toUpperCase()) {
    'P' => 'Portátil',
    'M' => 'Móvel',
    'F' => 'Fixa',
    _ => code,
  };

  String _trafficLabel(String code) => switch (code.trim().toUpperCase()) {
    'S' => 'Sem tráfego',
    'C' => 'Com tráfego',
    _ => code,
  };

  String _energyLabel(String code) => switch (code.trim().toUpperCase()) {
    'B' => 'Bateria',
    'G' => 'Gerador',
    'AC' => 'Rede elétrica',
    _ => code,
  };

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
        (operatorLocation.centerLongitude - contact.centerLongitude) *
        math.pi /
        180;
    final a =
        math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLon / 2), 2);
    final distance =
        earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    if (distance < 1000) return '${distance.round()}m';
    final kilometers = distance / 1000;
    final value = kilometers == kilometers.roundToDouble()
        ? kilometers.toStringAsFixed(0)
        : kilometers.toStringAsFixed(1);
    return '${value}km';
  }

  Widget _contactMeta(LogEntry entry) {
    final distance = _distanceLabel(entry);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final items = <Widget>[];
    if (distance.isNotEmpty) {
      items.addAll([
        Icon(Icons.straighten, size: 15, color: color),
        const SizedBox(width: 3),
        Text(distance),
        const SizedBox(width: 8),
        Text('·', style: TextStyle(color: color)),
        const SizedBox(width: 8),
      ]);
    }
    items.addAll([
      Icon(Icons.public, size: 15, color: color),
      const SizedBox(width: 3),
      Flexible(child: Text(entry.location, overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      Text('·', style: TextStyle(color: color)),
      const SizedBox(width: 8),
    ]);
    items.addAll([
      Icon(Icons.graphic_eq, size: 15, color: color),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          entry.frequency == _repeaterFrequency ? 'Repetidora' : 'Simplex',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }

  Future<bool> _confirmDeleteLog(LogEntry entry) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remover contato?'),
            content: Text(
              'O registro de ${entry.callsign} será removido permanentemente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remover'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _editLog(LogEntry entry) async {
    final callsign = TextEditingController(text: entry.callsign);
    final via = TextEditingController(text: entry.via);
    final operator = TextEditingController(
      text: capitalizeWordInitials(entry.operatorName),
    );
    final location = TextEditingController(text: entry.location);
    final power = TextEditingController(text: entry.powerWatts.toString());
    final station = TextEditingController(
      text: '${entry.stationType} - ${_stationLabel(entry.stationType)}',
    );
    final traffic = TextEditingController(
      text: '${entry.traffic} - ${_trafficLabel(entry.traffic)}',
    );
    final energy = TextEditingController(
      text: '${entry.energy} - ${_energyLabel(entry.energy)}',
    );
    final trafficMessage = TextEditingController(text: entry.trafficMessage);
    final key = GlobalKey<FormState>();
    var editFrequency = entry.frequency;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Editar contato'),
            content: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: _repeaterFrequency,
                          label: _FrequencyLabel('Repetidora', '145.37'),
                        ),
                        ButtonSegment(
                          value: _simplexFrequency,
                          label: _FrequencyLabel('Simplex', '146.52'),
                        ),
                      ],
                      selected: {editFrequency},
                      onSelectionChanged: (value) =>
                          setDialogState(() => editFrequency = value.first),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: callsign,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [UpperCaseFormatter()],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Indicativo',
                            ),
                            validator: _required,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: via,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [UpperCaseFormatter()],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'Via'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: operator,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [CapitalizeWordsFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Nome do operador',
                      ),
                      validator: _required,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 10),
                    GridLocatorField(controller: location, allowInvalid: true),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: power,
                            inputFormatters: [PowerFormatter()],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Potência (W)',
                            ),
                            validator: _required,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ChoiceField(
                            controller: station,
                            label: 'Estação',
                            values: const {
                              'P': 'Portátil',
                              'M': 'Móvel',
                              'F': 'Fixa',
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ChoiceField(
                            controller: energy,
                            label: 'Energia',
                            values: const {
                              'B': 'Bateria',
                              'G': 'Gerador',
                              'AC': 'Rede elétrica',
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ChoiceField(
                            controller: traffic,
                            label: 'Tráfego',
                            values: const {
                              'S': 'Sem tráfego',
                              'C': 'Com tráfego',
                            },
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (_choiceCode(traffic.text) == 'C') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: trafficMessage,
                        inputFormatters: [UpperCaseFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Mensagem (tráfego)',
                        ),
                        validator: _required,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!key.currentState!.validate()) return;
                  if (_rejectInvalidGrid(location.text.trim(), 'localização')) {
                    return;
                  }
                  if (_rejectInvalidGrid(
                    widget.profile.grid,
                    'grid do operador',
                  )) {
                    return;
                  }
                  await widget.database.updateLog(
                    id: entry.id,
                    frequency: editFrequency,
                    frequencyMhz: editFrequency == _simplexFrequency
                        ? 146.52
                        : 145.37,
                    repeaterGrid: editFrequency == _simplexFrequency
                        ? ''
                        : (entry.repeaterGrid ?? ''),
                    callsign: callsign.text.trim().toUpperCase(),
                    via: via.text.trim().toUpperCase(),
                    operatorName: capitalizeWordInitials(operator.text.trim()),
                    location: location.text.trim(),
                    powerWatts: double.parse(power.text.replaceAll(',', '.')),
                    stationType: _choiceCode(station.text),
                    traffic: _choiceCode(traffic.text),
                    energy: _choiceCode(energy.text),
                    trafficMessage: trafficMessage.text.trim(),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      for (final controller in [
        callsign,
        via,
        operator,
        location,
        power,
        station,
        traffic,
        energy,
        trafficMessage,
      ]) {
        controller.dispose();
      }
    }
  }
}

String _choiceCode(String value) =>
    value.split(' - ').first.trim().toUpperCase();

class _FrequencyLabel extends StatelessWidget {
  const _FrequencyLabel(this.name, this.frequency);

  final String name;
  final String frequency;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(name),
      const SizedBox(width: 6),
      Text(
        '$frequency MHz',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5),
      ),
    ],
  );
}

class _ChoiceField extends StatefulWidget {
  const _ChoiceField({
    required this.controller,
    this.focusNode,
    required this.label,
    required this.values,
    this.onSubmitted,
    this.onChanged,
    this.textInputAction,
    this.keyboardOptimized = false,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final Map<String, String> values;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool keyboardOptimized;

  @override
  State<_ChoiceField> createState() => _ChoiceFieldState();
}

class _ChoiceFieldState extends State<_ChoiceField> {
  late FocusNode _focusNode;
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _ChoiceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.hasFocus) {
        _menuKey.currentState?.showButtonMenu();
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) => TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          readOnly: !widget.keyboardOptimized,
          showCursor: widget.keyboardOptimized,
          onFieldSubmitted: (value) {
            final code = _choiceCode(value);
            if (widget.values.containsKey(code)) {
              widget.onSubmitted?.call(value);
            } else {
              if (widget.focusNode != null) {
                FocusScope.of(context).requestFocus(widget.focusNode);
              }
            }
          },
          onChanged: widget.onChanged,
          textInputAction: widget.textInputAction ?? TextInputAction.next,
          onEditingComplete: () {
            final code = _choiceCode(widget.controller.text);
            if (!widget.values.containsKey(code)) {
              if (widget.focusNode != null) {
                FocusScope.of(context).requestFocus(widget.focusNode);
              }
              return;
            }
            widget.controller.text = '$code - ${widget.values[code]}';
            FocusScope.of(context).nextFocus();
          },
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            UpperCaseFormatter(),
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: ExcludeFocus(
              child: PopupMenuButton<String>(
                key: _menuKey,
                requestFocus: false,
                onSelected: (value) {
                  widget.controller.text = '$value - ${widget.values[value]}';
                  widget.onChanged?.call(value);
                },
                itemBuilder: (_) => widget.values.entries
                    .map(
                      (e) => PopupMenuItem(
                        value: e.key,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: e.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: ' - ${e.value}'),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) =>
              widget.values.containsKey(_choiceCode(value ?? ''))
              ? null
              : 'Use ${widget.values.keys.join(', ')}',
        ),
      );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.profile,
    required this.theme,
    this.displayTimeZone = DisplayTimeZone.brasilia,
    required this.mergePrecision,
    required this.lastOnly,
    required this.mapMaxAgeHours,
    required this.keepScreenOn,
    this.keyboardOptimized = false,
    this.homeLayout = HomeLayout.bottomPanels,
    required this.showCompass,
    this.focusNewRecord = false,
    required this.database,
    this.repeaterGrid = defaultRepeaterGrid,
  });
  final OperatorProfile profile;
  final AppTheme theme;
  final DisplayTimeZone displayTimeZone;
  final bool mergePrecision;
  final bool lastOnly;
  final int mapMaxAgeHours;
  final bool keepScreenOn;
  final bool keyboardOptimized;
  final HomeLayout homeLayout;
  final bool showCompass;
  final bool focusNewRecord;
  final UsraDatabase database;
  final String repeaterGrid;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Future<PackageInfo> packageInfo = PackageInfo.fromPlatform();
  late final repeaterGrid = TextEditingController(text: widget.repeaterGrid);
  late final callsign = TextEditingController(text: widget.profile.callsign);
  late final name = TextEditingController(text: widget.profile.name);
  late final grid = TextEditingController(text: widget.profile.grid);
  late AppTheme theme = widget.theme;
  late DisplayTimeZone displayTimeZone = widget.displayTimeZone;
  bool locating = false;
  late bool mergePrecision = widget.mergePrecision;
  late bool lastOnly = widget.lastOnly;
  late bool keepScreenOn = widget.keepScreenOn;
  late bool keyboardOptimized = widget.keyboardOptimized;
  late HomeLayout homeLayout = widget.homeLayout;
  late bool showCompass = widget.showCompass;
  late bool focusNewRecord = widget.focusNewRecord;
  late final maxAgeHours = TextEditingController(
    text: widget.mapMaxAgeHours.toString(),
  );
  @override
  void dispose() {
    callsign.dispose();
    name.dispose();
    grid.dispose();
    maxAgeHours.dispose();
    repeaterGrid.dispose();
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
        const SizedBox(height: 20),
        DropdownButtonFormField<DisplayTimeZone>(
          initialValue: displayTimeZone,
          decoration: const InputDecoration(
            labelText: 'Fuso horário de exibição',
          ),
          items: DisplayTimeZone.values
              .map(
                (zone) =>
                    DropdownMenuItem(value: zone, child: Text(zone.label)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => displayTimeZone = value);
          },
        ),
        const SizedBox(height: 28),
        DropdownButtonFormField<HomeLayout>(
          initialValue: homeLayout,
          decoration: const InputDecoration(
            labelText: 'Layout da tela principal',
          ),
          items: const [
            DropdownMenuItem(
              value: HomeLayout.bottomPanels,
              child: Text('Painéis inferiores'),
            ),
            DropdownMenuItem(
              value: HomeLayout.sidebar,
              child: Text('Barra lateral'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => homeLayout = value);
          },
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Agrupar grids de precisões diferentes'),
          subtitle: const Text(
            'Usa o grid mais preciso para a mesma área e indicativo.',
          ),
          value: mergePrecision,
          onChanged: (value) => setState(() => mergePrecision = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar somente o último contato por pessoa'),
          subtitle: const Text(
            'Exibe apenas um marcador para cada indicativo.',
          ),
          value: lastOnly,
          onChanged: (value) => setState(() => lastOnly = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Manter a tela ativa'),
          subtitle: const Text(
            'Impede que a tela desligue enquanto o aplicativo estiver aberto.',
          ),
          value: keepScreenOn,
          onChanged: (value) => setState(() => keepScreenOn = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Modo otimizado para teclado'),
          subtitle: const Text(
            'Permite abrir o teclado ao tocar nos campos de seleção.',
          ),
          value: keyboardOptimized,
          onChanged: (value) => setState(() => keyboardOptimized = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar bússola no mapa'),
          subtitle: const Text(
            'Exibe a bússola e o azimute no canto inferior esquerdo do mapa.',
          ),
          value: showCompass,
          onChanged: (value) => setState(() => showCompass = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Focar automaticamente no novo registro'),
          subtitle: const Text(
            'Move o mapa para a localização sempre que um registro for salvo.',
          ),
          value: focusNewRecord,
          onChanged: (value) => setState(() => focusNewRecord = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: maxAgeHours,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Exibir contatos das últimas (horas)',
            helperText:
                'Contatos mais antigos continuam salvos, mas não aparecem no mapa.',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Localização da repetidora',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        GridLocatorField(
          controller: repeaterGrid,
          labelText: 'Grid da repetidora',
        ),
        const SizedBox(height: 24),
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
          textCapitalization: TextCapitalization.words,
          inputFormatters: [CapitalizeWordsFormatter()],
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
        Text(
          'Dados do logbook',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _exportCsv,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Exportar registros para CSV'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _importing ? null : _importCsv,
          icon: const Icon(Icons.file_download_outlined),
          label: Text(
            _importing ? 'Importando...' : 'Importar registros de CSV',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: _save, child: const Text('Salvar alterações')),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Sobre',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        FutureBuilder<PackageInfo>(
          future: packageInfo,
          builder: (context, snapshot) {
            final info = snapshot.data;
            final version = info == null
                ? 'Carregando versão...'
                : 'Versão ${info.version} (${info.buildNumber})';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(version),
              subtitle: const Text(AppBranding.aboutSummary),
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(AppBranding.aboutCredit),
        const SizedBox(height: 6),
        const SelectableText('Site da USRA: ${AppBranding.website}'),
      ],
    ),
  );
  bool _importing = false;

  Future<void> _exportCsv() async {
    try {
      final csv = logsToCsv(await widget.database.allLogs());
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(csv)),
              mimeType: 'text/csv',
              name: 'usra-r3-logbook.csv',
            ),
          ],
          subject: AppBranding.csvSubject,
        ),
      );
    } catch (error) {
      if (mounted) _showTransferError(error);
    }
  }

  Future<void> _importCsv() async {
    setState(() => _importing = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      final bytes = files.isEmpty ? null : await files.single.readAsBytes();
      if (bytes == null) return;
      final entries = csvToLogCompanions(utf8.decode(bytes));
      if (entries.isEmpty) {
        throw const FormatException('O arquivo não possui registros.');
      }
      await widget.database.importLogs(entries);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${entries.length} registro(s) importado(s).'),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showTransferError(error);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showTransferError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Falha na transferência: $error')));
  }

  void _save() {
    if (!GridLocator.inspect(repeaterGrid.text).isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um grid válido para a repetidora.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _SettingsResult(
        OperatorProfile(
          callsign: callsign.text.trim().toUpperCase(),
          name: capitalizeWordInitials(name.text.trim()),
          grid: grid.text.trim().toUpperCase(),
        ),
        theme,
        mergePrecision,
        lastOnly,
        math.max(
          1,
          int.tryParse(maxAgeHours.text.trim()) ?? widget.mapMaxAgeHours,
        ),
        keepScreenOn,
        keyboardOptimized,
        homeLayout,
        showCompass,
        focusNewRecord,
        GridLocator.inspect(repeaterGrid.text).normalized,
        displayTimeZone,
      ),
    );
  }

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
  const _SettingsResult(
    this.profile,
    this.theme,
    this.mergePrecision,
    this.lastOnly,
    this.mapMaxAgeHours,
    this.keepScreenOn,
    this.keyboardOptimized,
    this.homeLayout,
    this.showCompass,
    this.focusNewRecord,
    this.repeaterGrid,
    this.displayTimeZone,
  );
  final OperatorProfile profile;
  final AppTheme theme;
  final bool mergePrecision;
  final bool lastOnly;
  final int mapMaxAgeHours;
  final bool keepScreenOn;
  final bool keyboardOptimized;
  final HomeLayout homeLayout;
  final bool showCompass;
  final bool focusNewRecord;
  final String repeaterGrid;
  final DisplayTimeZone displayTimeZone;
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          child: Image.asset(AppBranding.markAsset, width: 28, height: 28),
        ),
        const SizedBox(width: 10),
        const Text(
          AppBranding.name,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
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

const _lowercaseNameConnectors = <String>{
  'a',
  'ante',
  'ao',
  'aos',
  'após',
  'as',
  'até',
  'com',
  'contra',
  'da',
  'das',
  'de',
  'do',
  'dos',
  'dum',
  'duma',
  'dumas',
  'duns',
  'e',
  'em',
  'entre',
  'mas',
  'na',
  'nas',
  'nem',
  'no',
  'nos',
  'o',
  'os',
  'para',
  'pelo',
  'pelos',
  'pela',
  'pelas',
  'perante',
  'por',
  'que',
  'se',
  'sem',
  'sob',
  'sobre',
  'trás',
  'um',
  'uma',
  'umas',
  'uns',
  'ou',
  'num',
  'numa',
  'numas',
  'nuns',
  'à',
  'às',
};

String capitalizeWordInitials(String value) {
  final wordPattern = RegExp(r'\S+');
  return value.replaceAllMapped(wordPattern, (match) {
    final word = match.group(0)!;
    final lowercaseWord = word.toLowerCase();
    if (_lowercaseNameConnectors.contains(lowercaseWord)) {
      return lowercaseWord;
    }
    return _capitalizeFirstLetter(word);
  });
}

String _capitalizeFirstLetter(String value) {
  var offset = 0;
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    final length = character.length;
    final isLetter = character.toUpperCase() != character.toLowerCase();
    if (isLetter) {
      return '${value.substring(0, offset)}${character.toUpperCase()}${value.substring(offset + length)}';
    }
    offset += length;
  }
  return value;
}

class CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: capitalizeWordInitials(newValue.text));
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
