class VoiceParser {

  static Map<String,String> parse(String speech){

    speech = speech.toLowerCase();

    Map<String,String> data = {

      "name":"",
      "mobile":"",
      "ration":"",
      "aadhaar":"",
      "units":""

    };

    RegExp nameRegex =
        RegExp(r'name\s(.+?)\smobile');

    RegExp mobileRegex =
        RegExp(r'mobile\s([0-9]+)');

    RegExp rationRegex =
        RegExp(r'ration\s?card\s([a-zA-Z0-9]+)');

    RegExp aadhaarRegex =
        RegExp(r'aadhaar\s([0-9]+)');

    RegExp unitRegex =
        RegExp(r'units\s([a-zA-Z0-9]+)');

    if(nameRegex.hasMatch(speech)){

      data["name"] =
          nameRegex.firstMatch(speech)!.group(1)!;

    }

    if(mobileRegex.hasMatch(speech)){

      data["mobile"] =
          mobileRegex.firstMatch(speech)!.group(1)!;

    }

    if(rationRegex.hasMatch(speech)){

      data["ration"] =
          rationRegex.firstMatch(speech)!.group(1)!;

    }

    if(aadhaarRegex.hasMatch(speech)){

      data["aadhaar"] =
          aadhaarRegex.firstMatch(speech)!.group(1)!;

    }

    if(unitRegex.hasMatch(speech)){

      data["units"] =
          unitRegex.firstMatch(speech)!.group(1)!;

    }

    return data;

  }

}