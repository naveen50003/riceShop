import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/speech_service.dart';
import '../services/voice_parser.dart';

import '../database/hive_helper.dart';
import '../models/customer.dart';
import 'records_screen.dart';
import 'master_customer_screen.dart';

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

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController mobileController =
      TextEditingController();

  final TextEditingController rationCardController =
      TextEditingController();

  final TextEditingController aadhaarController =
      TextEditingController();

  String selectedUnits = "1";

  // ==========================================================
  // RATION CARD SPEECH CONVERSION
  // ==========================================================

  String convertRationCard(String speech) {
    speech = speech.toUpperCase();

    speech = speech.replaceAll(
      RegExp(r'\bHYPHEN\b'),
      '-',
    );

    speech = speech.replaceAll(
      RegExp(r'\bHYPEN\b'),
      '-',
    );

    speech = speech.replaceAll(
      RegExp(r'\bDASH\b'),
      '-',
    );

    speech = speech.replaceAll(
      RegExp(r'\bMINUS\b'),
      '-',
    );

    speech = speech.replaceAll(
      RegExp(r'\bDONE\b'),
      '',
    );

    speech = speech.replaceAll(
      RegExp(r'\bSTOP\b'),
      '',
    );

    speech = speech.replaceAll(
      RegExp(r'\s*-\s*'),
      '-',
    );

    speech = speech.replaceAll(' ', '');

    speech = speech.replaceAll(
      RegExp(r'-{2,}'),
      '-',
    );

    speech = speech.replaceAll(
      RegExp(r'^-|-$'),
      '',
    );

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
    final rationCard =
        rationCardController.text.trim();

    if (rationCard.isEmpty) {
      return;
    }

    final result =
        HiveHelper.getMasterByRationCard(rationCard);

    if (result == null) {
      return;
    }

    final customer = result.value;

    setState(() {
      nameController.text = customer.name;
      mobileController.text = customer.mobile;
      aadhaarController.text = customer.aadhaar;

      if (unitOptions.contains(customer.units)) {
        selectedUnits = customer.units;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Customer details loaded from Master Customer List",
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ==========================================================
  // VOICE ASSISTANT
  // ==========================================================

  Future<void> startVoiceAssistant() async {
    await SpeechService.toggleListening(
      "fullForm",
      (speechText) {
        final data = VoiceParser.parse(speechText);

        setState(() {
          if (data["name"]!.isNotEmpty) {
            nameController.text = data["name"]!;
          }

          if (data["mobile"]!.isNotEmpty) {
            mobileController.text =
                convertSpeechNumbers(data["mobile"]!);
          }

          if (data["ration"]!.isNotEmpty) {
            rationCardController.text =
                convertRationCard(data["ration"]!);

            lookupMasterCustomer();
          }

          if (data["aadhaar"]!.isNotEmpty) {
            aadhaarController.text =
                convertSpeechNumbers(data["aadhaar"]!);
          }

          if (data["units"]!.isNotEmpty &&
              unitOptions.contains(data["units"])) {
            selectedUnits = data["units"]!;
          }
        });
      },
    );
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
    final wasUpdated =
        await HiveHelper.saveMasterCustomer(customer);

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
    });
  }

  // ==========================================================
  // INPUT DECORATION
  // ==========================================================

  InputDecoration inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
        title: const Text(
          "Rice Shop Customer Entry",
        ),
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
                    valueListenable:
                        SpeechService.activeField,

                    builder: (_, activeField, __) {
                      if (activeField == null) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        width: double.infinity,

                        margin:
                            const EdgeInsets.only(bottom: 15),

                        padding:
                            const EdgeInsets.all(12),

                        decoration: BoxDecoration(
                          color: Colors.red.shade50,

                          borderRadius:
                              BorderRadius.circular(10),

                          border:
                              Border.all(color: Colors.red),
                        ),

                        child: const Row(
                          children: [
                            Icon(
                              Icons.mic,
                              color: Colors.red,
                            ),

                            SizedBox(width: 10),

                            Text(
                              "Listening...",
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
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
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // RATION CARD
                  // =================================================

                  TextFormField(
                    controller:
                        rationCardController,

                    decoration: InputDecoration(
                      labelText:
                          "Ration Card Number",

                      border:
                          const OutlineInputBorder(),

                      prefixIcon:
                          const Icon(
                        Icons.credit_card,
                      ),

                      suffixIcon:
                          VoiceIconButton(
                        fieldName: "ration",

                        beforeListening: () {
                          rationCardController.clear();
                        },

                        onResult: (text) {
                          rationCardController.text =
                              convertRationCard(text);

                          lookupMasterCustomer();
                        },
                      ),
                    ),

                    onFieldSubmitted: (_) {
                      lookupMasterCustomer();
                    },

                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return "Enter Ration Card Number";
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 25),

                  // =================================================
                  // CUSTOMER NAME
                  // =================================================

                  TextFormField(
                    controller: nameController,

                    decoration: inputDecoration(
                      "Customer Name",
                      Icons.person,
                    ),

                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
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

                    keyboardType:
                        TextInputType.phone,

                    maxLength: 10,

                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly,
                    ],

                    decoration: InputDecoration(
                      labelText:
                          "Mobile Number",

                      border:
                          const OutlineInputBorder(),

                      prefixIcon:
                          const Icon(Icons.phone),

                      suffixIcon:
                          VoiceIconButton(
                        fieldName: "mobile",

                        beforeListening: () {
                          mobileController.clear();
                        },

                        onResult: (text) {
                          mobileController.text =
                              convertSpeechNumbers(
                            text,
                          );
                        },
                      ),
                    ),

                    validator: (value) {
                      if (value == null ||
                          !RegExp(
                            r'^\d{10}$',
                          ).hasMatch(
                            value.trim(),
                          )) {
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
                    value: unitOptions.contains(
                      selectedUnits,
                    )
                        ? selectedUnits
                        : null,

                    decoration:
                        const InputDecoration(
                      labelText: "Units",
                      border:
                          OutlineInputBorder(),
                      prefixIcon:
                          Icon(Icons.people),
                    ),

                    items:
                        unitOptions.map((unit) {
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
                      if (value == null ||
                          value.isEmpty) {
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
                    controller:
                        aadhaarController,

                    keyboardType:
                        TextInputType.number,

                    maxLength: 12,

                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly,

                      LengthLimitingTextInputFormatter(
                        12,
                      ),
                    ],

                    decoration: InputDecoration(
                      labelText:
                          "Aadhaar Number",

                      border:
                          const OutlineInputBorder(),

                      prefixIcon:
                          const Icon(Icons.badge),

                      suffixIcon:
                          VoiceIconButton(
                        fieldName: "aadhaar",

                        beforeListening: () {
                          aadhaarController.clear();
                        },

                        onResult: (text) {
                          aadhaarController.text =
                              convertSpeechNumbers(
                            text,
                          );
                        },
                      ),
                    ),
                  ),

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
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),

                  const SizedBox(height: 30),

                  // =================================================
                  // SAVE CUSTOMER
                  // =================================================

                  SizedBox(
                    width: double.infinity,
                    height: 55,

                    child: ElevatedButton.icon(
                      onPressed: saveCustomer,

                      icon: const Icon(
                        Icons.save,
                      ),

                      label: const Text(
                        "SAVE CUSTOMER",
                        style: TextStyle(
                          fontSize: 18,
                        ),
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
                            12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // =================================================
                  // VIEW RECORDS
                  // =================================================

                  SizedBox(
                    width: double.infinity,
                    height: 55,

                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.list,
                      ),

                      label: const Text(
                        "VIEW RECORDS",
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) =>
                                const RecordsScreen(),
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
                      icon: const Icon(
                        Icons.people_alt,
                      ),

                      label: const Text(
                        "MASTER CUSTOMER LIST",
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (_) =>
                                const MasterCustomerScreen(),
                          ),
                        );
                      },
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