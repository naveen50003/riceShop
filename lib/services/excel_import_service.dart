import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../database/hive_helper.dart';
import '../models/customer.dart';

class ExcelImportService {
  static Future<Map<String, int>> importCustomers() async {
    int inserted = 0;
    int updated = 0;
    int skipped = 0;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null) {
      return {
        "inserted": 0,
        "updated": 0,
        "skipped": 0,
      };
    }

    Uint8List bytes = result.files.single.bytes!;

    var excel = Excel.decodeBytes(bytes);

    var sheet = excel.tables['Customers'];

    if (sheet == null) {
      throw Exception(
        "Customers sheet not found in Excel file.",
      );
    }

    final rows = sheet.rows;

    if (rows.isEmpty) {
      throw Exception("No data found in Excel file");
    }

    for (int i = 1; i < sheet.rows.length; i++) {
      var row = sheet.rows[i];

      if (row.isEmpty) continue;

      String name =
          row.length > 0 ? row[0]?.value.toString().trim() ?? "" : "";

      String mobile =
          row.length > 1 ? row[1]?.value.toString().trim() ?? "" : "";

      String rationCard =
          row.length > 2 ? row[2]?.value.toString().trim() ?? "" : "";

      String aadhaar =
          row.length > 3 ? row[3]?.value.toString().trim() ?? "" : "";

      String units =
          row.length > 4 ? row[4]?.value.toString().trim() ?? "" : "";

      if (rationCard.isEmpty) {
        skipped++;
        continue;
      }

      Customer customer = Customer(
        name: name,
        mobile: mobile,
        rationCard: rationCard,
        aadhaar: aadhaar,
        units: units,
      );

      bool exists =
          await HiveHelper.saveOrUpdate(customer);

      if (exists) {
        updated++;
      } else {
        inserted++;
      }
    }

    return {
      "inserted": inserted,
      "updated": updated,
      "skipped": skipped,
    };
  }
}