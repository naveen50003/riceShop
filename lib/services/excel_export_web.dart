// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'dart:typed_data';

class ExcelExportService {

  static Future<void> saveExcel(
      List<int> bytes,
      String fileName,
      ) async {

    final blob = html.Blob(
      [Uint8List.fromList(bytes)],
    );

    final url =
        html.Url.createObjectUrlFromBlob(blob);

    final anchor =
        html.AnchorElement(href: url)
          ..download = fileName
          ..click();

    html.Url.revokeObjectUrl(url);
  }

}