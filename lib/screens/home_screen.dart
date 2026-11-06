import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/speech_service.dart';
import '../services/voice_parser.dart';
import '../services/missing_customer_import_service.dart';

import '../database/hive_helper.dart';
import '../models/customer.dart';
import 'records_screen.dart';
import 'master_customer_screen.dart';
import 'daily_sales_report_screen.dart';

import '../widgets/voice_icon_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();

  bool isListening = false;

  final SpeechToText speech = SpeechToText();

  final TextEditingController nameController = TextEditingController();

  final TextEditingController mobileController = TextEditingController();

  final TextEditingController rationCardController = TextEditingController();

  final TextEditingController aadhaarController = TextEditingController();

  String selectedUnits = "1";
  Customer? matchedCustomer;
  dynamic matchedCustomerKey;
  bool lookupPerformed = false;
  bool alreadyDeletedFromViewRecords = false;

  // ==========================================================
  // RATION CARD SPEECH CONVERSION
  // ==========================================================

  String convertRationCard(String speech) {
    speech = speech.toUpperCase();

    speech = speech.replaceAll(RegExp(r'\bHYPHEN\b'), '-');

    speech = speech.replaceAll(RegExp(r'\bHYPEN\b'), '-');

    speech = speech.replaceAll(RegExp(r'\bDASH\b'), '-');

    speech = speech.replaceAll(RegExp(r'\bMINUS\b'), '-');

    speech = speech.replaceAll(RegExp(r'\bDONE\b'), '');

    speech = speech.replaceAll(RegExp(r'\bSTOP\b'), '');

    speech = speech.replaceAll(RegExp(r'\s*-\s*'), '-');

    speech = speech.replaceAll(' ', '');

    speech = speech.replaceAll(RegExp(r'-{2,}'), '-');

    speech = speech.replaceAll(RegExp(r'^-|-$'), '');

    return speech;
  }

  // ==========================================================
  // SPEECH NUMBER CONVERSION
  // ==========================================================

  String convertSpeechNumbers(String speech) {
    speech = speech.toLowerCase();

    speech = speech
        .replaceAll(" HYPHEN ", "-")
        .replaceAll(" DASH ", "-")
        .replaceAll(" MINUS ", "-")
        .replaceAll(",", " ")
        .replaceAll(".", " ");

    final words = speech.split(RegExp(r'\s+'));

    const digitMap = {
      "zero": "0",
      "oh": "0",
      "o": "0",
      "one": "1",
      "two": "2",
      "three": "3",
      "four": "4",
      "five": "5",
      "six": "6",
      "seven": "7",
      "eight": "8",
      "nine": "9",

      // Telugu
      "సున్నా": "0",
      "ఒకటి": "1",
      "రెండు": "2",
      "మూడు": "3",
      "నాలుగు": "4",
      "ఐదు": "5",
      "ఆరు": "6",
      "ఏడు": "7",
      "ఎనిమిది": "8",
      "తొమ్మిది": "9",
    };

    String result = "";

    for (int i = 0; i < words.length; i++) {
      String word = words[i];

      if (word == "double" && i + 1 < words.length) {
        String next = digitMap[words[i + 1]] ?? "";

        result += next + next;

        i++;

        continue;
      }

      if (word == "triple" && i + 1 < words.length) {
        String next = digitMap[words[i + 1]] ?? "";

        result += next + next + next;

        i++;

        continue;
      }

      if (digitMap.containsKey(word)) {
        result += digitMap[word]!;

        continue;
      }

      if (RegExp(r'^\d+$').hasMatch(word)) {
        result += word;
      }
    }

    return result;
  }

  // ==========================================================
  // UNIT OPTIONS
  // ==========================================================

  final List<String> unitOptions = [
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
  ];

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    rationCardController.dispose();
    aadhaarController.dispose();

    super.dispose();
  }

  // ==========================================================
  // MASTER CUSTOMER LOOKUP
  // ==========================================================

  void lookupMasterCustomer() {
    final rationCard = rationCardController.text.trim();

    if (rationCard.isEmpty) {
      setState(() {
        matchedCustomer = null;
        matchedCustomerKey = null;
        alreadyDeletedFromViewRecords = false;
        lookupPerformed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a ration card number to search.')),
      );
      return;
    }

    final result = HiveHelper.getMasterByRationCard(rationCard);
    final existsInViewRecords =
        result != null &&
        HiveHelper.getCustomers().any(
          (entry) =>
              entry.value.rationCard.trim().toLowerCase() ==
              rationCard.toLowerCase(),
        );

    setState(() {
      lookupPerformed = true;
      matchedCustomer = result?.value;
      matchedCustomerKey = result?.key;
      alreadyDeletedFromViewRecords = result != null && !existsInViewRecords;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Ration card not found. Enter the customer details below.'
              : existsInViewRecords
              ? 'Customer found in Master and View Records.'
              : 'This customer is already deleted from View Records.',
        ),
        backgroundColor: result == null
            ? Colors.orange.shade800
            : alreadyDeletedFromViewRecords
            ? Colors.red.shade700
            : Colors.green,
      ),
    );
  }

  Future<void> editMasterCustomer() async {
    final customer = matchedCustomer;
    final customerKey = matchedCustomerKey;
    if (customer == null || customerKey == null) return;

    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: customer.name);
    final mobile = TextEditingController(text: customer.mobile);
    final rationCard = TextEditingController(text: customer.rationCard);
    final aadhaar = TextEditingController(text: customer.aadhaar);
    var units = customer.units;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Master Customer'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: inputDecoration(
                        'Customer Name',
                        Icons.person,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter Customer Name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: mobile,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 10,
                      decoration: inputDecoration('Mobile Number', Icons.phone),
                      validator: (value) =>
                          value == null ||
                              !RegExp(r'^\d{10}$').hasMatch(value.trim())
                          ? 'Enter valid Mobile Number'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: rationCard,
                      decoration: inputDecoration(
                        'Ration Card Number',
                        Icons.credit_card,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter Ration Card Number';
                        }
                        final existing = HiveHelper.getMasterByRationCard(
                          value.trim(),
                        );
                        if (existing != null && existing.key != customerKey) {
                          return 'This ration card is already assigned.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: aadhaar,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      decoration: inputDecoration(
                        'Aadhaar Number',
                        Icons.badge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: unitOptions.contains(units) ? units : '1',
                      decoration: inputDecoration('Units', Icons.people),
                      items: unitOptions.map((unit) {
                        return DropdownMenuItem(value: unit, child: Text(unit));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => units = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                await HiveHelper.updateMasterCustomer(
                  customerKey,
                  Customer(
                    name: name.text.trim(),
                    mobile: mobile.text.trim(),
                    rationCard: rationCard.text.trim(),
                    aadhaar: aadhaar.text.trim(),
                    units: units,
                    callStatus: customer.callStatus,
                    lastCalledAt: customer.lastCalledAt,
                  ),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              },
            ),
          ],
        ),
      ),
    );

    final updatedRationCard = rationCard.text.trim();
    name.dispose();
    mobile.dispose();
    rationCard.dispose();
    aadhaar.dispose();

    if (saved != true || !mounted) return;

    final updatedEntry = HiveHelper.getMasterByRationCard(updatedRationCard);
    setState(() {
      matchedCustomer = updatedEntry?.value;
      matchedCustomerKey = updatedEntry?.key;
      rationCardController.text = updatedEntry?.value.rationCard ?? '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Master customer updated successfully.')),
    );
  }

  Future<void> deleteViewRecord() async {
    final customer = matchedCustomer;
    if (customer == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete View Record?'),
        content: Text(
          'Remove ${customer.rationCard} from View Records? '
          'The Master Customer record will remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final rationCard = customer.rationCard.trim().toLowerCase();
    MapEntry<dynamic, Customer>? viewRecord;
    for (final entry in HiveHelper.getCustomers()) {
      if (entry.value.rationCard.trim().toLowerCase() == rationCard) {
        viewRecord = entry;
        break;
      }
    }

    if (viewRecord != null) {
      await HiveHelper.deleteDailySale(
        customer.rationCard,
        customer: viewRecord.value,
      );
      await HiveHelper.deleteCustomer(viewRecord.key);
    }

    if (!mounted) return;

    setState(() {
      rationCardController.clear();
      nameController.clear();
      mobileController.clear();
      aadhaarController.clear();
      selectedUnits = '1';
      matchedCustomer = null;
      matchedCustomerKey = null;
      alreadyDeletedFromViewRecords = false;
      lookupPerformed = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          viewRecord == null
              ? 'No matching record exists in View Records.'
              : 'Removed from View Records. The daily sales report is updated.',
        ),
      ),
    );
  }

  Widget buildMasterCustomerCard(Customer customer) {
    final parsedDate =
        customer.lastCalledAt == null || customer.lastCalledAt!.trim().isEmpty
        ? null
        : DateTime.tryParse(customer.lastCalledAt!);
    final formattedLastCalled = parsedDate == null
        ? 'Never'
        : '${parsedDate.toLocal().day.toString().padLeft(2, '0')}/'
              '${parsedDate.toLocal().month.toString().padLeft(2, '0')}/'
              '${parsedDate.toLocal().year} '
              '${parsedDate.toLocal().hour.toString().padLeft(2, '0')}:'
              '${parsedDate.toLocal().minute.toString().padLeft(2, '0')}';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: Colors.green.shade700,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    customer.name.isEmpty ? 'Unnamed Customer' : customer.name,
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
            const Divider(height: 24),
            if (alreadyDeletedFromViewRecords)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Already deleted from View Records.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _customerDetail(Icons.phone, customer.mobile, 'No mobile number'),
            _customerDetail(
              Icons.credit_card,
              customer.rationCard,
              'No ration card number',
            ),
            _customerDetail(Icons.badge, customer.aadhaar, 'No Aadhaar number'),
            _customerDetail(Icons.people, 'Units: ${customer.units}', ''),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Call Status: ${customer.callStatus}'),
                  const SizedBox(height: 6),
                  Text('Last called: $formattedLastCalled'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: editMasterCustomer,
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  label: const Text('EDIT MASTER'),
                ),
                if (!alreadyDeletedFromViewRecords)
                  TextButton.icon(
                    onPressed: deleteViewRecord,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      'DELETE FROM VIEW RECORDS',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _customerDetail(IconData icon, String value, String emptyLabel) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.green),
      title: Text(value.isEmpty ? emptyLabel : value),
    );
  }

  // ==========================================================
  // VOICE ASSISTANT
  // ==========================================================

  Future<void> startVoiceAssistant() async {
    await SpeechService.toggleListening("fullForm", (speechText) {
      final data = VoiceParser.parse(speechText);

      setState(() {
        if (data["name"]!.isNotEmpty) {
          nameController.text = data["name"]!;
        }

        if (data["mobile"]!.isNotEmpty) {
          mobileController.text = convertSpeechNumbers(data["mobile"]!);
        }

        if (data["ration"]!.isNotEmpty) {
          rationCardController.text = convertRationCard(data["ration"]!);

          lookupMasterCustomer();
        }

        if (data["aadhaar"]!.isNotEmpty) {
          aadhaarController.text = convertSpeechNumbers(data["aadhaar"]!);
        }

        if (data["units"]!.isNotEmpty && unitOptions.contains(data["units"])) {
          selectedUnits = data["units"]!;
        }
      });
    });
  }

  // ==========================================================
  // STOP LISTENING
  // ==========================================================

  Future<void> stopListening() async {
    await SpeechService.stopListening();

    setState(() {
      isListening = false;
    });
  }

  Future<void> uploadMissingRationCards() async {
    try {
      final result = await MissingCustomerImportService.importExcel();

      if (!mounted || result == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Excel imported successfully. '
            'Ration cards: ${result['imported']}, '
            'duplicates skipped: ${result['duplicates']}.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // ==========================================================
  // SAVE CUSTOMER TO MASTER
  // ==========================================================

  Future<void> saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final customer = Customer(
      name: nameController.text.trim(),
      mobile: mobileController.text.trim(),
      rationCard: rationCardController.text.trim(),
      aadhaar: aadhaarController.text.trim(),
      units: selectedUnits,
    );

    // Save to MASTER CUSTOMER LIST
    //
    // true  = existing ration card was updated
    // false = new ration card was inserted
    final wasUpdated = await HiveHelper.saveMasterCustomer(customer);
    await HiveHelper.recordDailySale(customer, isExistingCard: false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasUpdated
              ? "Master Customer Record Updated Successfully"
              : "Customer Added to Master Successfully",
        ),
        backgroundColor: Colors.green,
      ),
    );

    // Clear form
    nameController.clear();
    mobileController.clear();
    rationCardController.clear();
    aadhaarController.clear();

    setState(() {
      selectedUnits = "1";
      lookupPerformed = false;
      matchedCustomer = null;
      matchedCustomerKey = null;
      alreadyDeletedFromViewRecords = false;
    });
  }

  // ==========================================================
  // INPUT DECORATION
  // ==========================================================

  InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        title: const Text("Rice Shop Customer Entry"),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Card(
          elevation: 6,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          child: Padding(
            padding: const EdgeInsets.all(20),

            child: Form(
              key: _formKey,

              child: Column(
                children: [
                  // =================================================
                  // LISTENING INDICATOR
                  // =================================================

                  ValueListenableBuilder<String?>(
                    valueListenable: SpeechService.activeField,

                    builder: (_, activeField, __) {
                      if (activeField == null) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        width: double.infinity,

                        margin: const EdgeInsets.only(bottom: 15),

                        padding: const EdgeInsets.all(12),

                        decoration: BoxDecoration(
                          color: Colors.red.shade50,

                          borderRadius: BorderRadius.circular(10),

                          border: Border.all(color: Colors.red),
                        ),

                        child: const Row(
                          children: [
                            Icon(Icons.mic, color: Colors.red),

                            SizedBox(width: 10),

                            Text(
                              "Listening...",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // =================================================
                  // ICON
                  // =================================================
                  const Icon(
                    Icons.person_add_alt_1,
                    size: 70,
                    color: Colors.green,
                  ),

                  const SizedBox(height: 10),

                  // =================================================
                  // TITLE
                  // =================================================
                  const Text(
                    "Customer Details",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // RATION CARD
                  // =================================================
                  TextFormField(
                    controller: rationCardController,

                    decoration: InputDecoration(
                      labelText: "Ration Card Number",

                      border: const OutlineInputBorder(),

                      prefixIcon: const Icon(Icons.credit_card),

                      suffixIcon: VoiceIconButton(
                        fieldName: "ration",

                        beforeListening: () {
                          rationCardController.clear();
                        },

                        onResult: (text) {
                          rationCardController.text = convertRationCard(text);

                          lookupMasterCustomer();
                        },
                      ),
                    ),

                    onFieldSubmitted: (_) {
                      lookupMasterCustomer();
                    },

                    onChanged: (_) {
                      if (!lookupPerformed && matchedCustomer == null) {
                        return;
                      }

                      setState(() {
                        lookupPerformed = false;
                        matchedCustomer = null;
                        matchedCustomerKey = null;
                        alreadyDeletedFromViewRecords = false;
                        nameController.clear();
                        mobileController.clear();
                        aadhaarController.clear();
                        selectedUnits = '1';
                      });
                    },

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Enter Ration Card Number";
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: lookupMasterCustomer,
                      icon: const Icon(Icons.search),
                      label: const Text(
                        'LOOK UP RATION CARD',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                  if (!lookupPerformed) const SizedBox(height: 15),

                  if (lookupPerformed && matchedCustomer != null) ...[
                    const SizedBox(height: 16),
                    buildMasterCustomerCard(matchedCustomer!),
                  ],

                  if (lookupPerformed && matchedCustomer == null) ...[
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Customer not found. Enter details to add to Master.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: nameController,

                      decoration: inputDecoration(
                        "Customer Name",
                        Icons.person,
                      ),

                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Enter Customer Name";
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // =================================================
                    // MOBILE
                    // =================================================
                    TextFormField(
                      controller: mobileController,

                      keyboardType: TextInputType.phone,

                      maxLength: 10,

                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],

                      decoration: InputDecoration(
                        labelText: "Mobile Number",

                        border: const OutlineInputBorder(),

                        prefixIcon: const Icon(Icons.phone),

                        suffixIcon: VoiceIconButton(
                          fieldName: "mobile",

                          beforeListening: () {
                            mobileController.clear();
                          },

                          onResult: (text) {
                            mobileController.text = convertSpeechNumbers(text);
                          },
                        ),
                      ),

                      validator: (value) {
                        if (value == null ||
                            !RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                          return "Enter valid Mobile Number";
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // =================================================
                    // UNITS
                    // =================================================
                    DropdownButtonFormField<String>(
                      value: unitOptions.contains(selectedUnits)
                          ? selectedUnits
                          : null,

                      decoration: const InputDecoration(
                        labelText: "Units",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.people),
                      ),

                      items: unitOptions.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),

                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          selectedUnits = value;
                        });
                      },

                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please select Units";
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // =================================================
                    // AADHAAR
                    // =================================================
                    TextFormField(
                      controller: aadhaarController,

                      keyboardType: TextInputType.number,

                      maxLength: 12,

                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,

                        LengthLimitingTextInputFormatter(12),
                      ],

                      decoration: InputDecoration(
                        labelText: "Aadhaar Number",

                        border: const OutlineInputBorder(),

                        prefixIcon: const Icon(Icons.badge),

                        suffixIcon: VoiceIconButton(
                          fieldName: "aadhaar",

                          beforeListening: () {
                            aadhaarController.clear();
                          },

                          onResult: (text) {
                            aadhaarController.text = convertSpeechNumbers(text);
                          },
                        ),
                      ),
                    ),
                  ],

                  // =================================================
                  // LISTENING ANIMATION
                  // =================================================
                  if (isListening)
                    Column(
                      children: [
                        const Icon(
                          Icons.graphic_eq,
                          color: Colors.red,
                          size: 80,
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          "Listening...",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),

                  if (lookupPerformed && matchedCustomer == null) ...[
                    const SizedBox(height: 30),

                    // =================================================
                    // SAVE CUSTOMER
                    // =================================================
                    SizedBox(
                      width: double.infinity,
                      height: 55,

                      child: ElevatedButton.icon(
                        onPressed: saveCustomer,

                        icon: const Icon(Icons.save),

                        label: const Text(
                          "SAVE TO MASTER",
                          style: TextStyle(fontSize: 18),
                        ),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,

                          foregroundColor: Colors.white,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),
                  ],

                  // =================================================
                  // VIEW RECORDS
                  // =================================================
                  SizedBox(
                    width: double.infinity,
                    height: 55,

                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.list),

                      label: const Text(
                        "VIEW RECORDS",
                        style: TextStyle(fontSize: 18),
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => const RecordsScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bar_chart),
                      label: const Text(
                        'DAILY SALES REPORT',
                        style: TextStyle(fontSize: 18),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DailySalesReportScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 15),

                  // =================================================
                  // MASTER CUSTOMER LIST
                  // =================================================
                  SizedBox(
                    width: double.infinity,
                    height: 55,

                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.people_alt),

                      label: const Text(
                        "MASTER CUSTOMER LIST",
                        style: TextStyle(fontSize: 18),
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) => const MasterCustomerScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 30,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Missing Master Customers',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Upload an Excel file containing ration card '
                            'numbers that need to be checked against '
                            'Master Customer List.',
                          ),

                          const SizedBox(height: 14),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: uploadMissingRationCards,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('UPLOAD EXCEL FILE'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'Ration card numbers loaded: '
                            '${HiveHelper.getMissingRationCardsCount()}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
