import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'database.dart';

class SessionReportPdf {
  static const _repeaterCallsign = 'PY3SMA';
  static const _repeaterName = 'RPT USRA';

  static Future<Uint8List> build({
    required List<LogEntry> entries,
    required String control,
    required String opening,
    required String closing,
    required Uint8List logoBytes,
    Map<String, Uint8List> mapImages = const {},
  }) async {
    final document = pw.Document();
    final grouped = <String, List<LogEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.frequency, () => []).add(entry);
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'Relatório Técnico - Rede de Radiocomunicação Resiliente R3',
                        style: pw.TextStyle(
                          color: PdfColors.grey600,
                          fontSize: 8,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      'USRA R3',
                      style: pw.TextStyle(
                        color: PdfColors.grey600,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          pw.Center(
            child: pw.Image(
              pw.MemoryImage(logoBytes),
              width: 141.5,
              height: 141.5,
              fit: pw.BoxFit.contain,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'Relatório Técnico',
                  style: pw.TextStyle(
                    fontSize: 21,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Rede de Radiocomunicação Resiliente R3',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange50,
              border: pw.Border.all(color: PdfColors.orange700, width: 1),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _labelValue('Controle', control),
                _labelValue('Abertura', opening),
                _labelValue('Encerramento', closing),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          for (final frequency in const ['simplex', 'repeater'])
            ..._frequencySection(
              frequency,
              grouped[frequency] ?? const [],
              frequency == 'simplex'
                  ? grouped['repeater'] ?? const []
                  : grouped['simplex'] ?? const [],
              mapImages[frequency],
            ),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _labelValue(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: value),
        ],
      ),
    ),
  );

  static List<pw.Widget> _frequencySection(
    String frequency,
    List<LogEntry> entries,
    List<LogEntry> otherFrequencyEntries,
    Uint8List? mapImage,
  ) {
    final first = entries.isEmpty ? null : entries.first;
    final repeated = frequency == 'repeater';
    final stations = <String, LogEntry>{};
    for (final entry in entries) {
      stations.putIfAbsent(entry.callsign, () => entry);
    }
    final traffic = entries
        .where(
          (entry) =>
              entry.traffic == 'C' && entry.trafficMessage.trim().isNotEmpty,
        )
        .toList();
    final qrg = entries.isEmpty
        ? (repeated
              ? 'QRG: 145.370 -600 $_repeaterCallsign $_repeaterName'
              : 'QRG: 146.520')
        : repeated
        ? 'QRG: ${(first!.frequencyMhz ?? 145.37).toStringAsFixed(3)} -600 $_repeaterCallsign $_repeaterName'
        : 'QRG: ${(first!.frequencyMhz ?? 146.52).toStringAsFixed(3)} ${first.callsign} ${first.operatorName}';

    return [
      if (repeated) ...[pw.SizedBox(height: 8), pw.Divider()],
      pw.SizedBox(height: 14),
      pw.Text(
        '$qrg (${repeated ? 'repetidora' : 'simplex'})',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      if (entries.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'Sem contato realizado',
            style: pw.TextStyle(
              color: PdfColors.grey700,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      if (entries.isNotEmpty && mapImage != null) ...[
        pw.SizedBox(height: 6),
        pw.Image(
          pw.MemoryImage(mapImage),
          width: double.infinity,
          height: 285,
          fit: pw.BoxFit.contain,
        ),
      ],
      pw.SizedBox(height: 8),
      pw.Header(level: 3, text: 'Estações'),
      _stationsTable(stations.values.toList(), otherFrequencyEntries),
      if (traffic.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Header(level: 3, text: 'Tráfego'),
        _trafficTable(traffic),
      ],
    ];
  }

  static pw.Widget _stationsTable(
    List<LogEntry> entries,
    List<LogEntry> otherFrequencyEntries,
  ) {
    final current = {for (final entry in entries) entry.callsign: entry};
    final other = {
      for (final entry in otherFrequencyEntries) entry.callsign: entry,
    };
    final both = current.keys
        .where(other.containsKey)
        .map((callsign) => current[callsign]!)
        .toList();
    final currentOnly = current.keys
        .where((callsign) => !other.containsKey(callsign))
        .map((callsign) => current[callsign]!)
        .toList();
    final otherOnly = other.keys
        .where((callsign) => !current.containsKey(callsign))
        .map((callsign) => other[callsign]!)
        .toList();
    final groups = <({String title, List<LogEntry> entries})>[
      if (both.isNotEmpty)
        (title: 'Acessíveis por ambas as frequências', entries: both),
      if (currentOnly.isNotEmpty)
        (title: 'Visíveis somente nesta frequência', entries: currentOnly),
      if (otherOnly.isNotEmpty)
        (title: 'Não visíveis nesta frequência', entries: otherOnly),
    ];
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FractionColumnWidth(0.10),
      1: const pw.FractionColumnWidth(0.12),
      2: const pw.FractionColumnWidth(0.07),
      3: const pw.FractionColumnWidth(0.21),
      4: const pw.FractionColumnWidth(0.12),
      5: const pw.FractionColumnWidth(0.15),
      6: const pw.FractionColumnWidth(0.08),
      7: const pw.FractionColumnWidth(0.07),
      8: const pw.FractionColumnWidth(0.08),
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 7,
          ),
          cellStyle: const pw.TextStyle(fontSize: 7),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange100),
          cellPadding: const pw.EdgeInsets.all(4),
          columnWidths: columnWidths,
          headers: const [
            'Indicativo',
            'Nome',
            'Via',
            'Primeiro contato',
            'Grid',
            'Localização',
            'Potência',
            'Estação',
            'Energia',
          ],
          data: const [],
        ),
        for (final group in groups) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColors.orange100,
              border: pw.Border(
                top: pw.BorderSide(width: 0.5),
                bottom: pw.BorderSide(width: 0.5),
                left: pw.BorderSide(width: 1),
                right: pw.BorderSide(width: 1),
              ),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              group.title,
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
          ),
          _stationDataTable(group.entries, columnWidths),
        ],
      ],
    );
  }

  static pw.Widget _stationDataTable(
    List<LogEntry> entries,
    Map<int, pw.TableColumnWidth> columnWidths,
  ) => pw.TableHelper.fromTextArray(
    headerCount: 0,
    cellStyle: const pw.TextStyle(fontSize: 7),
    cellPadding: const pw.EdgeInsets.all(4),
    columnWidths: columnWidths,
    data: entries
        .map(
          (entry) => [
            entry.callsign.toUpperCase(),
            entry.operatorName,
            entry.via.toUpperCase(),
            _date(entry.createdAt),
            entry.operatorGrid.toUpperCase(),
            entry.location.toUpperCase(),
            '${entry.powerWatts} W',
            _station(entry.stationType),
            _energy(entry.energy),
          ],
        )
        .toList(),
  );

  static pw.Widget _trafficTable(List<LogEntry> entries) =>
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
        cellStyle: const pw.TextStyle(fontSize: 6),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellPadding: const pw.EdgeInsets.all(4),
        headers: const ['Data/hora', 'Indicativo', 'Mensagem'],
        data: entries
            .map(
              (entry) => [
                _date(entry.createdAt),
                entry.callsign,
                pw.Text(
                  entry.trafficMessage.toUpperCase(),
                  style: pw.TextStyle(font: pw.Font.courier(), fontSize: 6),
                ),
              ],
            )
            .toList(),
      );

  static String _date(DateTime value) {
    final local = value.toUtc().subtract(const Duration(hours: 3));
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)} GMT-3';
  }

  static String _station(String value) => switch (value) {
    'P' => 'Portátil',
    'M' => 'Móvel',
    'F' => 'Fixa',
    _ => value,
  };

  static String _energy(String value) => switch (value) {
    'B' => 'Bateria',
    'G' => 'Gerador',
    'AC' => 'Rede elétrica',
    _ => value,
  };
}
