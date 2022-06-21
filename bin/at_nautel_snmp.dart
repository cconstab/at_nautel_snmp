import 'dart:io';
import 'dart:convert';

// external packages
import 'package:args/args.dart';
import 'package:dart_snmp/dart_snmp.dart';
import 'package:logging/src/level.dart';

// @platform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';

import 'package:at_nautel_snmp/models/transmitter_model.dart';
import 'package:at_nautel_snmp/snmp_get_nautel.dart';
import 'package:at_nautel_snmp/home_directory.dart';
import 'package:at_nautel_snmp/check_file_exists.dart';

void main(List<String> args) async {
  String ip;
  String name;
  String nameSpace = 'kryz_9850';
  String publicKey;
  String frequency;
  Transmitter nautel;
  InternetAddress target;
  final AtSignLogger _logger = AtSignLogger(' nautel ');
  _logger.hierarchicalLoggingEnabled = true;
  _logger.logger.level = Level.WARNING;

  var parser = ArgParser();
// Args
  parser.addOption('key-file',
      abbr: 'k', mandatory: false, help: 'transmitters @sign\'s atKeys file if not in ~/.atsign/keys/');
  parser.addOption('transmitter-atsign', abbr: 't', mandatory: true, help: 'Transmitters @sign');
  parser.addOption('receiver-atsign', abbr: 'r', mandatory: true, help: 'Send a notification to this @sign');
  parser.addOption('public-location', abbr: 'p', mandatory: true, help: 'public FQ @address to publish results');
  parser.addOption('name', abbr: 'n', mandatory: true, help: 'Radio Transmitter name');
  parser.addOption('ip-address', abbr: 'i', mandatory: true, help: 'IP address of transmitter');
  parser.addOption('frequency', abbr: 'f', mandatory: true, help: 'Frequency of transmitter');
  parser.addFlag('verbose', abbr: 'v', help: 'More logging');

  // Check the arguments
  dynamic results;
  String atsignFile;

  String fromAtsign = 'unknown';
  String toAtsign = 'unknown';
  String? homeDirectory = getHomeDirectory();

  try {
    // Arg check
    results = parser.parse(args);
    // Find @sign key file
    name = results['name'];
    fromAtsign = results['transmitter-atsign'];
    toAtsign = results['receiver-atsign'];
    ip = results['ip-address'];
    frequency = results['frequency'];
    publicKey = results['public-location'];
    nautel = Transmitter(stationName: name, frequency: frequency, ip: ip);
    target = InternetAddress(ip);

    if (results['key-file'] != null) {
      atsignFile = results['key-file'];
    } else {
      atsignFile = '${fromAtsign}_key.atKeys';
      atsignFile = '$homeDirectory/.atsign/keys/$atsignFile';
    }
    // Check atKeyFile selected exists
    if (!await fileExists(atsignFile)) {
      throw ('\n Unable to find .atKeys file : $atsignFile');
    }
  } catch (e) {
    print(parser.usage);
    print(e);
    exit(1);
  }

// Now on to the @platform startup
  AtSignLogger.root_level = 'WARNING';
  if (results['verbose']) {
    _logger.logger.level = Level.INFO;

    AtSignLogger.root_level = 'INFO';
  }

  //onboarding preference builder can be used to set onboardingService parameters
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    //..qrCodePath = 'etc/qrcode_blueamateurbinding.png'
    ..hiveStoragePath = '$homeDirectory/.$nameSpace/$fromAtsign/storage'
    ..namespace = nameSpace
    ..downloadPath = '$homeDirectory/.$nameSpace/files'
    ..isLocalStoreRequired = true
    ..commitLogPath = '$homeDirectory/.$nameSpace/$fromAtsign/storage/commitLog'
    //..cramSecret = '<your cram secret>';
    ..atKeysFilePath = atsignFile;

  AtOnboardingService onboardingService = AtOnboardingServiceImpl(fromAtsign, atOnboardingConfig);

  await onboardingService.authenticate();

  var atClient = await onboardingService.getAtClient();

  print(atClient!.getPreferences()?.namespace);

  AtClientManager atClientManager = AtClientManager.getInstance();

  NotificationService notificationService = atClientManager.notificationService;

  bool syncComplete = false;
  void onSyncDone(syncResult) {
    _logger.info("syncResult.syncStatus: ${syncResult.syncStatus}");
    _logger.info("syncResult.lastSyncedOn ${syncResult.lastSyncedOn}");
    syncComplete = true;
  }

  // Wait for initial sync to complete
  _logger.info("Waiting for initial sync");
  syncComplete = false;
  atClientManager.syncService.sync(onDone: onSyncDone);
  while (!syncComplete) {
    await Future.delayed(Duration(milliseconds: 100));
  }

  while (true) {
    try {
      var session = await Snmp.createSession(target);
      await mainloop(nautel, session, atClient, fromAtsign, toAtsign, publicKey);
    } catch (e) {
      print(e);
    }
    print("error staring retry in 5 Seconds");
    await Future.delayed(Duration(seconds: 5));
  }
}

Future<void> mainloop(nautel, session, atClient, fromAtsign, toAtsign, publicKey) async {
  while (true) {
    nautel = await getOID(session, nautel);
    var t = nautel.toJson();
    var ts = (json.encode(t));
    await updateAtsign(ts, atClient, fromAtsign, toAtsign, publicKey);
    await Future.delayed(Duration(seconds: 1));
  }
}

Future<void> updateAtsign(json, atClient, fromAtsign, toAtsign, publicKey) async {
  var metaData = Metadata()
    ..isPublic = true
    ..isEncrypted = false
    ..namespaceAware = true
    ..isHidden = true
    ..ttr = -1
    ..ttl = 10000;

  var atKey = AtKey()
    ..key = publicKey
    ..namespace = atClient!.getPreferences()?.namespace
    ..sharedBy = fromAtsign
    ..metadata = metaData;

  atClient.getPreferences();

  print(atKey.toString());
  print(atClient!.getPreferences()?.namespace);

  await atClient.put(atKey, json);
  var b = await atClient.get(atKey);
  print(b.toString());
}
