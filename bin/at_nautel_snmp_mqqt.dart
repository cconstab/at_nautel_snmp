import 'dart:io';

import 'dart:async';

// external packages
import 'package:args/args.dart';
import 'package:logging/src/level.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// @platform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';

import 'package:at_nautel_snmp/home_directory.dart';
import 'package:at_nautel_snmp/check_file_exists.dart';

var pongCount = 0; // Pong counter
var mqttSession = MqttServerClient('test.mosquitto.org', '');

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
  String mqttIP;
  String mqttTopic;
  String mqttUsername;
  String nameSpace = 'kryz_9850';
  String deviceName;

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
  parser.addOption('receiver-atsign',
      abbr: 'r', mandatory: true, help: '@sign that recieves notifications');
  parser.addOption('device-name',
      abbr: 'n', mandatory: true, help: 'Device name, used as AtKey:key');
  parser.addOption('mqtt-host',
      abbr: 'm', mandatory: true, help: 'MQQT server hostname');
  parser.addOption('mqtt-username',
      abbr: 'u', mandatory: true, help: 'MQQT server username');
  parser.addOption('mqtt-topic',
      abbr: 't', mandatory: true, help: 'MQTT subjectname');
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
    mqttIP = results['mqtt-host'];
    mqttUsername = results['mqtt-username'];
    mqttTopic = results['mqtt-topic'];
    deviceName = results['device-name'];

    var targetlist = await InternetAddress.lookup(mqttIP);
    target = targetlist[0];

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
    ..hiveStoragePath = '$homeDirectory/.${nameSpace}mqtt/$fromAtsign/storage'
    ..namespace = nameSpace
    ..downloadPath = '$homeDirectory/.${nameSpace}mqtt/files'
    ..isLocalStoreRequired = true
    ..commitLogPath = '$homeDirectory/.${nameSpace}mqtt/$fromAtsign/storage/commitLog'
    ..fetchOfflineNotifications = false
    //..cramSecret = '<your cram secret>';
    ..atKeysFilePath = atsignFile;

  AtOnboardingService onboardingService =
      AtOnboardingServiceImpl(fromAtsign, atOnboardingConfig);

  await onboardingService.authenticate();

  // var atClient = await onboardingService.getAtClient();

  AtClientManager atClientManager = AtClientManager.getInstance();

  NotificationService notificationService =
      atClientManager.atClient.notificationService;

// Keep an eye on connectivity and report failures if we see them
  ConnectivityListener().subscribe().listen((isConnected) {
    if (isConnected) {
      _logger.warning('connection available');
    } else {
      _logger.warning('connection lost');
    }
  });

// Set up MQTT
  mqttSession = MqttServerClient(mqttIP, deviceName, maxConnectionAttempts: 10);
  final builder = MqttClientPayloadBuilder();

  mqttSession.setProtocolV311();
  mqttSession.keepAlivePeriod = 20;
  mqttSession.autoReconnect = true;
  // Pong Callback
  void pong() {
    _logger.info('Mosquitto Ping response client callback invoked');
    pongCount++;
  }

  mqttSession.pongCallback = pong;

  // await mqttSession.connect(mqttUsername, 'KRYZ');
  // print(mqttSession.connectionStatus);

  /// Create a connection message to use or use the default one. The default one sets the
  /// client identifier, any supplied username/password and clean session,
  /// an example of a specific one below.
  final connMess = MqttConnectMessage()
      .withClientIdentifier('Mqtt_MyClientUniqueId')
      // .withWillTopic('willtopic') // If you set this you must set a will message
      // .withWillMessage('My Will message')
      .startClean() // Non persistent session for testing
      .authenticateAs(mqttUsername, '')
      .withWillQos(MqttQos.atLeastOnce);
  _logger.info('Mosquitto client connecting....');
  mqttSession.connectionMessage = connMess;

  /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
  /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
  /// never send malformed messages.
  try {
    await mqttSession.connect();
  } on NoConnectionException catch (e) {
    // Raised by the client when connection fails.
    _logger.severe(' Mosquitto client exception - $e');
    mqttSession.disconnect();
  } on SocketException catch (e) {
    // Raised by the socket layer
    _logger.severe(' Mosquitto socket exception - $e');
    mqttSession.disconnect();
  }

  /// Check we are connected
  if (mqttSession.connectionStatus!.state == MqttConnectionState.connected) {
    _logger.info(' Mosquitto client connected');
  } else {
    /// Use status here rather than state if you also want the broker return code.
    _logger.severe(
        ' Mosquitto client connection failed - disconnecting, status is ${mqttSession.connectionStatus}');
    mqttSession.disconnect();
    exit(-1);
  }

  // notificationService.subscribe(regex: '$deviceName.$nameSpace@', shouldDecrypt: true).listen(((notification) async {
  //   String keyAtsign = notification.key;
  //   //Uint8List buffer;
  //   keyAtsign = keyAtsign.replaceAll(notification.to + ':', '');
  //   keyAtsign = keyAtsign.replaceAll('.' + nameSpace + notification.from, '');
  //   if (keyAtsign == deviceName) {
  //     _logger.info('SNMP update recieved from ' + notification.from + ' notification id : ' + notification.id);
  //     var json = notification.value!;
  //     print(json);
  String? atSign = AtClientManager.getInstance().atClient.getCurrentAtSign();
  notificationService
      .subscribe(
          regex: '$atSign:{"stationName":"$deviceName"', shouldDecrypt: true)
      .listen(((notification) async {
    print(notification.toString());
    String? json = notification.key;
    json = json.replaceFirst('$atSign:', '');
    if (notification.from == '@$nameSpace') {
      _logger.info(
          'SNMP update recieved from ${notification.from} notification id : ${notification.id}');
      print(json);

      await mqttSession.connect();

      if (mqttSession.connectionStatus!.state ==
          MqttConnectionState.connected) {
        _logger.info('Mosquitto client connected sending message');
        mqttSession.publishMessage(
            mqttTopic, MqttQos.atMostOnce, builder.addString(json).payload!,
            retain: false);
        builder.clear();
      } else {
        await mqttSession.connect();
      }
    }
  }),
          onError: (e) => _logger.severe('Notification Failed:' + e.toString()),
          onDone: () => _logger.info('Notification listener stopped'));
}
