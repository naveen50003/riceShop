import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../database/hive_helper.dart';
import '../models/customer.dart';

class MasterExcelImportService {
  static Future<Map<String, dynamic>> importMasterCustomers() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    // User cancelled file selection
    if (result == null || result.files.single.bytes == null) {
      return {
        'inserted': 0,
        'updated': 0,
        'skipped': 0,
        'customers': <MapEntry<dynamic, Customer>>[],
      };
    }

    final bytes = result.files.single.bytes!;

    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception("No Excel sheet found");
    }

    // ---------------------------------------------------------
    // MASTER CUSTOMERS SHEET
    // ---------------------------------------------------------

    final sheet = excel.tables['Master Customers'];

    if (sheet == null) {
      throw Exception(
        "Master Customers sheet not found in Excel file.",
      );
    }

    final rows = sheet.rows;

    if (rows.isEmpty) {
      throw Exception("No data found in Excel file");
    }

    // ---------------------------------------------------------
    // FIND HEADER ROW
    // ---------------------------------------------------------

    int headerRowIndex = -1;

    for (int i = 0; i < rows.length; i++) {
      final hasData = rows[i].any(
        (cell) => _cellToString(cell).trim().isNotEmpty,
      );

      if (hasData) {
        headerRowIndex = i;
        break;
      }
    }

    if (headerRowIndex == -1) {
      throw Exception("No header/data found in Excel file");
    }

    // ---------------------------------------------------------
    // READ HEADERS
    // ---------------------------------------------------------

    final headers = rows[headerRowIndex].map((cell) {
      return _normalizeHeader(
        _cellToString(cell),
      );
    }).toList();

    // ---------------------------------------------------------
    // FIND COLUMN INDEXES
    // ---------------------------------------------------------

    final nameIndex = _findHeader(headers, [
      'customer name',
      'name',
      'customer',
    ]);

    final mobileIndex = _findHeader(headers, [
      'mobile number',
      'mobile',
      'phone number',
      'phone',
      'mobile no',
      'mobile no.',
    ]);

    final rationIndex = _findHeader(headers, [
      'ration card number',
      'ration card',
      'rationcard',
      'ration card no',
      'ration card no.',
      'ration',
      'rc number',
      'rc no',
      'rc no.',
    ]);

    final aadhaarIndex = _findHeader(headers, [
      'aadhaar number',
      'aadhaar',
      'aadhar number',
      'aadhar',
      'aadhaar no',
      'aadhaar no.',
      'aadhar no',
      'aadhar no.',
    ]);

    final unitsIndex = _findHeader(headers, [
      'units',
      'unit',
      'number of units',
      'no of units',
      'no. of units',
    ]);

    // ---------------------------------------------------------
    // RATION CARD IS MANDATORY
    // ---------------------------------------------------------

    if (rationIndex == -1) {
      throw Exception(
        "Ration Card Number column not found in Excel.\n\n"
        "Available columns:\n${headers.join(', ')}",
      );
    }

    // ---------------------------------------------------------
    // IMPORT DATA
    // ---------------------------------------------------------

    int inserted = 0;
    int updated = 0;
    int skipped = 0;

    final List<MapEntry<dynamic, Customer>> importedCustomers = [];

    for (
      int rowIndex = headerRowIndex + 1;
      rowIndex < rows.length;
      rowIndex++
    ) {
      final row = rows[rowIndex];

      // Ignore completely empty rows
      final hasData = row.any(
        (cell) => _cellToString(cell).trim().isNotEmpty,
      );

      if (!hasData) {
        continue;
      }

      // -------------------------------------------------------
      // RATION CARD
      // -------------------------------------------------------

      final rationCard = _getCellValue(
        row,
        rationIndex,
      ).trim();

      // Ration Card is mandatory
      if (rationCard.isEmpty) {
        skipped++;
        continue;
      }

      // -------------------------------------------------------
      // CREATE CUSTOMER
      // -------------------------------------------------------

      final customer = Customer(
        name: _getCellValue(
          row,
          nameIndex,
        ),
        mobile: _getCellValue(
          row,
          mobileIndex,
        ),
        rationCard: rationCard,
        aadhaar: _getCellValue(
          row,
          aadhaarIndex,
        ),
        units: _getCellValue(
          row,
          unitsIndex,
        ),
      );

      // -------------------------------------------------------
      // SAVE / UPDATE MASTER
      // -------------------------------------------------------

      final wasUpdated =
          await HiveHelper.saveMasterCustomer(customer);

      if (wasUpdated) {
        updated++;
      } else {
        inserted++;
      }

      // -------------------------------------------------------
      // GET ACTUAL HIVE ENTRY
      //
      // This gives us the Hive key + Customer object so the
      // Master screen can immediately display the imported rows.
      // -------------------------------------------------------

      final savedEntry =
          HiveHelper.getMasterByRationCard(rationCard);

      if (savedEntry != null) {
        importedCustomers.add(savedEntry);
      }
    }

    return {
      'inserted': inserted,
      'updated': updated,
      'skipped': skipped,
      'customers': importedCustomers,
    };
  }

  // ===========================================================
  // FIND HEADER
  // ===========================================================

  static int _findHeader(
    List<String> headers,
    List<String> possibleNames,
  ) {
    for (final possibleName in possibleNames) {
      final normalizedName =
          _normalizeHeader(possibleName);

      final index = headers.indexOf(normalizedName);

      if (index != -1) {
        return index;
      }
    }

    return -1;
  }

  // ===========================================================
  // NORMALIZE HEADER
  // ===========================================================

  static String _normalizeHeader(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('.', '')
        .replaceAll('_', ' ');
  }

  // ===========================================================
  // GET CELL VALUE
  // ===========================================================

  static String _getCellValue(
    List<Data?> row,
    int index,
  ) {
    if (index == -1 || index >= row.length) {
      return '';
    }

    return _cellToString(row[index]).trim();
  }

  // ===========================================================
  // CONVERT EXCEL CELL TO STRING
  // ===========================================================

  static String _cellToString(Data? cell) {
    if (cell == null || cell.value == null) {
      return '';
    }

    final value = cell.value;

    // Text
    if (value is TextCellValue) {
      return value.value.text ?? '';
    }

    // Integer
    if (value is IntCellValue) {
      return value.value.toString();
    }

    // Decimal
    if (value is DoubleCellValue) {
      final number = value.value;

      if (number == number.toInt()) {
        return number.toInt().toString();
      }

      return number.toString();
    }

    // Formula
    if (value is FormulaCellValue) {
      return value.toString();
    }

    // Boolean
    if (value is BoolCellValue) {
      return value.value.toString();
    }

    // DateTime
    if (value is DateTimeCellValue) {
      return value.asDateTimeLocal().toString();
    }

    return value.toString();
  }
}