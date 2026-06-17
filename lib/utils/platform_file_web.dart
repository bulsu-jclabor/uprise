import 'dart:typed_data';
import 'dart:html' as html;

Future<String> saveBytesToTemp(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  return url;
}

Future<void> saveBytesToTempAndOpen(Uint8List bytes, String filename, {String mimeType = 'application/octet-stream'}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.window.open(url, '_blank');
  } catch (_) {
    (html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click());
  }
}

Future<void> downloadBytes(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  (html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click());
  html.Url.revokeObjectUrl(url);
}

Future<void> openUrl(String url) async {
  html.window.open(url, '_blank');
}

Future<String> saveStringToTemp(String content, String filename) async {
  final blob = html.Blob([content], 'text/plain');
  final url = html.Url.createObjectUrlFromBlob(blob);
  return url;
}
