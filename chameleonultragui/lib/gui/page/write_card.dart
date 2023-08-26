import 'package:flutter/material.dart';
import 'package:chameleonultragui/gui/page/read_card.dart';
import 'package:chameleonultragui/bridge/chameleon.dart';
import 'package:chameleonultragui/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:chameleonultragui/gui/component/error_message.dart';
import 'package:chameleonultragui/helpers/general.dart';
import 'package:chameleonultragui/helpers/mifare_classic.dart';

class WriteCardPage extends StatefulWidget {
  const WriteCardPage({Key? key}) : super(key: key);

  @override
  WriteCardPageState createState() => WriteCardPageState();
}

class WriteCardPageState extends State<WriteCardPage> {
  ChameleonReadTagStatus status = ChameleonReadTagStatus();

  @override
  void initState() {
    super.initState();
  }

  Future<void> readHFInfo(MyAppState appState) async {
    status.validKeys = List.generate(80, (_) => Uint8List(0));
    status.checkMarks = List.generate(80, (_) => ChameleonKeyCheckmark.none);

    try {
      if (!await appState.communicator!.isReaderDeviceMode()) {
        await appState.communicator!.setReaderDeviceMode(true);
      }

      var card = await appState.communicator!.scan14443aTag();
      var mifare = await appState.communicator!.detectMf1Support();
      var mf1Type = MifareClassicType.none;
      bool isEV1 = false;
      if (mifare) {
        mf1Type = mfClassicGetType(card.atqa, card.sak);
        isEV1 = (await appState.communicator!
            .mf1Auth(0x45, 0x61, gMifareClassicKeys[3]));
      }
      setState(() {
        status.hfUid = bytesToHexSpace(card.uid);
        status.sak = card.sak.toRadixString(16).padLeft(2, '0').toUpperCase();
        status.atqa = bytesToHexSpace(card.atqa);
        status.ats = "Unavailable";
        status.hfTech = mifare
            ? "Mifare Classic ${mfClassicGetName(mf1Type)}${(isEV1) ? " EV1" : ""}"
            : "Other";
        status.isEV1 = isEV1;
        status.recoveryError = "";
        status.checkMarks =
            List.generate(80, (_) => ChameleonKeyCheckmark.none);
        status.type = mf1Type;
        status.state = (mf1Type != MifareClassicType.none)
            ? ChameleonMifareClassicState.checkKeys
            : ChameleonMifareClassicState.none;
        status.allKeysExists = false;
        status.noHfCard = false;
        status.dumpProgress = 0;
      });
    } catch (_) {
      setState(() {
        status.hfUid = "";
        status.sak = "";
        status.atqa = "";
        status.ats = "";
        status.hfTech = "";
        status.recoveryError = "";
        status.type = MifareClassicType.none;
        status.state = ChameleonMifareClassicState.none;
        status.allKeysExists = false;
        status.noHfCard = true;
        status.isEV1 = false;
      });
    }
  }

  Future<void> readLFInfo(MyAppState appState) async {
    try {
      if (!await appState.communicator!.isReaderDeviceMode()) {
        await appState.communicator!.setReaderDeviceMode(true);
      }

      var card = await appState.communicator!.readEM410X();
      if (card == "00 00 00 00 00") {
        setState(() {
          status.lfUid = "";
          status.lfTech = "";
          status.noLfCard = true;
        });
      } else {
        setState(() {
          status.lfUid = card;
          status.lfTech = "EM-Marin EM4100/EM4102";
          status.noLfCard = false;
        });
      }
    } catch (_) {
      setState(() {
        status.lfUid = "";
        status.lfTech = "";
        status.noLfCard = true;
      });
    }
  }

  Widget buildFieldRow(String label, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        '$label: $value',
        textAlign: (MediaQuery.of(context).size.width < 800)
            ? TextAlign.left
            : TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 800;
    double fieldFontSize = isSmallScreen ? 16 : 20;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Card'),
      ),
      body: Column(
        children: [
          Center(
            child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Tag Info',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  buildFieldRow('UID', status.hfUid, fieldFontSize),
                  buildFieldRow('SAK', status.sak, fieldFontSize),
                  buildFieldRow('ATQA', status.atqa, fieldFontSize),
                  // buildFieldRow('ATS', status.ats, fieldFontSize),
                  const SizedBox(height: 16),
                  Text(
                    'Tech: ${status.hfTech}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: fieldFontSize),
                  ),
                  const SizedBox(height: 16),
                  if (status.noHfCard) ...[
                    const ErrorMessage(
                        errorMessage:
                            "No card found. Try to move Chameleon on card"),
                    const SizedBox(height: 16)
                  ],
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
