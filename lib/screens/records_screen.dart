import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rice_shop_appln/services/excel_import_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../database/hive_helper.dart';
import '../models/customer.dart';
import '../services/excel_export_service.dart';
import 'master_customer_screen.dart';
import 'package:excel/excel.dart' as excel_f;

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {

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
    final result = HiveHelper.getCustomers();

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

    final start =
        (currentPage - 1) * recordsPerPage;

    if (start >= filteredCustomers.length) {
      return [];
    }

    var end = start + recordsPerPage;

    if (end > filteredCustomers.length) {
      end = filteredCustomers.length;
    }

    return filteredCustomers.sublist(start, end);
  }

  int get totalPages {
    if (filteredCustomers.isEmpty) {
      return 1;
    }

    return (filteredCustomers.length / recordsPerPage).ceil();
  }

  // ============================================================
  // CALL CUSTOMER
  // ============================================================

  Future<void> makeCall(String mobile) async {
    final number = mobile.trim();

    if (number.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mobile number is not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: number,
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open phone dialer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open phone dialer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // SMS
  // ============================================================

  Future<void> sendSMS(String mobile) async {
    final uri = Uri(
      scheme: 'sms',
      path: mobile,
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ============================================================
  // WHATSAPP
  // ============================================================

  Future<void> openWhatsApp(Customer customer) async {
    final message =
        "Hello ${customer.name},\n"
        "Ration Card : ${customer.rationCard}\n"
        "Units : ${customer.units}\n"
        "from Shop 34";

    final uri = Uri.parse(
      "https://wa.me/91${customer.mobile}"
      "?text=${Uri.encodeComponent(message)}",
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  // ============================================================
  // COPY MOBILE
  // ============================================================

  void copyNumber(String number) {
    Clipboard.setData(
      ClipboardData(text: number),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Phone Number Copied Successfully",
        ),
      ),
    );
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> shareCustomer(Customer customer) async {
    await Share.share(
      '''
      Name : ${customer.name}

      Mobile : ${customer.mobile}

      Ration : ${customer.rationCard}

      Aadhaar : ${customer.aadhaar}

      Units : ${customer.units}
      ''',
    );
  }

  // ============================================================
  // EXCEL IMPORT
  // ============================================================

  Future<void> importExcel() async {
    try {
      final result =
          await ExcelImportService.importCustomers();

      await loadCustomers();

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
                    "${filteredCustomers.length} customer(s) imported from Excel.",
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Excel import failed: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
  // EXCEL EXPORT
  // ============================================================

  Future<void> exportToExcel() async {
    try {
      final excel = excel_f.Excel.createExcel();
      excel.rename('Sheet1', 'Customers');

      final sheet = excel['Customers'];

      // Column widths
      sheet.setColumnWidth(0, 30);
      sheet.setColumnWidth(1, 18);
      sheet.setColumnWidth(2, 25);
      sheet.setColumnWidth(3, 22);
      sheet.setColumnWidth(4, 12);

      // Header style
      final headerStyle = excel_f.CellStyle(
        bold: true,
        horizontalAlign: excel_f.HorizontalAlign.Center,
      );

      // Header
      sheet
          .cell(
            excel_f.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: 0,
            ),
          )
          .value = excel_f.TextCellValue(
        "Customer Name",
      );

      sheet
          .cell(
            excel_f.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: 0,
            ),
          )
          .value = excel_f.TextCellValue(
        "Mobile Number",
      );

      sheet
          .cell(
            excel_f.CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: 0,
            ),
          )
          .value = excel_f.TextCellValue(
        "Ration Card Number",
      );

      sheet
          .cell(
            excel_f.CellIndex.indexByColumnRow(
              columnIndex: 3,
              rowIndex: 0,
            ),
          )
          .value = excel_f.TextCellValue(
        "Aadhaar Number",
      );

      sheet
          .cell(
            excel_f.CellIndex.indexByColumnRow(
              columnIndex: 4,
              rowIndex: 0,
            ),
          )
          .value = excel_f.TextCellValue(
        "Units",
      );

      // Apply header style
      for (int column = 0; column < 5; column++) {
        sheet
            .cell(
              excel_f.CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: 0,
              ),
            )
            .cellStyle = headerStyle;
      }

      // Data
      for (final entry in filteredCustomers) {
        final customer = entry.value;

        sheet.appendRow([
          excel_f.TextCellValue(customer.name),
          excel_f.TextCellValue(customer.mobile),
          excel_f.TextCellValue(customer.rationCard),
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
        "RiceShopCustomers.xlsx",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Excel exported successfully",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Excel export failed: $e",
          ),
          backgroundColor: Colors.red,
        ),
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
          ),
          content: const Text(
            "Are you sure you want to delete this customer?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await HiveHelper.deleteCustomer(hiveKey);

      await loadCustomers();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Customer Deleted",
          ),
        ),
      );
    }
  }

  // ============================================================
  // EDIT CUSTOMER
  // ============================================================

  Future<void> showEditDialog(
    dynamic hiveKey,
    Customer customer,
  ) async {
    final formKey =
        GlobalKey<FormState>();

    final nameController =
        TextEditingController(
      text: customer.name,
    );

    final mobileController =
        TextEditingController(
      text: customer.mobile,
    );

    final rationController =
        TextEditingController(
      text: customer.rationCard,
    );

    final aadhaarController =
        TextEditingController(
      text: customer.aadhaar,
    );

    String units = customer.units;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder:
              (context, setBottomState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(
                      context,
                    ).viewInsets.bottom +
                    20,
              ),
              child:
                  SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      const Text(
                        "Edit Customer",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 25,
                      ),

                      // NAME
                      TextFormField(
                        controller:
                            nameController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              "Customer Name",
                          prefixIcon:
                              Icon(
                            Icons.person,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                        validator:
                            (value) {
                          if (value ==
                                  null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return "Enter Name";
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // MOBILE
                      TextFormField(
                        controller:
                            mobileController,
                        keyboardType:
                            TextInputType
                                .phone,
                        decoration:
                            const InputDecoration(
                          labelText:
                              "Mobile Number",
                          prefixIcon:
                              Icon(
                            Icons.phone,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // RATION CARD
                      TextFormField(
                        controller:
                            rationController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              "Ration Card Number",
                          prefixIcon:
                              Icon(
                            Icons.credit_card,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // AADHAAR
                      TextFormField(
                        controller:
                            aadhaarController,
                        keyboardType:
                            TextInputType
                                .number,
                        decoration:
                            const InputDecoration(
                          labelText:
                              "Aadhaar Number",
                          prefixIcon:
                              Icon(
                            Icons.badge,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // UNITS
                      DropdownButtonFormField<
                          String>(
                        value: units,
                        decoration:
                            const InputDecoration(
                          labelText: "Units",
                          border:
                              OutlineInputBorder(),
                          prefixIcon:
                              Icon(
                            Icons.people,
                          ),
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
                          return DropdownMenuItem<
                              String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged:
                            (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setBottomState(
                            () {
                              units = value;
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height: 25,
                      ),

                      // UPDATE
                      SizedBox(
                        width:
                            double.infinity,
                        height: 50,
                        child:
                            ElevatedButton
                                .icon(
                          icon:
                              const Icon(
                            Icons.save,
                          ),
                          label:
                              const Text(
                            "UPDATE CUSTOMER",
                            style:
                                TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                Colors.green,
                            foregroundColor:
                                Colors.white,
                          ),
                          onPressed:
                              () async {
                            if (!formKey
                                .currentState!
                                .validate()) {
                              return;
                            }

                            final updated =
                                Customer(
                              callStatus: customer.callStatus,
                              lastCalledAt: customer.lastCalledAt,
                              name:
                                  nameController
                                      .text
                                      .trim(),
                              mobile:
                                  mobileController
                                      .text
                                      .trim(),
                              rationCard:
                                  rationController
                                      .text
                                      .trim(),
                              aadhaar:
                                  aadhaarController
                                      .text
                                      .trim(),
                              units: units,
                            );

                            await HiveHelper
                                .updateCustomer(
                              hiveKey,
                              updated,
                            );

                            if (!mounted) {
                              return;
                            }

                            Navigator.pop(
                              context,
                            );

                            await loadCustomers();

                            if (!mounted) {
                              return;
                            }

                            ScaffoldMessenger
                                    .of(
                                        context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Customer Updated",
                                ),
                              ),
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
        isMaster: false,
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
  // VIEW RECORDS CUSTOMER CARD
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
        vertical: 8,
      ),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // CUSTOMER NAME
            // ==================================================

            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.green.shade700,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 28,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

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

                  // WHATSAPP
                  IconButton(
                    tooltip: 'WhatsApp',
                    icon: const Icon(
                      Icons.chat,
                      color: Colors.green,
                    ),
                    onPressed: customer.mobile.trim().isEmpty
                        ? null
                        : () => openWhatsApp(customer),
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

                  // SHARE CUSTOMER
                  IconButton(
                    tooltip: 'Share Customer',
                    icon: const Icon(
                      Icons.share,
                      color: Colors.blue,
                    ),
                    onPressed: () => shareCustomer(customer),
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
      backgroundColor:
          Colors.grey.shade100,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          "Customer Records",
        ),
        centerTitle: true,
        backgroundColor:
            Colors.green,
        foregroundColor:
            Colors.white,

        actions: [
          // EXCEL UPLOAD
          IconButton(
            icon: const Icon(
              Icons.upload_file,
            ),
            tooltip: "Import Excel",
            onPressed: importExcel,
          ),

          // EXCEL DOWNLOAD
          IconButton(
            icon: const Icon(
              Icons.file_download,
            ),
            tooltip: "Export Excel",
            onPressed: exportToExcel,
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
              padding:
                  const EdgeInsets.all(15),

              child: TextField(
                controller:
                    searchController,

                decoration:
                    InputDecoration(
                  hintText:
                      "Search Customer",

                  prefixIcon:
                      const Icon(
                    Icons.search,
                  ),

                  suffixIcon:
                      searchController
                              .text
                              .isEmpty
                          ? null
                          : IconButton(
                              icon:
                                  const Icon(
                                Icons.clear,
                              ),
                              onPressed:
                                  () {
                                searchController
                                    .clear();

                                searchCustomer(
                                  "",
                                );
                              },
                            ),

                  filled: true,

                  fillColor:
                      Colors.white,

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      15,
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // TOTAL
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 15,
              ),

              child: Row(
                children: [
                  Text(
                    "Total Records : "
                    "${filteredCustomers.length}",

                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            // ==================================================
            // LIST
            // ==================================================

            Expanded(
              child:
                  filteredCustomers.isEmpty
                      ? Center(
                          child:
                              Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              const Icon(
                                Icons
                                    .people_outline,
                                size: 90,
                                color:
                                    Colors.grey,
                              ),

                              const SizedBox(
                                height: 10,
                              ),

                              const Text(
                                "No Customer Found",
                                style:
                                    TextStyle(
                                  fontSize:
                                      20,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              const Padding(
                                padding:
                                    EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      20,
                                ),
                                child:
                                    Text(
                                  "Customer may be available in "
                                  "Master Customer List",
                                  textAlign:
                                      TextAlign
                                          .center,
                                  style:
                                      TextStyle(
                                    fontSize:
                                        14,
                                    color:
                                        Colors
                                            .grey,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height: 20,
                              ),

                              // =================================================
                              // VIEW MASTER CUSTOMERS
                              // =================================================

                              ElevatedButton
                                  .icon(
                                icon:
                                    const Icon(
                                  Icons
                                      .people_alt,
                                ),

                                label:
                                    const Text(
                                  "VIEW MASTER CUSTOMERS",
                                  style:
                                      TextStyle(
                                    fontSize:
                                        16,
                                  ),
                                ),

                                style:
                                    ElevatedButton
                                        .styleFrom(
                                  backgroundColor:
                                      Colors
                                          .green,
                                  foregroundColor:
                                      Colors
                                          .white,
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        20,
                                    vertical:
                                        14,
                                  ),
                                ),

                                onPressed:
                                    () {
                                  Navigator
                                      .push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) =>
                                              const MasterCustomerScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics:const AlwaysScrollableScrollPhysics(),
                          itemCount:paginatedCustomers.length,

                          itemBuilder:
                              (context,
                                  index) {
                            final entry =
                                paginatedCustomers[
                                    index];

                            return buildCustomerCard(entry);                          },
                        ),
            ),

            // ==================================================
            // PAGINATION
            // ==================================================

            Container(
              color: Colors.white,

              padding:
                  const EdgeInsets.all(15),

              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,

                children: [
                  ElevatedButton(
                    onPressed:
                        currentPage == 1
                            ? null
                            : () {
                                setState(() {
                                  currentPage--;
                                });
                              },
                    child:
                        const Text(
                      "Previous",
                    ),
                  ),

                  Text(
                    "Page $currentPage "
                    "of $totalPages",

                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  ElevatedButton(
                    onPressed:
                        currentPage >=
                                totalPages
                            ? null
                            : () {
                                setState(() {
                                  currentPage++;
                                });
                              },
                    child:
                        const Text(
                      "Next",
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
}