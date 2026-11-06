import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../database/hive_helper.dart';

class MissingCustomerImportService {
  static Future<Map<String, int>?> importExcel() async {
    // Open file picker.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Unable to read the selected Excel file.');
    }

    // Read Excel file.
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception('The Excel file does not contain any sheets.');
    }

    final sheet = excel.tables.values.first;

    if (sheet == null || sheet.rows.isEmpty) {
      throw Exception('The selected Excel sheet is empty.');
    }

    // Find the required column.
    final headers = sheet.rows.first.map((cell) {
      return (cell?.value?.toString() ?? '')
          .trim()
          .toLowerCase();
    }).toList();

    for (int i = 0; i < sheet.rows.first.length; i++) {
      final header = sheet.rows.first[i]?.value?.toString().trim() ?? '';
      print('Column $i: "$header"');
    }

    final rationCardColumn = headers.indexOf(
      'ration card number',
    );

    if (rationCardColumn == -1) {
      throw Exception(
        'Column "Ration Card Number" was not found in the Excel file.',
      );
    }

    final Set<String> rationCards = {};
    int emptyRows = 0;
    int duplicateRows = 0;

    // Read ration card numbers.
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];

      if (rationCardColumn >= row.length) {
        emptyRows++;
        continue;
      }

      final rawValue =
          row[rationCardColumn]?.value?.toString() ?? '';

      final rationCard = rawValue.trim();

      if (rationCard.isEmpty) {
        emptyRows++;
        continue;
      }

      // Case-insensitive duplicate handling.
      final normalized = rationCard.toLowerCase();

      if (!rationCards.add(normalized)) {
        duplicateRows++;
      }
    }

    if (rationCards.isEmpty) {
      throw Exception(
        'No ration card numbers were found in the Excel file.',
      );
    }

    // Replace the old list only after successful validation.
    await HiveHelper.replaceMissingRationCards(rationCards);

    return {
      'imported': rationCards.length,
      'duplicates': duplicateRows,
      'emptyRows': emptyRows,
    };
  }
}