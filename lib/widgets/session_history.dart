import 'package:flutter/material.dart';
import '../data/database.dart';

/// A collapsed session loads only its summary. Expanded pages use a bounded,
/// lazy viewport so offscreen contacts do not incur card layout costs.
class SessionHistory extends StatefulWidget {
  const SessionHistory({
    super.key,
    required this.database,
    required this.frequency,
    required this.activeSession,
    required this.title,
    required this.card,
    required this.export,
    this.map,
    this.mapSession,
    this.exporting,
  });
  final UsraDatabase database;
  final String frequency;
  final DateTime? activeSession;
  final String Function(DateTime?, DateTime?) title;
  final Widget Function(LogEntry, List<LogEntry>) card;
  final void Function(DateTime) export;
  final void Function(DateTime, DateTime)? map;
  final DateTime? mapSession;
  final DateTime? exporting;
  @override
  State<SessionHistory> createState() => _SessionHistoryState();
}

class _SessionHistoryState extends State<SessionHistory> {
  late Stream<List<LogSessionSummary>> _summaries;
  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _summaries = widget.database.watchSessionSummaries(widget.frequency);
  }

  @override
  void didUpdateWidget(SessionHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frequency != widget.frequency ||
        oldWidget.database != widget.database) {
      _subscribe();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<LogSessionSummary>>(
    stream: _summaries,
    builder: (context, snapshot) {
      final history = (snapshot.data ?? <LogSessionSummary>[])
          .where(
            (summary) =>
                summary.startedAt == null ||
                summary.startedAt != widget.activeSession,
          )
          .toList();
      return Column(
        children: [
          if (snapshot.hasData && history.isEmpty)
            const Text('Não há sessões no histórico.'),
          for (final summary in history)
            _HistorySession(
              key: ValueKey('${widget.frequency}|${summary.startedAt}'),
              owner: widget,
              summary: summary,
            ),
        ],
      );
    },
  );
}

class _HistorySession extends StatefulWidget {
  const _HistorySession({
    super.key,
    required this.owner,
    required this.summary,
  });
  final SessionHistory owner;
  final LogSessionSummary summary;
  @override
  State<_HistorySession> createState() => _HistorySessionState();
}

class _HistorySessionState extends State<_HistorySession> {
  final _scroll = ScrollController();
  final _entries = <LogEntry>[];
  bool _expanded = false, _loading = false, _done = false;
  Object? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 200) _load();
    });
  }

  @override
  void didUpdateWidget(_HistorySession oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.lastId != widget.summary.lastId ||
        oldWidget.summary.count != widget.summary.count) {
      _generation++;
      _entries.clear();
      _done = false;
      _loading = false;
      if (_expanded) _load();
    }
  }

  Future<void> _load() async {
    if (!_expanded || _loading || _done) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.owner.database.sessionPage(
        startedAt: widget.summary.startedAt,
        frequency: widget.owner.frequency,
        before: _entries.lastOrNull,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries.addAll(page);
        _done = page.length < 50;
        _loading = false;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: ValueKey('saved-session-${widget.summary.startedAt}'),
    tilePadding: const EdgeInsets.only(left: 10),
    onExpansionChanged: (value) {
      setState(() => _expanded = value);
      if (value) _load();
    },
    title: Text(
      widget.owner.title(widget.summary.startedAt, widget.summary.endedAt),
    ),
    subtitle: Text('${widget.summary.count} contatos'),
    trailing: widget.summary.startedAt != null && widget.summary.endedAt != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.owner.activeSession == null)
                IconButton(
                  key: ValueKey(
                    'session-map-button-${widget.summary.startedAt}',
                  ),
                  tooltip: widget.owner.mapSession == widget.summary.startedAt
                      ? 'Ocultar mapa da sessão'
                      : 'Mostrar sessão no mapa',
                  isSelected:
                      widget.owner.mapSession == widget.summary.startedAt,
                  selectedIcon: const Icon(Icons.map),
                  icon: const Icon(Icons.map_outlined),
                  onPressed: widget.owner.map == null
                      ? null
                      : () => widget.owner.map!(
                          widget.summary.startedAt!,
                          widget.summary.endedAt!,
                        ),
                ),
              IconButton(
                tooltip: 'Exportar relatório',
                icon: const Icon(Icons.summarize_outlined),
                onPressed: widget.owner.exporting != null
                    ? null
                    : () => widget.owner.export(widget.summary.startedAt!),
              ),
            ],
          )
        : null,
    children: [
      if (_expanded)
        SizedBox(
          height: 400,
          child: ListView.builder(
            controller: _scroll,
            itemCount: _entries.length + (_done ? 0 : 1),
            itemBuilder: (context, index) {
              if (index < _entries.length) {
                return widget.owner.card(_entries[index], _entries);
              }
              if (_loading) {
                return const Center(child: CircularProgressIndicator());
              }
              return TextButton(
                onPressed: _load,
                child: Text(
                  _error == null ? 'Carregar mais' : 'Tentar novamente',
                ),
              );
            },
          ),
        ),
    ],
  );
}
