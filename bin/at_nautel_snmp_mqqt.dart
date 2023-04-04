import 'dart:io';
import 'dart:isolate';

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
late MqttServerClient mqttSession;

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
  String mqttPassword;
  String nameSpace = 'kryz_9850';
  String deviceName;
  String mqttDeviceName;
  String mqttJsonWrapper;
  String mqttPort;
  bool mqttTls;
  String trustedCertsFile;
  String certFile;
  String privateKeyFile;
  bool useCerts;

  InternetAddress target;
  final AtSignLogger _logger = AtSignLogger(' nautel ');
  _logger.hierarchicalLoggingEnabled = true;
  _logger.logger.level = Level.WARNING;

  var parser = ArgParser();
// Args
  parser.addOption('key-file',
      abbr: 'k', mandatory: false, help: 'transmitters @sign\'s atKeys file if not in ~/.atsign/keys/');
  parser.addOption('receiver-atsign', abbr: 'r', mandatory: true, help: '@sign that recieves notifications');
  parser.addOption('device-name', abbr: 'n', mandatory: true, help: 'Device name, used as AtKey:key');
  parser.addOption('mqtt-device-name', abbr: 'd', mandatory: false, help: 'MQTT device name', defaultsTo: '');
  parser.addOption('mqtt-host', abbr: 'm', mandatory: true, help: 'MQQT server hostname');
  parser.addOption('mqtt-username', abbr: 'u', mandatory: false, help: 'MQQT server username', defaultsTo: '');
  parser.addOption('mqtt-password', abbr: 'p', mandatory: false, help: 'MQQT server password', defaultsTo: '');
  parser.addOption('mqtt-topic', abbr: 't', mandatory: false, help: 'MQTT subjectname', defaultsTo: '');
  parser.addOption('mqtt-trusted-certs', mandatory: false, help: 'MQTT TLS trusted CA file', defaultsTo: '');
  parser.addOption('mqtt-cert', mandatory: false, help: 'MQTT TLS certificate file', defaultsTo: '');
  parser.addOption('mqtt-cert-private-key', mandatory: false, help: 'MQTT TLS certificate file', defaultsTo: '');
  parser.addFlag('use-certificates',
      abbr: 's', help: 'Use/specify certficates for TLS connections e.g. AWS IoT', defaultsTo: false);

  parser.addOption('mqtt-port',
      abbr: 'o', mandatory: false, help: 'MQQT server port number default 8883', defaultsTo: '8883');
  parser.addFlag('secure', abbr: 'i', help: 'Use TLS for mqqt connection', defaultsTo: true);

  parser.addOption('mqtt-json-wrapper',
      abbr: 'w',
      mandatory: false,
      help: 'MQTT json wrapper useful to create {"<data>": json} for IoT hubs that need it where option is "data"',
      defaultsTo: '');
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
    mqttPassword = results['mqtt-password'];
    mqttTopic = results['mqtt-topic'];
    deviceName = results['device-name'];
    mqttDeviceName = results['mqtt-device-name'];
    mqttJsonWrapper = results['mqtt-json-wrapper'];
    mqttPort = results['mqtt-port'];
    mqttTls = results['secure'];
    useCerts = results['use-certificates'];
    trustedCertsFile = results['mqtt-trusted-certs'];
    certFile = results['mqtt-cert'];
    privateKeyFile = results['mqtt-cert-private-key'];

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

// Keep an eye on connectivity and report failures if we see them
  ConnectivityListener().subscribe().listen((isConnected) {
    if (isConnected) {
      _logger.warning('connection available');
    } else {
      _logger.warning('connection lost');
    }
  });

  ReceivePort myReceivePort = ReceivePort();
  ReceivePort pubReceivePort = ReceivePort();

  Isolate.spawn<SendPort>(mqttSetup, myReceivePort.sendPort);

  List<SendPort> sendPorts = await myReceivePort.first;

  SendPort mySendPort = sendPorts[0];
  SendPort pubSendPort = sendPorts[1];

  mySendPort.send(
    [
      mqttTls.toString(),
      mqttIP,
      mqttDeviceName,
      mqttPort,
      useCerts.toString(),
      certFile,
      privateKeyFile,
      mqttUsername,
      mqttPassword,
      mqttTopic,
      pubReceivePort.sendPort
    ],
  );

  //onboarding preference builder can be used to set onboardingService parameters
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    //..qrCodePath = 'etc/qrcode_blueamateurbinding.png'
    ..hiveStoragePath = '$homeDirectory/.${nameSpace}mqtt/$fromAtsign/$mqttIP/storage'
    ..namespace = nameSpace
    ..downloadPath = '$homeDirectory/.${nameSpace}mqtt/files'
    ..isLocalStoreRequired = true
    ..commitLogPath = '$homeDirectory/.${nameSpace}mqtt/$fromAtsign/$mqttIP/storage/commitLog'
    ..fetchOfflineNotifications = false
    //..cramSecret = '<your cram secret>';
    ..atKeysFilePath = atsignFile;

  AtOnboardingService onboardingService = AtOnboardingServiceImpl(fromAtsign, atOnboardingConfig);

  await onboardingService.authenticate();

  // var atClient = await onboardingService.getAtClient();

  AtClientManager atClientManager = AtClientManager.getInstance();
  final builder = MqttClientPayloadBuilder();
  NotificationService notificationService = atClientManager.atClient.notificationService;
  String? atSign = AtClientManager.getInstance().atClient.getCurrentAtSign();
  notificationService.subscribe(regex: '$atSign:{"stationName":"$deviceName"', shouldDecrypt: true).listen(
      ((notification) async {
    print(notification.toString());
    String? json = notification.key;
    if (mqttJsonWrapper == '') {
      json = json.replaceFirst('$atSign:', '');
    } else {
      json = json.replaceFirst('$atSign:', '{"$mqttJsonWrapper":');
      json = '$json}';
    }
    print(json);
    if (notification.from == '@$nameSpace') {
      _logger.info('SNMP update recieved from ${notification.from} notification id : ${notification.id}');
      _logger.info('Mosquitto client connected sending message: $json');
      try {
        //await mqttSession.connect();
        //mqttSession.publishMessage(mqttTopic, MqttQos.atMostOnce, builder.addString(json).payload!, retain: false);
        pubSendPort.send(json);
        builder.clear();
        print(json);
      } catch (e) {
        _logger.info('Error sending mqtt message: $e');
      }
    }
  }),
      onError: (e) => _logger.severe('Notification Failed:$e'),
      onDone: () => _logger.info('Notification listener stopped'));
}

