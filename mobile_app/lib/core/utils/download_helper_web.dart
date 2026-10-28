import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> downloadFile({
  required String content,
  required String fileName,
  required String mimeType,
}) async {
  final bytes = utf8.encode(content);
  await downloadBytes(bytes: Uint8List.fromList(bytes), fileName: fileName, mimeType: mimeType);
}

Future<void> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
