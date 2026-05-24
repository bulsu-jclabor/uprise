import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

Future<String> saveBytesToTemp(Uint8List bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<void> saveBytesToTempAndOpen(Uint8List bytes, String filename) async {
  final path = await saveBytesToTemp(bytes, filename);
  await OpenFile.open(path);
}

Future<void> openUrl(String url) async {
  // On non-web platforms, delegate to url_launcher if needed.
  // Keeping minimal here; the caller can use url_launcher separately.
}

Future<void> downloadBytes(Uint8List bytes, String filename) async {
  await saveBytesToTempAndOpen(bytes, filename);
}

Future<String> saveStringToTemp(String content, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, flush: true);
  return file.path;
}
