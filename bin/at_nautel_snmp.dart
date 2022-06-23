import 'dart:io';
import 'dart:convert';

// external packages
import 'package:args/args.dart';
import 'package:dart_snmp/dart_snmp.dart';
import 'package:logging/src/level.dart';

// @platform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_nautel_snmp/models/transmitter_model.dart';
import 'package:at_nautel_snmp/snmp_get_nautel.dart';
import 'package:at_nautel_snmp/home_directory.dart';
import 'package:at_nautel_snmp/check_file_exists.dart';

void main(List<String> args) async {
  String ip;
  InternetAddress sourceIp;
  String name;
  String nameSpace = 'kryz_9850';
  String deviceName;
  String frequency;
  Transmitter nautel;
  Snmp session;
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
  // parser.addOption('device-name', abbr: 'n', mandatory: true, help: 'Device name, used as AtKey:key');
  parser.addOption('name', abbr: 'n', mandatory: true, help: 'Radio Transmitter name');
  parser.addOption('ip-address', abbr: 'i', mandatory: true, help: 'IP address of transmitter');
  parser.addOption('source-ip-address',
      abbr: 's', mandatory: false, defaultsTo: '0.0.0.0', help: 'Source IP address of SNMP');
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
    sourceIp = InternetAddress(results['source-ip-address']);
    frequency = results['frequency'];
    deviceName = results['name'];
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

  AtClient? atClient = await onboardingService.getAtClient();

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
      session = await Snmp.createSession(target, sourceAddress: sourceIp);
      await mainloop(_logger, nautel, session, atClient!, notificationService, fromAtsign, toAtsign, deviceName);
      session.close();
    } catch (e) {
      _logger.severe(e);
    }
    _logger.severe(" SNMP error  retry in 5 Seconds");
    await Future.delayed(Duration(seconds: 5));
  }
}

Future<void> mainloop(AtSignLogger _logger, Transmitter nautel, Snmp session, AtClient atClient,
    NotificationService notificationService, String fromAtsign, String toAtsign, String deviceName) async {
  while (true) {
    nautel = await getOID(session, nautel);
    var t = nautel.toJson();
    var ts = (json.encode(t));
    await updatePublicAtsign(_logger, ts, atClient, fromAtsign, toAtsign, deviceName);
    await updatePrivateAtsign(_logger, ts, atClient, notificationService, fromAtsign, toAtsign, deviceName);
    await Future.delayed(Duration(seconds: 1));
  }
}

Future<void> updatePublicAtsign(
    AtSignLogger _logger, String json, AtClient atClient, String fromAtsign, String toAtsign, String deviceName) async {
  var metaData = Metadata()
    ..isPublic = true
    ..isEncrypted = false
    ..namespaceAware = true
    // Is hidden not working in SDK as yet
    // Will hide this public AtKey once available
    //..isHidden = true
    ..ttr = -1
    // Keep the key in place for 20 seconds
    ..ttl = 20000;

  var atKey = AtKey()
    ..key = deviceName
    ..namespace = atClient.getPreferences()?.namespace
    ..sharedBy = fromAtsign
    ..metadata = metaData;

  // atClient.getPreferences();

  _logger.info(atKey.toString());

  await atClient.put(atKey, json);
  var b = await atClient.get(atKey);
  _logger.info(b.toString());
}

Future<void> updatePrivateAtsign(AtSignLogger _logger, String json, AtClient atClient,
    NotificationService notificationService, String fromAtsign, String toAtsign, String deviceName) async {
  var metaData = Metadata()
    ..isPublic = false
    ..isEncrypted = true
    ..namespaceAware = true
    ..ttr = -1
    ..ttl = 1000;

  var key = AtKey()
    ..key = deviceName
    ..sharedBy = fromAtsign
    ..sharedWith = toAtsign
    ..namespace = atClient.getPreferences()?.namespace
    ..metadata = metaData;

  try {
    await notificationService.notify(NotificationParams.forUpdate(key, value: json), onSuccess: (notification) {
      _logger.info('SUCCESS:' + notification.toString());
    }, onError: (notification) {
      _logger.info('ERROR:' + notification.toString());
    });
  } catch (e) {
    _logger.severe(e.toString());
  }
}