Future<void> mqttSetup(SendPort mySendPort) async {
  ReceivePort myReceivePort = ReceivePort();
  ReceivePort pubReceivePort = ReceivePort();
  mySendPort.send([myReceivePort.sendPort, pubReceivePort.sendPort]);
  List message = await myReceivePort.first as List;
  bool mqttTls = message[0] == 'true';
  String mqttIP = message[1];
  String mqttDeviceName = message[2];
  String mqttPort = message[3];
  bool useCerts = message[4] == 'true';
  String certFile = message[5];
  String privateKeyFile = message[6];
  String mqttUsername = message[7];
  String mqttPassword = message[8];
  String mqttTopic = message[9];

  final AtSignLogger logger = AtSignLogger(' mqtt ');
  logger.hierarchicalLoggingEnabled = true;
  logger.logger.level = Level.WARNING;
  // Set up MQTT
  mqttSession = MqttServerClient.withPort(mqttIP, mqttDeviceName, int.parse(mqttPort), maxConnectionAttempts: 10);
  final builder = MqttClientPayloadBuilder();

  mqttSession.setProtocolV311();
  mqttSession.secure = mqttTls;
  if (useCerts) {
    //mqttSession.securityContext.setTrustedCertificates(trustedCertsFile);
    //mqttSession.securityContext.setClientAuthorities(trustedCertsFile);
    mqttSession.securityContext.useCertificateChain(certFile);
    mqttSession.securityContext.usePrivateKey(privateKeyFile);
  }
  mqttSession.keepAlivePeriod = 20;
  mqttSession.autoReconnect = true;
  // Pong Callback
  void pong() {
    logger.info('Mosquitto Ping response client callback invoked');
    pongCount++;
  }

  mqttSession.pongCallback = pong;

  /// Create a connection message to use or use the default one. The default one sets the
  /// client identifier, any supplied username/password and clean session,
  /// an example of a specific one below.
  MqttConnectMessage connMess;
  if (useCerts) {
    connMess = MqttConnectMessage().withClientIdentifier(mqttDeviceName).withWillQos(MqttQos.atLeastOnce);
    logger.info('Mosquitto client connecting....');
    mqttSession.connectionMessage = connMess;
  } else {
    connMess = MqttConnectMessage()
        .withClientIdentifier(mqttDeviceName)
        .authenticateAs(mqttUsername, mqttPassword)
        .withWillQos(MqttQos.atLeastOnce);
    logger.info('Mosquitto client connecting....');
    mqttSession.connectionMessage = connMess;
  }

  /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
  /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
  /// never send malformed messages.
  try {
    mqttSession.autoReconnect;
    await mqttSession.connect();
  } on NoConnectionException catch (e) {
    // Raised by the client when connection fails.
    logger.severe(' Mosquitto client exception - $e');
    mqttSession.disconnect();
    exit(-1);
  } on SocketException catch (e) {
    // Raised by the socket layer
    logger.severe(' Mosquitto socket exception - $e');
    mqttSession.disconnect();
    exit(-1);
  } on Exception catch (e) {
    logger.severe(' Mosquitto unknown exception - $e');
    mqttSession.disconnect();
    exit(-1);
  }

  /// Check we are connected
  if (mqttSession.connectionStatus!.state == MqttConnectionState.connected) {
    logger.info(' Mosquitto client connected');
  } else {
    /// Use status here rather than state if you also want the broker return code.
    logger.severe(' Mosquitto client connection failed - disconnecting, status is ${mqttSession.connectionStatus}');
    mqttSession.disconnect();
    exit(-1);
  }

  pubReceivePort.listen((message) {
    mqttSession.publishMessage(mqttTopic, MqttQos.atMostOnce, builder.addString(message).payload!, retain: false);
    builder.clear;
    print('sent');
  });
}
