import 'dart:async';
import 'dart:io';

import 'package:chalkdart/chalk.dart';

// @platform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';

// Local Packages
import 'package:at_nautel_snmp/home_directory.dart';

var streamController = StreamController<String>.broadcast();

void main() async {
  Stream<String> trans;
  streamController.stream.asBroadcastStream();
  trans = transmitterStream().asBroadcastStream();
  trans.listen((event) {
    print(event);
  });
  HttpServer server = await HttpServer.bind('0.0.0.0', 9850);
  server.transform(WebSocketTransformer()).listen(onWebSocketData);
}

void onWebSocketData(WebSocket client) async {
  client.listen((data) {
    print('Message received: $data ');
    client.add('Echo: $data');
  });
  streamController.stream.listen((data) {
    client.add(data);
  });
}

Stream<String> transmitterStream() async* {
  String nameSpace = 'kryz_9850';
  String deviceName = 'KRYZ';
  String json = '';
  String? homeDirectory = getHomeDirectory();
  String atSign = '@visual61';
  String rootDomain = 'root.atsign.org';
  String atsignFile = '${atSign}_key.atKeys';
  atsignFile = '$homeDirectory/.atsign/keys/$atsignFile';

// Accessing the stream and listening for data event

  // Now on to the @platform startup
  final AtSignLogger _logger = AtSignLogger(' nautel ');
  _logger.hierarchicalLoggingEnabled = true;
  AtSignLogger.root_level = 'WARNING';

  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath = '$homeDirectory/.$nameSpace/$atSign/storage'
    ..namespace = nameSpace
    ..downloadPath = '$homeDirectory/.$nameSpace/files'
    ..isLocalStoreRequired = true
    ..commitLogPath = '$homeDirectory/.$nameSpace/$atSign/storage/commitLog'
    ..rootDomain = rootDomain
    ..fetchOfflineNotifications = false
    ..atKeysFilePath = atsignFile
    ..useAtChops = true;

  AtOnboardingService onboardingService = AtOnboardingServiceImpl(atSign, atOnboardingConfig);
  bool onboarded = false;
  Duration retryDuration = Duration(seconds: 3);
  while (!onboarded) {
    try {
      stdout.write(chalk.brightBlue('\r\x1b[KConnecting ... '));
      await Future.delayed(Duration(milliseconds: 1000)); // Pause just long enough for the retry to be visible
      onboarded = await onboardingService.authenticate();
    } catch (exception) {
      stdout.write(chalk.brightRed('$exception. Will retry in ${retryDuration.inSeconds} seconds'));
    }
    if (!onboarded) {
      await Future.delayed(retryDuration);
    }
  }
  stdout.writeln(chalk.brightGreen('Connected'));

  AtClientManager atClientManager = AtClientManager.getInstance();

  NotificationService notificationService = atClientManager.atClient.notificationService;

  notificationService.subscribe(regex: '$deviceName.$nameSpace@', shouldDecrypt: true).listen(((notification) async {
    String keyAtsign = notification.key;
    //Uint8List buffer;
    keyAtsign = keyAtsign.replaceAll('${notification.to}:', '');
    keyAtsign = keyAtsign.replaceAll('.$nameSpace${notification.from}', '');
    if (keyAtsign == deviceName) {
      _logger.info('SNMP update recieved from ${notification.from} notification id : ${notification.id}');
      json = notification.value!;
      print(json);
      streamController.sink.add(json);
    }
  }),
      onError: (e) => _logger.severe('Notification Failed:$e'),
      onDone: () => _logger.info('Notification listener stopped'));
}
