import 'dart:typed_data';

Future<void> downloadFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  throw UnsupportedError(
    'Download direto não está disponível nesta plataforma.',
  );
}
