import 'package:excel/excel.dart' as excel_f;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/hive_helper.dart';
import '../models/customer.dart';
import '../services/excel_export_service.dart';
import '../services/master_excel_import_service.dart';

class MasterCustomerScreen extends StatefulWidget {
  const MasterCustomerScreen({super.key});

  @override
  State<MasterCustomerScreen> createState() =>
      _MasterCustomerScreenState();
}

class _MasterCustomerScreenState
    extends State<MasterCustomerScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryColor = Color(0xFF263238);
  static const Color accentColor = Color(0xFFB08D57);
  static const Color backgroundColor = Color(0xFFF7F5F0);
  static const Color successColor = Color(0xFF386641);
  static const Color dangerColor = Color(0xFF8B3A3A);

  String getCurrentDateForFilename() {
    final now = DateTime.now();

    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();

    return '$day-$month-$year';
  }

  // ============================================================
  // DATA
  // ============================================================

  List<MapEntry<dynamic, Customer>> customers = [];
  List<MapEntry<dynamic, Customer>> filteredCustomers = [];

  final TextEditingController searchController =
      TextEditingController();

  int currentPage = 1;
  final int recordsPerPage = 10;

  // Selected Hive keys — persists across pagination.
  final Set<dynamic> selectedCustomerKeys = {};

  bool get hasSelectedCustomers =>
      selectedCustomerKeys.isNotEmpty;

  List<MapEntry<dynamic, Customer>> get selectedCustomers {
    return customers
        .where((entry) => selectedCustomerKeys.contains(entry.key))
        .toList();
  }

  void toggleCustomerSelection(dynamic key, bool selected) {
    setState(() {
      if (selected) {
        selectedCustomerKeys.add(key);
      } else {
        selectedCustomerKeys.remove(key);
      }
    });
  }

  void toggleSelectAllFiltered(bool selected) {
    setState(() {
      if (selected) {
        selectedCustomerKeys.addAll(
          filteredCustomers.map((entry) => entry.key),
        );
      } else {
        selectedCustomerKeys.removeAll(
          filteredCustomers.map((entry) => entry.key),
        );
      }
    });
  }

  void clearSelection() {
    setState(() {
      selectedCustomerKeys.clear();
    });
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    loadCustomers();

    searchController.addListener(() {
      searchCustomer(searchController.text);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CUSTOMERS
  // ============================================================

  Future<void> loadCustomers() async {
    final result = HiveHelper.getMasterCustomers();

    if (!mounted) return;

    setState(() {
      customers = result;
      filteredCustomers = List.from(result);

      if (currentPage > totalPages) {
        currentPage = totalPages;
      }
    });
  }

  // ============================================================
  // TRANSFER ALL MASTER CUSTOMERS TO VIEW RECORDS
  // ============================================================

  Future<void> transferAllMasterCustomers() async {
    final masterCount = HiveHelper.getMasterCustomers().length;

    if (masterCount == 0) {
      _showMessage(
        'Master Customer List is empty.',
        isError: true,
      );
      return;
    }

    // Confirm before deleting existing View Records.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Replace All View Records?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color:  Colors.green,
            ),
          ),
          content: Text(
            'This will permanently remove all existing records '
            'from View Records and replace them with all '
            '$masterCount customers from the Master Customer List.\n\n'
            'The Master Customer List will remain unchanged.\n\n'
            'Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Clear & Transfer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final transferredCount =
          await HiveHelper.replaceViewRecordsWithMasterCustomers();

      if (!mounted) return;

      _showMessage(
        '$transferredCount customers transferred successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Transfer failed: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void searchCustomer(String keyword) {
    final search = keyword.trim().toLowerCase();

    setState(() {
      if (search.isEmpty) {
        filteredCustomers = List.from(customers);
      } else {
        filteredCustomers = customers.where((entry) {
          final customer = entry.value;

          return customer.name
                  .toLowerCase()
                  .contains(search) ||
              customer.mobile.contains(search) ||
              customer.rationCard
                  .toLowerCase()
                  .contains(search) ||
              customer.aadhaar.contains(search);
        }).toList();
      }

      currentPage = 1;
    });
  }

  // ============================================================
  // PAGINATION
  // ============================================================

  List<MapEntry<dynamic, Customer>> get paginatedCustomers {
  if (filteredCustomers.isEmpty) {
    return [];
  }

  // Always keep page number at least 1.
  final safePage =
      currentPage < 1 ? 1 : currentPage;

  final start =
      (safePage - 1) * recordsPerPage;

  // Safety check
  if (start >= filteredCustomers.length) {
    return [];
  }

  final end = (start + recordsPerPage)
      .clamp(0, filteredCustomers.length);

  return filteredCustomers.sublist(
    start,
    end,
  );
}

  int get totalPages {
    if (filteredCustomers.isEmpty) {
      return 1;
    }

    return (filteredCustomers.length / recordsPerPage)
        .ceil();
  }

  // ============================================================
  // CALL
  // ============================================================

  Future<void> makeCall(String mobile) async {
    final number = mobile.trim();

    if (number.isEmpty) {
      _showMessage(
        "Mobile number is not available",
        isError: true,
      );
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: number,
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage(
          "Unable to open phone dialer",
          isError: true,
        );
      }
    } catch (e) {
      _showMessage(
        "Unable to make call",
        isError: true,
      );
    }
  }

  // ============================================================
  // SMS / TEXT
  // ============================================================

  Future<void> sendSMS(String mobile) async {
    final number = mobile.trim();

    if (number.isEmpty) {
      _showMessage(
        "Mobile number is not available",
        isError: true,
      );
      return;
    }

    final uri = Uri(
      scheme: 'sms',
      path: number,
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage(
          "Unable to open SMS app",
          isError: true,
        );
      }
    } catch (e) {
      _showMessage(
        "Unable to open SMS app",
        isError: true,
      );
    }
  }

  // ============================================================
  // COPY MOBILE NUMBER
  // ============================================================

  void copyNumber(String number) {
    Clipboard.setData(
      ClipboardData(text: number),
    );

    _showMessage(
      "Phone number copied",
    );
  }

  // ============================================================
  // ADD CUSTOMER
  // ============================================================

  Future<void> showAddDialog() async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final rationController = TextEditingController();
    final aadhaarController = TextEditingController();

    String units = "1";

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                        20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TITLE
                      Row(
                        children: [
                          const Icon(
                            Icons.person_add,
                            color: accentColor,
                            size: 28,
                          ),

                          const SizedBox(width: 10),

                          const Expanded(
                            child: Text(
                              "Add Customer",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),

                          IconButton(
                            tooltip: "Close",
                            icon: const Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 28,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // NAME
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Customer Name",
                          prefixIcon:
                              Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return "Enter Name";
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 15),

                      // MOBILE
                      TextFormField(
                        controller: mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Mobile Number",
                          prefixIcon:
                              Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // RATION CARD
                      TextFormField(
                        controller: rationController,
                        decoration: const InputDecoration(
                          labelText:
                              "Ration Card Number",
                          prefixIcon:
                              Icon(Icons.credit_card),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return "Enter Ration Card Number";
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 15),

                      // AADHAAR
                      TextFormField(
                        controller: aadhaarController,
                        keyboardType:
                            TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Aadhaar Number",
                          prefixIcon:
                              Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // UNITS
                      DropdownButtonFormField<String>(
                        value: units,
                        decoration:
                            const InputDecoration(
                          labelText: "Units",
                          border:
                              OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.people),
                        ),
                        items: const [
                          "1",
                          "2",
                          "3",
                          "4",
                          "5",
                          "6",
                          "7",
                          "8",
                          "9",
                          "10",
                          "AAY",
                        ].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setBottomState(() {
                            units = value;
                          });
                        },
                      ),

                      const SizedBox(height: 25),

                      // SAVE
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text(
                            "SAVE CUSTOMER",
                            style:
                                TextStyle(fontSize: 17),
                          ),
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.green,
                            foregroundColor:
                                Colors.white,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      10),
                            ),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!
                                .validate()) {
                              return;
                            }

                            final customer = Customer(
                              name: nameController.text
                                  .trim(),
                              mobile:
                                  mobileController.text
                                      .trim(),
                              rationCard:
                                  rationController.text
                                      .trim(),
                              aadhaar:
                                  aadhaarController.text
                                      .trim(),
                              units: units,
                            );

                            final wasUpdated =
                                await HiveHelper
                                    .saveMasterCustomer(
                              customer,
                            );

                            if (!mounted) return;

                            Navigator.pop(context);

                            await loadCustomers();

                            if (!mounted) return;

                            _showMessage(
                              wasUpdated
                                  ? "Master Customer Updated Successfully"
                                  : "Customer Added Successfully",
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    mobileController.dispose();
    rationController.dispose();
    aadhaarController.dispose();
  }

  Future<void> exportSelectedCustomersToExcel() async {
    if (selectedCustomers.isEmpty) {
      _showMessage(
        'Please select at least one customer.',
        isError: true,
      );
      return;
    }

    final selectedFields = await showExportFieldDialog();

    if (selectedFields == null || selectedFields.isEmpty) {
      return;
    }

    try {
      final workbook = excel_f.Excel.createExcel();

      final sheet = workbook['Customers List'];

      final headerStyle = excel_f.CellStyle(
        bold: true,
        horizontalAlign: excel_f.HorizontalAlign.Center,
      );

      String getFieldValue(Customer customer, String field) {
        switch (field) {
          case 'Customer Name':
            return customer.name;
          case 'Mobile Number':
            return customer.mobile;
          case 'Ration Card Number':
            return customer.rationCard;
          case 'Aadhaar Number':
            return customer.aadhaar;
          case 'Units':
            return customer.units;
          default:
            return '';
        }
      }

      for (var column = 0;
          column < selectedFields.length;
          column++) {
        sheet.setColumnWidth(column, 24);

        final cell = sheet.cell(
          excel_f.CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: 0,
          ),
        );

        cell.value = excel_f.TextCellValue(selectedFields[column]);
        cell.cellStyle = headerStyle;
      }

      for (final entry in selectedCustomers) {
        final customer = entry.value;

        sheet.appendRow(
          selectedFields.map((field) {
            return excel_f.TextCellValue(
              getFieldValue(customer, field),
            );
          }).toList(),
        );
      }

      final bytes = workbook.encode();

      if (bytes == null) {
        throw Exception('Unable to generate Excel file.');
      }

      final date = getCurrentDateForFilename();
      await ExcelExportService.saveExcel(
        bytes,
        'CustomersList_$date.xlsx',
      );

      if (!mounted) return;

      _showMessage(
        'Excel exported: ${selectedCustomers.length} customers.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Excel export failed: $e',
        isError: true,
      );
    }
  }

  Future<void> exportSelectedCustomersToPdf() async {
    if (selectedCustomers.isEmpty) {
      _showMessage(
        'Please select at least one customer.',
        isError: true,
      );
      return;
    }

    final fontData = await rootBundle.load(
      'assets/fonts/NotoSansTelugu-Regular.ttf',
    );
    final teluguFont = pw.Font.ttf(fontData);
    final selectedFields = await showExportFieldDialog();

    if (selectedFields == null || selectedFields.isEmpty) {
      return;
    }

    try {
      final document = pw.Document();

      String getFieldValue(Customer customer, String field) {
        switch (field) {
          case 'Customer Name':
            return customer.name;
          case 'Mobile Number':
            return customer.mobile;
          case 'Ration Card Number':
            return customer.rationCard;
          case 'Aadhaar Number':
            return customer.aadhaar;
          case 'Units':
            return customer.units;
          default:
            return '';
        }
      }

      final tableRows = <List<String>>[
        selectedFields,
        ...selectedCustomers.map((entry) {
          return selectedFields.map((field) {
            return getFieldValue(entry.value, field);
          }).toList();
        }),
      ];

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) {
            return [
              pw.Text(
                'Customer List',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Total customers: ${selectedCustomers.length}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 18),
              pw.TableHelper.fromTextArray(
                headers: ['S.No.', ...selectedFields],
                data: selectedCustomers.asMap().entries.map((entry) {
                  final serialNumber = entry.key + 1;
                  final customer = entry.value.value;

                  return [
                    serialNumber.toString(),
                    ...selectedFields.map((field) {
                      switch (field) {
                        case 'Customer Name':
                          return customer.name;
                        case 'Mobile Number':
                          return customer.mobile;
                        case 'Ration Card Number':
                          return customer.rationCard;
                        case 'Aadhaar Number':
                          return customer.aadhaar;
                        case 'Units':
                          return customer.units;
                        default:
                          return '';
                      }
                    }),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  font: teluguFont,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
                cellStyle: pw.TextStyle(
                  font: teluguFont,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await document.save();
      final date = getCurrentDateForFilename();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'CustomerList_$date.pdf',
      );
      if (!mounted) return;

      _showMessage(
        'PDF generated for ${selectedCustomers.length} customers.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'PDF export failed: $e',
        isError: true,
      );
    }
  }

  Future<List<String>?> showExportFieldDialog() async {
    final fields = <String, bool>{
      'Customer Name': true,
      'Mobile Number': true,
      'Ration Card Number': true,
      'Aadhaar Number': false,
      'Units': true,
    };

    return showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Export Fields'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: fields.keys.map((field) {
                    return CheckboxListTile(
                      title: Text(field),
                      value: fields[field],
                      activeColor: Colors.green,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setDialogState(() {
                          fields[field] = value ?? false;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final selectedFields = fields.entries
                        .where((entry) => entry.value)
                        .map((entry) => entry.key)
                        .toList();

                    if (selectedFields.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Select at least one field.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      selectedFields,
                    );
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // ============================================================
  // EDIT CUSTOMER
  // ============================================================

  Future<void> showEditDialog(
    dynamic hiveKey,
    Customer customer,
  ) async {
    final formKey = GlobalKey<FormState>();

    final nameController =
        TextEditingController(text: customer.name);

    final mobileController =
        TextEditingController(text: customer.mobile);

    final rationController =
        TextEditingController(text: customer.rationCard);

    final aadhaarController =
        TextEditingController(text: customer.aadhaar);

    String units = customer.units;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                        20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TITLE
                      Row(
                        children: [
                          const Icon(
                            Icons.edit,
                            color: accentColor,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Edit Customer",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      // NAME
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Customer Name",
                          prefixIcon:
                              Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return "Enter Name";
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 15),

                      // MOBILE
                      TextFormField(
                        controller: mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Mobile Number",
                          prefixIcon:
                              Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // RATION CARD
                      TextFormField(
                        controller: rationController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText:
                              "Ration Card Number",
                          prefixIcon:
                              const Icon(Icons.credit_card),
                          border:
                              const OutlineInputBorder(),
                          filled: true,
                          fillColor:
                              Colors.grey.shade100,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // AADHAAR
                      TextFormField(
                        controller: aadhaarController,
                        keyboardType:
                            TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Aadhaar Number",
                          prefixIcon:
                              Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // UNITS
                      DropdownButtonFormField<String>(
                        value: [
                          "1",
                          "2",
                          "3",
                          "4",
                          "5",
                          "6",
                          "7",
                          "8",
                          "9",
                          "10",
                          "AAY",
                        ].contains(units)
                            ? units
                            : "1",
                        decoration:
                            const InputDecoration(
                          labelText: "Units",
                          border:
                              OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.people),
                        ),
                        items: const [
                          "1",
                          "2",
                          "3",
                          "4",
                          "5",
                          "6",
                          "7",
                          "8",
                          "9",
                          "10",
                          "AAY",
                        ].map((value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setBottomState(() {
                            units = value;
                          });
                        },
                      ),

                      const SizedBox(height: 25),

                      // UPDATE
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text(
                            "UPDATE CUSTOMER",
                            style:
                                TextStyle(fontSize: 17),
                          ),
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.green,
                            foregroundColor:
                                Colors.white,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      10),
                            ),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!
                                .validate()) {
                              return;
                            }

                            final updated = Customer(
                              name: nameController.text
                                  .trim(),
                              mobile:
                                  mobileController.text
                                      .trim(),
                              rationCard:
                                  customer.rationCard,
                              aadhaar:
                                  aadhaarController.text
                                      .trim(),
                              units: units,
                            );

                            await HiveHelper
                                .updateMasterCustomer(
                              hiveKey,
                              updated,
                            );

                            if (!mounted) return;

                            Navigator.pop(context);

                            await loadCustomers();

                            if (!mounted) return;

                            _showMessage(
                              "Master Customer Updated Successfully",
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    mobileController.dispose();
    rationController.dispose();
    aadhaarController.dispose();
  }

  // ============================================================
  // MANAGE CALL STATUS
  // ============================================================

  Future<void> showCallStatusDialog(
    dynamic hiveKey,
    Customer customer,
  ) async {
    const statuses = [
      'Not Called',
      'Call Initiated',
      'Answered',
      'Not Answered',
      'Busy',
      'Call Back Required',
      'Completed',
    ];

    String selectedStatus = statuses.contains(customer.callStatus)
        ? customer.callStatus
        : 'Not Called';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Call Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Call Status',
                      border: OutlineInputBorder(),
                    ),
                    items: statuses.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedStatus = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      selectedStatus,
                    );
                  },
                  child: const Text('Save Status'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      await HiveHelper.updateCallTracking(
        isMaster: true,
        key: hiveKey,
        status: result,
        lastCalledAt: result == 'Not Called'
            ? null
            : DateTime.now(),
      );

      await loadCustomers();

      if (!mounted) return;

      _showMessage('Call status updated: $result');
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to update call status: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // DELETE CUSTOMER
  // ============================================================

  Future<void> deleteCustomer(dynamic hiveKey) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Delete Customer",
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Are you sure you want to delete this "
            "customer from the Master Customer List?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dangerColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await HiveHelper.deleteMasterCustomer(
        hiveKey,
      );

      await loadCustomers();

      if (!mounted) return;

      _showMessage(
        "Master Customer Deleted",
      );
    }
  }

  // ============================================================
  // EXCEL IMPORT
  // ============================================================

  Future<void> importMasterFromExcel() async {
    try {
      final result =
          await MasterExcelImportService.importMasterCustomers();

      final importedCustomers =
          (result["customers"]
                  as List<MapEntry<dynamic, Customer>>);

      // ---------------------------------------------------------
      // IMPORTANT
      //
      // Show ONLY the customers imported from the Excel file.
      // Do NOT reload the complete Master database here.
      // ---------------------------------------------------------

      if (importedCustomers.isNotEmpty) {
        setState(() {
          customers = List<MapEntry<dynamic, Customer>>.from(
            importedCustomers,
          );

          filteredCustomers =
              List<MapEntry<dynamic, Customer>>.from(
            importedCustomers,
          );

          currentPage = 0;
        });
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: successColor,
                  size: 28,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Master Import Completed",
                    style: TextStyle(
                      color: successColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _importResultRow(
                  "Inserted",
                  result["inserted"] ?? 0,
                  successColor,
                ),

                const SizedBox(height: 8),

                _importResultRow(
                  "Updated",
                  result["updated"] ?? 0,
                  primaryColor,
                ),

                const SizedBox(height: 8),

                _importResultRow(
                  "Skipped",
                  result["skipped"] ?? 0,
                  dangerColor,
                ),

                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${importedCustomers.length} customer(s) imported from Excel.",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "OK",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        "Master Excel import failed: $e",
        isError: true,
      );
    }
  }

  // ADD IT HERE
  Widget _importResultRow(
    String title,
    int value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
  // ============================================================
  // EXCEL EXPORT
  // ============================================================

  Future<void> exportMasterToExcel() async {
    try {
      final excel = excel_f.Excel.createExcel();
      excel.rename('Sheet1', 'Master Customers');

      final sheet =
          excel['Master Customers'];

      // Column widths
      sheet.setColumnWidth(0, 30);
      sheet.setColumnWidth(1, 18);
      sheet.setColumnWidth(2, 25);
      sheet.setColumnWidth(3, 22);
      sheet.setColumnWidth(4, 12);

      // Header style
      final headerStyle = excel_f.CellStyle(
        bold: true,
        horizontalAlign:
            excel_f.HorizontalAlign.Center,
      );

      final headers = [
        "Customer Name",
        "Mobile Number",
        "Ration Card Number",
        "Aadhaar Number",
        "Units",
      ];

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          excel_f.CellIndex.indexByColumnRow(
            columnIndex: i,
            rowIndex: 0,
          ),
        );

        cell.value =
            excel_f.TextCellValue(headers[i]);

        cell.cellStyle = headerStyle;
      }

      // Data
      final masterCustomers =
          HiveHelper.getMasterCustomers();

      for (final entry in masterCustomers) {
        final customer = entry.value;

        sheet.appendRow([
          excel_f.TextCellValue(customer.name),
          excel_f.TextCellValue(customer.mobile),
          excel_f.TextCellValue(
              customer.rationCard),
          excel_f.TextCellValue(customer.aadhaar),
          excel_f.TextCellValue(customer.units),
        ]);
      }

      final bytes = excel.encode();

      if (bytes == null) {
        throw Exception(
          "Unable to create Excel file",
        );
      }

      await ExcelExportService.saveExcel(
        bytes,
        "RiceShopMasterCustomers.xlsx",
      );

      if (!mounted) return;

      _showMessage(
        "Master Customer Excel exported successfully",
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        "Master Excel export failed: $e",
        isError: true,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? dangerColor : successColor,
      ),
    );
  }

  // ============================================================
  // CUSTOMER CARD
  // ============================================================

  // ============================================================
  // MASTER CUSTOMER CARD
  // ============================================================

  Widget buildCustomerCard(
    MapEntry<dynamic, Customer> entry,
  ) {
    final hiveKey = entry.key;
    final customer = entry.value;

    final callStatus = customer.callStatus.isEmpty
        ? 'Not Called'
        : customer.callStatus;

    final lastCalledAt = customer.lastCalledAt;

    final parsedDate = lastCalledAt == null ||
            lastCalledAt.trim().isEmpty
        ? null
        : DateTime.tryParse(lastCalledAt);

    final formattedLastCalled = parsedDate == null
        ? 'Never'
        : '${parsedDate.toLocal().day.toString().padLeft(2, '0')}/'
            '${parsedDate.toLocal().month.toString().padLeft(2, '0')}/'
            '${parsedDate.toLocal().year} '
            '${parsedDate.toLocal().hour.toString().padLeft(2, '0')}:'
            '${parsedDate.toLocal().minute.toString().padLeft(2, '0')}';

    Color getStatusColor(String status) {
      switch (status) {
        case 'Completed':
          return Colors.green;
        case 'Answered':
          return Colors.teal;
        case 'Call Back Required':
          return Colors.orange;
        case 'Not Answered':
          return Colors.deepOrange;
        case 'Busy':
          return Colors.red;
        case 'Call Initiated':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    final statusColor = getStatusColor(callStatus);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 7,
      ),
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // CUSTOMER NAME
            // ==================================================

            Row(
              children: [
                Checkbox(
                  value: selectedCustomerKeys.contains(hiveKey),
                  activeColor: Colors.green,
                  onChanged: (value) {
                    toggleCustomerSelection(
                      hiveKey,
                      value ?? false,
                    );
                  },
                ),
                CircleAvatar(
                  radius: 23,
                  backgroundColor: Colors.green.shade700,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 27,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    customer.name.isEmpty
                        ? 'Unnamed Customer'
                        : customer.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const Divider(),

            // ==================================================
            // MOBILE NUMBER
            // ==================================================

            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.phone,
                color: Colors.green,
              ),
              title: Text(
                customer.mobile.isEmpty
                    ? 'No mobile number'
                    : customer.mobile,
              ),
            ),

            // ==================================================
            // RATION CARD
            // ==================================================

            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.credit_card,
                color: Colors.green,
              ),
              title: Text(
                customer.rationCard.isEmpty
                    ? 'No ration card number'
                    : customer.rationCard,
              ),
            ),

            // ==================================================
            // AADHAAR
            // ==================================================

            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.badge,
                color: Colors.green,
              ),
              title: Text(
                customer.aadhaar.isEmpty
                    ? 'No Aadhaar number'
                    : customer.aadhaar,
              ),
            ),

            // ==================================================
            // UNITS
            // ==================================================

            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.people,
                color: Colors.green,
              ),
              title: Text(
                'Units: ${customer.units}',
              ),
            ),

            const SizedBox(height: 8),

            // ==================================================
            // CALL STATUS
            // ==================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        color: statusColor,
                        size: 21,
                      ),

                      const SizedBox(width: 8),

                      const Text(
                        'Call Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const Spacer(),

                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            callStatus,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 17,
                        color: Colors.grey.shade700,
                      ),

                      const SizedBox(width: 7),

                      Expanded(
                        child: Text(
                          'Last called: $formattedLastCalled',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ==================================================
            // ACTION BUTTONS
            // ==================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 2,
                runSpacing: 2,
                children: [
                  // CALL
                  IconButton(
                    tooltip: 'Call',
                    icon: const Icon(
                      Icons.call,
                      color: Colors.green,
                    ),
                    onPressed: customer.mobile.trim().isEmpty
                        ? null
                        : () => makeCall(customer.mobile),
                  ),

                  // UPDATE CALL STATUS
                  IconButton(
                    tooltip: 'Update Call Status',
                    icon: const Icon(
                      Icons.assignment_outlined,
                      color: Colors.blue,
                    ),
                    onPressed: () => showCallStatusDialog(
                      hiveKey,
                      customer,
                    ),
                  ),

                  // SMS
                  IconButton(
                    tooltip: 'Text / SMS',
                    icon: const Icon(
                      Icons.sms_outlined,
                      color: Colors.green,
                    ),
                    onPressed: customer.mobile.trim().isEmpty
                        ? null
                        : () => sendSMS(customer.mobile),
                  ),

                  // COPY NUMBER
                  IconButton(
                    tooltip: 'Copy Mobile Number',
                    icon: const Icon(
                      Icons.copy,
                      color: Colors.teal,
                    ),
                    onPressed: customer.mobile.trim().isEmpty
                        ? null
                        : () => copyNumber(customer.mobile),
                  ),

                  // EDIT
                  IconButton(
                    tooltip: 'Edit Customer',
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.blue,
                    ),
                    onPressed: () => showEditDialog(
                      hiveKey,
                      customer,
                    ),
                  ),

                  // DELETE
                  IconButton(
                    tooltip: 'Delete Customer',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => deleteCustomer(hiveKey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          "Master Customer List",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 2,

        actions: [
          // ====================================================
          // ADD CUSTOMER
          // ====================================================

          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1,
            ),
            tooltip: "Add Customer",
            onPressed: showAddDialog,
          ),

          // ====================================================
          // EXCEL UPLOAD
          // ====================================================

          IconButton(
            icon: const Icon(
              Icons.upload_file,
            ),
            tooltip: "Upload Master Excel",
            onPressed:
                importMasterFromExcel,
          ),

          // ====================================================
          // EXCEL EXPORT
          // ====================================================

          IconButton(
            icon: const Icon(
              Icons.file_download,
            ),
            tooltip: "Export Master Excel",
            onPressed:
                exportMasterToExcel,
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: RefreshIndicator(
        onRefresh: loadCustomers,
        child: Column(
          children: [
            // ==================================================
            // SEARCH
            // ==================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                15,
                15,
                15,
                8,
              ),
              child: TextField(
                controller:
                    searchController,
                decoration: InputDecoration(
                  hintText:
                      "Search Customer",
                  prefixIcon:
                      const Icon(Icons.search),

                  suffixIcon:
                      searchController
                              .text
                              .isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.clear,
                              ),
                              onPressed: () {
                                searchController
                                    .clear();

                                searchCustomer("");
                              },
                            ),

                  filled: true,
                  fillColor:
                      Colors.white,

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                            10),
                    borderSide:
                        BorderSide.none,
                  ),

                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                            10),
                    borderSide: BorderSide(
                      color:
                          Colors.grey.shade300,
                    ),
                  ),

                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                            10),
                    borderSide:
                        const BorderSide(
                      color: accentColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // TOTAL RECORDS
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 5,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_alt_outlined,
                    size: 20,
                    color: Colors.green,
                  ),

                  const SizedBox(width: 7),

                  Text(
                    "Total Records : "
                    "${filteredCustomers.length}",
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 15,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            if (hasSelectedCustomers)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${selectedCustomerKeys.length} customer(s) selected',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: clearSelection,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: exportSelectedCustomersToPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Download PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: exportSelectedCustomersToExcel,
                          icon: const Icon(Icons.table_view),
                          label: const Text('Download Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            
            // ==================================================
            // SELECT ALL FILTERED CUSTOMERS
            // ==================================================

            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              title: const Text(
                'Select all filtered customers',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: filteredCustomers.isNotEmpty &&
                  filteredCustomers.every(
                    (entry) =>
                        selectedCustomerKeys.contains(entry.key),
                  ),
              onChanged: (value) {
                toggleSelectAllFiltered(value ?? false);
              },
            ),

            // ============================================================
            // TRANSFER ALL TO VIEW RECORDS
            // ============================================================

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 8,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: transferAllMasterCustomers,
                  icon: const Icon(Icons.sync_alt),
                  label: const Text(
                    'TRANSFER ALL TO VIEW RECORDS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),

            // ==================================================
            // LIST
            // ==================================================

            Expanded(
              child:
                  filteredCustomers.isEmpty
                      ? ListView(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height:
                                  MediaQuery.of(
                                      context)
                                  .size
                                  .height *
                                  0.55,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Icon(
                                    Icons
                                        .people_outline,
                                    size: 85,
                                    color: Colors
                                        .grey
                                        .shade400,
                                  ),

                                  const SizedBox(
                                      height: 12),

                                  const Text(
                                    "No Customer Found",
                                    style:
                                        TextStyle(
                                      fontSize: 20,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      color:
                                          Colors.green,
                                    ),
                                  ),

                                  const SizedBox(
                                      height: 6),

                                  Text(
                                    "Add a customer or "
                                    "upload the Master Excel file.",
                                    textAlign:
                                        TextAlign
                                            .center,
                                    style: TextStyle(
                                      color: Colors
                                          .grey
                                          .shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          itemCount:
                              paginatedCustomers
                                  .length,
                          itemBuilder:
                              (context, index) {
                            return buildCustomerCard(
                              paginatedCustomers[
                                  index],
                            );
                          },
                        ),
            ),

            // ==================================================
            // PAGINATION
            // ==================================================

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.05),
                    blurRadius: 5,
                    offset:
                        const Offset(0, -2),
                  ),
                ],
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 10,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    // PREVIOUS
                    ElevatedButton.icon(
                      onPressed:
                          currentPage == 1
                              ? null
                              : () {
                                  setState(() {
                                    currentPage--;
                                  });
                                },
                      icon: const Icon(
                        Icons.chevron_left,
                      ),
                      label:
                          const Text("Previous"),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.green,
                        foregroundColor:
                            Colors.white,
                      ),
                    ),

                    // PAGE
                    Text(
                      "Page $currentPage "
                      "of $totalPages",
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),

                    // NEXT
                    ElevatedButton.icon(
                      onPressed:
                          currentPage >=
                                  totalPages
                              ? null
                              : () {
                                  setState(() {
                                    currentPage++;
                                  });
                                },
                      icon: const Icon(
                        Icons.chevron_right,
                      ),
                      label: const Text("Next"),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.green,
                        foregroundColor:
                            Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}