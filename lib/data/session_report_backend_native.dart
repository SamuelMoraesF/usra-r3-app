import 'dart:typed_data';
import 'session_report_pdf_renderer.dart';
import 'session_report_request.dart';

Future<Uint8List> buildReport(SessionReportRequest request) =>
    SessionReportPdfRenderer.build(
      entries: request.entries,
      control: request.control,
      opening: request.opening,
      closing: request.closing,
      logoBytes: request.logoBytes,
      mapImages: request.mapImages,
    );
