import 'dart:io';
import 'dart:convert';
import 'dart:async';

// external packages
import 'package:args/args.dart';
import 'package:dart_snmp/dart_snmp.dart';
import 'package:logging/src/level.dart';
import 'package:chalkdart/chalk.dart';

// @platform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_nautel_snmp/models/transmitter_model.dart';
import 'package:at_nautel_snmp/snmp_get_nautel.dart';
import 'package:at_nautel_snmp/home_directory.dart';
import 'package:at_nautel_snmp/check_file_exists.dart';

void main(List<String> args) async {
  //starting secondary in a zone
  var logger = AtSignLogger('atNautel sender ');
  runZonedGuarded(() async {
    await snmp(args);
  }, (error, stackTrace) {
    logger.severe('Uncaught error: $error');
    logger.severe(stackTrace.toString());
  });
}

Future<void> snmp(List<String> args) async {
  String ip;
  InternetAddress sourceIp;
  String name;
  String nameSpace = 'kryz_9850';
  String deviceName;
  String frequency;
  String pollDelay;
  Transmitter nautel;
  InternetAddress target;
  final AtSignLogger _logger = AtSignLogger(' nautel ');
  _logger.hierarchicalLoggingEnabled = true;
  _logger.logger.level = Level.WARNING;

  var parser = ArgParser();
// Args
  parser.addOption('key-file',
      abbr: 'k',
      mandatory: false,
      help: 'transmitters @sign\'s atKeys file if not in ~/.atsign/keys/');
  parser.addOption('transmitter-atsign',
      abbr: 't', mandatory: true, help: 'Transmitters @sign');
  parser.addOption('receiver-atsign',
      abbr: 'r', mandatory: true, help: 'Send a notification to this @sign');
  // parser.addOption('device-name', abbr: 'n', mandatory: true, help: 'Device name, used as AtKey:key');
  parser.addOption('name',
      abbr: 'n', mandatory: true, help: 'Radio Transmitter name');
  parser.addOption('ip-address',
      abbr: 'i', mandatory: true, help: 'IP address of transmitter');
  parser.addOption('source-ip-address',
      abbr: 's',
      mandatory: false,
      defaultsTo: '0.0.0.0',
      help: 'Source IP address of SNMP');
  parser.addOption('frequency',
      abbr: 'f', mandatory: true, help: 'Frequency of transmitter');
  parser.addOption('pollDelay',
      abbr: 'd',
      defaultsTo: '1000',
      help: 'Delay between SNMP polls in milliseconds');
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
    pollDelay = results['pollDelay'];
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
    ..atKeysFilePath = atsignFile
    ..fetchOfflineNotifications = false
    ..useAtChops = true;

  AtOnboardingService onboardingService =
      AtOnboardingServiceImpl(fromAtsign, atOnboardingConfig);

  bool onboarded = false;
  Duration retryDuration = Duration(seconds: 3);
  while (!onboarded) {
    try {
      stdout.write(chalk.brightBlue('\r\x1b[KConnecting ... '));
      await Future.delayed(Duration(
          milliseconds:
              1000)); // Pause just long enough for the retry to be visible
      onboarded = await onboardingService.authenticate();
    } catch (exception) {
      stdout.write(chalk.brightRed(
          '$exception. Will retry in ${retryDuration.inSeconds} seconds'));
    }
    if (!onboarded) {
      await Future.delayed(retryDuration);
    }
  }
  stdout.writeln(chalk.brightGreen('Connected'));

  // Current atClient is the one which the onboardingService just authenticated
  AtClient atClient = AtClientManager.getInstance().atClient;
  late Snmp session;
  bool sessionBool = false;
  while (true) {
    try {
      session = await Snmp.createSession(target, sourceAddress: sourceIp);
      sessionBool = true;
      session.retries = 5;

      await mainloop(_logger, nautel, session, atClient,
          atClient.notificationService, fromAtsign, toAtsign, deviceName,pollDelay);
    } catch (e) {
      _logger.severe(e);
    }
    if (sessionBool) {
      session.close();
    }
    _logger.severe(" SNMP error  retry in 5 Seconds");
    await Future.delayed(Duration(seconds: 5));
    sessionBool = false;
  }
}

Future<void> mainloop(
    AtSignLogger _logger,
    Transmitter nautel,
    Snmp session,
    AtClient atClient,
    NotificationService notificationService,
    String fromAtsign,
    String toAtsign,
    String deviceName,
    String pollDelay) async {
  int counter = 0;
  while (true) {
    nautel = await getOID(session, nautel, _logger);
    var t = nautel.toJson();
    var ts = (json.encode(t));

    updatePrivateAtsign(_logger, ts, atClient, notificationService, fromAtsign,
        toAtsign, deviceName);
    await Future.delayed(Duration(milliseconds: int.parse(pollDelay)));
  }
}



void updatePrivateAtsign(
    AtSignLogger _logger,
    String json,
    AtClient atClient,
    NotificationService notificationService,
    String fromAtsign,
    String toAtsign,
    String deviceName) async {
  try {
    notificationService
        .notify(NotificationParams.forText(json, toAtsign, shouldEncrypt: true),
            onSuccess: (notification) {
      _logger.info('SUCCESS:' + notification.toString());
    }, onError: (notification) {
      _logger.info('ERROR:' + notification.toString());
    });
  } catch (e) {
    _logger.severe(e.toString());
  }
}
