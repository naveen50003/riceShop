import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelExportService {
  static Future<void> saveExcel(
      List<int> bytes,
      String fileName,
      ) async {

    final directory =
        await getApplicationDocumentsDirectory();

    final file = File("${directory.path}/$fileName");

    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: "Rice Shop Customers",
    );
  }
}