import 'package:excel/excel.dart' as excel_f;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/hive_helper.dart';
import '../models/daily_sale.dart';
import '../services/excel_export_service.dart';

class DailySalesReportScreen extends StatefulWidget {
  const DailySalesReportScreen({super.key});

  @override
  State<DailySalesReportScreen> createState() => _DailySalesReportScreenState();
}

class _DailySalesReportScreenState extends State<DailySalesReportScreen> {
  static const Color _primaryColor = Color(0xFF263238);
  static const Color _accentColor = Color(0xFF386641);

  late DateTimeRange selectedDateRange;
  List<DailySale> sales = [];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    selectedDateRange = DateTimeRange(start: todayDate, end: todayDate);
    loadSales();
  }

  void loadSales() {
    setState(() {
      sales = HiveHelper.getDailySalesForDateRange(
        selectedDateRange.start,
        selectedDateRange.end,
      );
    });
  }

  Future<void> chooseDateRange() async {
    final dateRange = await showDateRangePicker(
      context: context,
      initialDateRange: selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: _primaryColor,
              onPrimary: Colors.white,
              secondary: _accentColor,
              onSecondary: Colors.white,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: _primaryColor,
              headerForegroundColor: Colors.white,
              rangeSelectionBackgroundColor: _accentColor.withValues(
                alpha: 0.18,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (dateRange == null || !mounted) return;

    setState(() {
      selectedDateRange = dateRange;
      sales = HiveHelper.getDailySalesForDateRange(
        dateRange.start,
        dateRange.end,
      );
    });
  }

  Future<void> showUnitSales(String unit) async {
    final matchingSales = sales.where((sale) {
      final saleUnit = sale.units.trim().isEmpty
          ? 'Not specified'
          : sale.units.trim();
      return saleUnit == unit;
    }).toList();

    await _showSalesDialog(
      title: '$unit unit customers',
      records: matchingSales,
      icon: Icons.people_outline,
      accentColor: _accentColor,
    );
  }

  Future<void> showSummarySales(
    String title,
    Iterable<DailySale> matchingSales,
  ) async {
    final isExisting = title == 'Existing Cards';
    final isNotInMaster = title == 'Cards Not in Master';

    await _showSalesDialog(
      title: title,
      records: matchingSales.toList(),
      icon: isExisting
          ? Icons.verified_user_outlined
          : isNotInMaster
          ? Icons.person_add_alt_1
          : Icons.groups_outlined,
      accentColor: isExisting
          ? _accentColor
          : isNotInMaster
          ? Colors.deepOrange.shade700
          : _primaryColor,
    );
  }

  Future<void> _showSalesDialog({
    required String title,
    required List<DailySale> records,
    required IconData icon,
    required Color accentColor,
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                color: accentColor,
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$formattedDateRange  |  ${records.length} cards',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'CUSTOMER DETAILS',
                        style: TextStyle(
                          color: Color(0xFF626A6D),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'UNITS',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: records.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 40,
                                color: Color(0xFF879093),
                              ),
                              SizedBox(height: 10),
                              Text('No matching customer records.'),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: records.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 42),
                        itemBuilder: (context, index) {
                          final sale = records[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sale.name.isEmpty
                                            ? 'Unnamed Customer'
                                            : sale.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Ration card: ${sale.rationCard}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF626A6D),
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (selectedDateRange.start !=
                                          selectedDateRange.end) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          sale.date,
                                          style: const TextStyle(
                                            color: Color(0xFF879093),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                      if (sale.isDeleted) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Removed from View Records',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 52,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    sale.units.isEmpty ? 'N/A' : sale.units,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E5E5))),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('DONE'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get existingCount => sales.where((sale) => sale.isExistingCard).length;

  int get newCount => sales.length - existingCount;

  Map<String, int> get unitCounts {
    final counts = <String, int>{};
    for (final sale in sales) {
      final unit = sale.units.isEmpty ? 'Not specified' : sale.units;
      counts.update(unit, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  List<String> get sortedUnits {
    final units = unitCounts.keys.toList();
    units.sort((first, second) {
      final firstNumber = int.tryParse(first);
      final secondNumber = int.tryParse(second);
      if (firstNumber != null && secondNumber != null) {
        return firstNumber.compareTo(secondNumber);
      }
      if (firstNumber != null) return -1;
      if (secondNumber != null) return 1;
      return first.compareTo(second);
    });
    return units;
  }

  String get dateFileSuffix =>
      '${_dateFilePart(selectedDateRange.start)}_to_'
      '${_dateFilePart(selectedDateRange.end)}';

  String _dateFilePart(DateTime date) =>
      '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> exportToExcel() async {
    try {
      final workbook = excel_f.Excel.createExcel();
      workbook.rename('Sheet1', 'Daily Sales');
      final sheet = workbook['Daily Sales'];

      sheet.appendRow([
        excel_f.TextCellValue('Daily Sales Report'),
        excel_f.TextCellValue(formattedDateRange),
      ]);
      sheet.appendRow([
        excel_f.TextCellValue('Existing'),
        excel_f.IntCellValue(existingCount),
        excel_f.TextCellValue('Not in Master'),
        excel_f.IntCellValue(newCount),
        excel_f.TextCellValue('Total Cards'),
        excel_f.IntCellValue(sales.length),
      ]);
      sheet.appendRow([
        excel_f.TextCellValue('Customer Name'),
        excel_f.TextCellValue('Ration Card Number'),
        excel_f.TextCellValue('Units'),
        excel_f.TextCellValue('Master Status'),
        excel_f.TextCellValue('Record Status'),
      ]);

      for (final sale in sales) {
        sheet.appendRow([
          excel_f.TextCellValue(sale.name),
          excel_f.TextCellValue(sale.rationCard),
          excel_f.TextCellValue(sale.units),
          excel_f.TextCellValue(
            sale.isExistingCard ? 'Existing' : 'Not in Master',
          ),
          excel_f.TextCellValue(sale.isDeleted ? 'Removed' : 'Recorded'),
        ]);
      }

      sheet.appendRow([excel_f.TextCellValue('Cards by Units')]);
      for (final unit in sortedUnits) {
        sheet.appendRow([
          excel_f.TextCellValue(unit),
          excel_f.IntCellValue(unitCounts[unit]!),
        ]);
      }

      final bytes = workbook.encode();
      if (bytes == null) throw Exception('Unable to create Excel file.');

      await ExcelExportService.saveExcel(
        bytes,
        'DailySales_$dateFileSuffix.xlsx',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel report exported successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Excel export failed: $error')));
    }
  }

  Future<void> exportToPdf() async {
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansTelugu-Regular.ttf',
      );
      final reportFont = pw.Font.ttf(fontData);
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (_) => [
            pw.Text(
              'Daily Sales Report',
              style: pw.TextStyle(
                font: reportFont,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Date: $formattedDateRange',
              style: pw.TextStyle(font: reportFont),
            ),
            pw.Text(
              'Existing: $existingCount    '
              'Not in Master: $newCount    Total Cards: ${sales.length}',
              style: pw.TextStyle(font: reportFont),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Customer Name',
                'Ration Card Number',
                'Units',
                'Master Status',
                'Record Status',
              ],
              data: sales.map((sale) {
                return [
                  sale.name,
                  sale.rationCard,
                  sale.units,
                  sale.isExistingCard ? 'Existing' : 'Not in Master',
                  sale.isDeleted ? 'Removed' : 'Recorded',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                font: reportFont,
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: pw.TextStyle(font: reportFont, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Cards by Units',
              style: pw.TextStyle(
                font: reportFont,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TableHelper.fromTextArray(
              headers: const ['Units', 'Cards'],
              data: sortedUnits
                  .map((unit) => [unit, '${unitCounts[unit]}'])
                  .toList(),
              headerStyle: pw.TextStyle(
                font: reportFont,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: pw.TextStyle(font: reportFont),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await document.save(),
        filename: 'DailySales_$dateFileSuffix.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF report exported successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  String get formattedDateRange =>
      '${_formatDate(selectedDateRange.start)} - '
      '${_formatDate(selectedDateRange.end)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Sales Report'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export report',
            onSelected: (format) {
              if (format == 'pdf') {
                exportToPdf();
              } else {
                exportToExcel();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
              PopupMenuItem(value: 'excel', child: Text('Export as Excel')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            width: double.infinity,
            height: 55,
            child: OutlinedButton.icon(
              onPressed: chooseDateRange,
              icon: const Icon(Icons.date_range),
              label: Text(
                formattedDateRange,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryTile(
                  label: 'Existing',
                  value: existingCount,
                  color: Colors.green.shade700,
                  onTap: () => showSummarySales(
                    'Existing Cards',
                    sales.where((sale) => sale.isExistingCard),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryTile(
                  label: 'Not in Master',
                  value: newCount,
                  color: Colors.deepOrange.shade700,
                  onTap: () => showSummarySales(
                    'Cards Not in Master',
                    sales.where((sale) => !sale.isExistingCard),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryTile(
                  label: 'Total Cards',
                  value: sales.length,
                  color: const Color(0xFF263238),
                  onTap: () => showSummarySales('All Cards', sales),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Sales Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Customer / Ration Card',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Units',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (sales.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No sales recorded for this date. Import the daily sales file '
                'from View Records to add sales to this report.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...sales.map((sale) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      sale.name.isEmpty
                                          ? 'Unnamed Customer'
                                          : sale.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (sale.isDeleted) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      'Removed',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                'Ration card: ${sale.rationCard}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Text(
                            sale.units.isEmpty ? 'Not specified' : sale.units,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
          const SizedBox(height: 24),
          const Text(
            'Cards by Units',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),
          if (sortedUnits.isEmpty)
            const Text('No card records to summarize for this date.')
          else
            ...sortedUnits.map((unit) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_outline),
                title: Text(unit == 'Not specified' ? unit : '$unit units'),
                trailing: TextButton(
                  onPressed: () => showUnitSales(unit),
                  child: Text('${unitCounts[unit]} cards'),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required String label,
    required int value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
