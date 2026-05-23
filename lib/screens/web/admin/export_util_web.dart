// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

class AdminExportUtil {
  static Future<void> saveText(String content, String fileName, {String mimeType = 'text/plain'}) async {
    return saveBytes(utf8.encode(content), fileName, mimeType: mimeType);
  }

  static Future<void> saveBytes(List<int> bytes, String fileName, {String mimeType = 'application/octet-stream'}) async {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    await Future.delayed(const Duration(milliseconds: 100));
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
