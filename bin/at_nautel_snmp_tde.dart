import 'dart:io';
import 'dart:isolate';

import 'dart:async';

// external packages
import 'package:args/args.dart';
import 'package:logging/src/level.dart';

// @platform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';

import 'package:at_nautel_snmp/home_directory.dart';
import 'package:at_nautel_snmp/check_file_exists.dart';

void main(List<String> args) async {
  //starting secondary in a zone
  var logger = AtSignLogger('atNautel reciever ');
  runZonedGuarded(() async {
    await snmpMqtt(args);
  }, (error, stackTrace) {
    logger.severe('Uncaught error: $error');
    logger.severe(stackTrace.toString());
  });
}

Future<void> snmpMqtt(List<String> args) async {
  //InternetAddress sourceIp;

  String nameSpace = 'kryz_9850';
  String deviceName;
  String cloudToken;
  String cloudUrl;

  final AtSignLogger logger = AtSignLogger(' nautel ');
  logger.hierarchicalLoggingEnabled = true;
  logger.logger.level = Level.WARNING;

  var parser = ArgParser();
// Args
  parser.addOption('key-file',
      abbr: 'k',
      mandatory: false,
      help: 'transmitters @sign\'s atKeys file if not in ~/.atsign/keys/');
  parser.addOption('receiver-atsign',
      abbr: 'r', mandatory: true, help: '@sign that recieves notifications');
  parser.addOption('device-name',
      abbr: 'n', mandatory: true, help: 'Device name, used as AtKey:key');
  parser.addOption('cloud-token',
      abbr: 't', mandatory: true, help: 'Cloud token for TD Engine');
  parser.addOption('cloud-url',
      abbr: 'u', mandatory: true, help: 'Cloud URL for TD Engine');
  parser.addFlag('verbose', abbr: 'v', help: 'More logging');

  // Check the arguments
  dynamic results;
  String atsignFile;

  String fromAtsign = 'unknown';
  String? homeDirectory = getHomeDirectory();
  try {
    // Arg check
    results = parser.parse(args);
    // Find @sign key file
    fromAtsign = results['receiver-atsign'];

    deviceName = results['device-name'];
    cloudToken = results['cloud-token'];
    cloudUrl = results['cloud-url'];
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
    stderr.writeln(e);
    stderr.writeln(parser.usage);
    exit(1);
  }

// Now on to the @platform startup
  AtSignLogger.root_level = 'WARNING';
  if (results['verbose']) {
    logger.logger.level = Level.INFO;

    AtSignLogger.root_level = 'INFO';
  }

// Keep an eye on connectivity and report failures if we see them
  ConnectivityListener().subscribe().listen((isConnected) {
    if (isConnected) {
      logger.warning('Internet connection available');
    } else {
      logger.warning('Internet connection lost');
    }
  });

  //onboarding preference builder can be used to set onboardingService parameters
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath = '$homeDirectory/.${nameSpace}mqtt/$fromAtsign/storage'
    ..namespace = nameSpace
    ..downloadPath = '$homeDirectory/.${nameSpace}mqtt/files'
    ..isLocalStoreRequired = true
    ..commitLogPath =
        '$homeDirectory/.${nameSpace}mqtt/$fromAtsign/storage/commitLog'
    ..fetchOfflineNotifications = false
    ..atKeysFilePath = atsignFile;

  AtOnboardingService onboardingService =
      AtOnboardingServiceImpl(fromAtsign, atOnboardingConfig);

  await onboardingService.authenticate();

  // var atClient = await onboardingService.getAtClient();

  AtClientManager atClientManager = AtClientManager.getInstance();
  NotificationService notificationService =
      atClientManager.atClient.notificationService;
  String? atSign = AtClientManager.getInstance().atClient.getCurrentAtSign();
  notificationService
      .subscribe(
          regex: '$atSign:{"stationName":"$deviceName"', shouldDecrypt: true)
      .listen(((notification) async {
    String? json = notification.key;

    if (notification.from == '@$nameSpace') {
      logger.info(
          'SNMP update recieved from ${notification.from} notification id : ${notification.id}');
      try {
        print(json);
      } catch (e) {
        logger.info('Error printing message: $e');
      }
    }
  }),
          onError: (e) => logger.severe('Notification Failed:$e'),
          onDone: () => logger.info('Notification listener stopped'));
}

Future<void> mqttSetup(SendPort mySendPort) async {
  ReceivePort myReceivePort = ReceivePort();
  ReceivePort pubReceivePort = ReceivePort();
  mySendPort.send([myReceivePort.sendPort, pubReceivePort.sendPort]);
  List message = await myReceivePort.first as List;
  bool verbose = message[11] == 'true';

  print(verbose);

  final AtSignLogger logger = AtSignLogger(' mqtt ');
  logger.hierarchicalLoggingEnabled = true;
  logger.logger.level = Level.WARNING;

// Now on to the @platform startup
  AtSignLogger.root_level = 'WARNING';
  if (verbose) {
    logger.logger.level = Level.INFO;
    AtSignLogger.root_level = 'INFO';
  }
}
