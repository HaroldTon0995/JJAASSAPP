import 'dart:typed_data';

Future<void> downloadFile({
  required String content,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('downloadFile is not supported on this platform.');
}

Future<void> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('downloadBytes is not supported on this platform.');
}
