import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<void> downloadFile({
  required String content,
  required String fileName,
  required String mimeType,
}) async {
  final bytes = Uint8List.fromList(content.codeUnits);
  await downloadBytes(bytes: bytes, fileName: fileName, mimeType: mimeType);
}

Future<void> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  Directory? directory;
  try {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      directory = await getDownloadsDirectory();
    }
  } catch (e) {
    // Fallback if getDownloadsDirectory is not supported or fails
  }
  directory ??= await getApplicationDocumentsDirectory();

  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(bytes);
}
