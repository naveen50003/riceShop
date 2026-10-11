import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // ============================================================
  // DATA
  // ============================================================

  List<MapEntry<dynamic, Customer>> customers = [];
  List<MapEntry<dynamic, Customer>> filteredCustomers = [];

  final TextEditingController searchController =
      TextEditingController();

  int currentPage = 1;
  final int recordsPerPage = 10;

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
      final excel = Excel.createExcel();
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
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign:
            HorizontalAlign.Center,
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
          CellIndex.indexByColumnRow(
            columnIndex: i,
            rowIndex: 0,
          ),
        );

        cell.value =
            TextCellValue(headers[i]);

        cell.cellStyle = headerStyle;
      }

      // Data
      final masterCustomers =
          HiveHelper.getMasterCustomers();

      for (final entry in masterCustomers) {
        final customer = entry.value;

        sheet.appendRow([
          TextCellValue(customer.name),
          TextCellValue(customer.mobile),
          TextCellValue(
              customer.rationCard),
          TextCellValue(customer.aadhaar),
          TextCellValue(customer.units),
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

  Widget buildCustomerCard(
    MapEntry<dynamic, Customer> entry,
  ) {
    final hiveKey = entry.key;
    final customer = entry.value;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 7,
      ),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ==================================================
            // CUSTOMER NAME
            // ==================================================

            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor:
                      Colors.green,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    customer.name,
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
            // MOBILE
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
                    ? "No mobile number"
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
                customer.rationCard,
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
                    ? "No Aadhaar number"
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
                "Units : ${customer.units}",
              ),
            ),

            const SizedBox(height: 6),

            // ==================================================
            // ACTIONS
            // ==================================================

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  // CALL
                  IconButton(
                    tooltip: "Call",
                    icon: const Icon(
                      Icons.call,
                      color: successColor,
                    ),
                    onPressed:
                        customer.mobile.isEmpty
                            ? null
                            : () => makeCall(
                                  customer.mobile,
                                ),
                  ),

                  // TEXT
                  IconButton(
                    tooltip: "Text / SMS",
                    icon: const Icon(
                      Icons.sms_outlined,
                      color: Colors.green,
                    ),
                    onPressed:
                        customer.mobile.isEmpty
                            ? null
                            : () => sendSMS(
                                  customer.mobile,
                                ),
                  ),

                  // COPY
                  IconButton(
                    tooltip: "Copy Mobile Number",
                    icon: const Icon(
                      Icons.copy,
                      color: Colors.green,
                    ),
                    onPressed:
                        customer.mobile.isEmpty
                            ? null
                            : () => copyNumber(
                                  customer.mobile,
                                ),
                  ),

                  // EDIT
                  IconButton(
                    tooltip: "Edit",
                    icon: const Icon(
                      Icons.edit,
                      color: accentColor,
                    ),
                    onPressed: () =>
                        showEditDialog(
                      hiveKey,
                      customer,
                    ),
                  ),

                  // DELETE
                  IconButton(
                    tooltip: "Delete",
                    icon: const Icon(
                      Icons.delete_outline,
                      color: dangerColor,
                    ),
                    onPressed: () =>
                        deleteCustomer(
                      hiveKey,
                    ),
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