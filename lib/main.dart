import 'package:flutter/material.dart';

void main() => runApp(const UsraR3App());

class UsraR3App extends StatelessWidget {
  const UsraR3App({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF18181B);
    return MaterialApp(
      title: 'USRA R3',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: ink),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (wide) _Sidebar(index: selectedIndex, onSelect: _select),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(wide: wide),
                      Expanded(child: _page(selectedIndex)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: _select,
                  backgroundColor: Colors.white,
                  indicatorColor: const Color(0xFFE4E4E7),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Resumo',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.radio_outlined),
                      selectedIcon: Icon(Icons.radio),
                      label: 'Operações',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.map_outlined),
                      selectedIcon: Icon(Icons.map),
                      label: 'Mapa',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: 'Ajustes',
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _select(int index) => setState(() => selectedIndex = index);

  Widget _page(int index) {
    if (index == 0) return const _Overview();
    final data = switch (index) {
      1 => (
        Icons.radio_outlined,
        'Operações',
        'Os registros de comunicação aparecerão aqui.',
      ),
      2 => (
        Icons.map_outlined,
        'Mapa operacional',
        'A camada de mapas offline será integrada nesta etapa.',
      ),
      _ => (
        Icons.settings_outlined,
        'Ajustes',
        'Configurações do dispositivo e da operação.',
      ),
    };
    return _Placeholder(icon: data.$1, title: data.$2, message: data.$3);
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.wifi_tethering, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 10),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'USRA R3',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          Text(
            'LOGBOOK',
            style: TextStyle(
              color: Color(0xFF71717A),
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ],
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    width: 232,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: Color(0xFFE4E4E7))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 16, 28),
          child: _Brand(),
        ),
        Expanded(
          child: NavigationRail(
            selectedIndex: index,
            onDestinationSelected: onSelect,
            labelType: NavigationRailLabelType.all,
            groupAlignment: -1,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFE4E4E7),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Resumo'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.radio_outlined),
                selectedIcon: Icon(Icons.radio),
                label: Text('Operações'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: Text('Mapa'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Ajustes'),
              ),
            ],
          ),
        ),
        const Padding(padding: EdgeInsets.all(16), child: _Status()),
      ],
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 20),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFE4E4E7))),
    ),
    child: Row(
      children: [
        if (!wide) const _Brand(),
        if (!wide) const Spacer(),
        IconButton(
          onPressed: () {},
          tooltip: 'Notificações',
          icon: const Icon(Icons.notifications_none),
        ),
        const SizedBox(width: 4),
        const CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFFE4E4E7),
          child: Text(
            'R3',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumo da operação',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Acompanhe o estado da rede e seus últimos registros.',
              style: TextStyle(color: Color(0xFF71717A)),
            ),
            const SizedBox(height: 24),
            const _OfflineBanner(),
            const SizedBox(height: 20),
            const Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _Metric(
                  label: 'Registros hoje',
                  value: '0',
                  icon: Icons.article_outlined,
                ),
                _Metric(
                  label: 'Estações ativas',
                  value: '0',
                  icon: Icons.cell_tower_outlined,
                ),
                _Metric(
                  label: 'Última sincronização',
                  value: 'Nunca',
                  icon: Icons.sync_outlined,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Atividade recente',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const _EmptyActivity(),
          ],
        ),
      ),
    ),
  );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F4F5),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE4E4E7)),
    ),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_outlined, size: 20, color: Color(0xFF52525B)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Modo offline pronto',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Flexible(
          child: Text(
            'Dados serão salvos neste dispositivo',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    child: Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(icon, size: 18, color: const Color(0xFF71717A)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) => Container(
    height: 150,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE4E4E7)),
    ),
    child: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, color: Color(0xFFA1A1AA), size: 24),
          SizedBox(height: 8),
          Text(
            'Nenhuma atividade registrada',
            style: TextStyle(
              color: Color(0xFF71717A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE4E4E7)),
    ),
    child: const Row(
      children: [
        Icon(Icons.circle, color: Color(0xFF16A34A), size: 9),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            'Pronto para operar',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: const Color(0xFFA1A1AA)),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF71717A)),
          ),
        ],
      ),
    ),
  );
}
