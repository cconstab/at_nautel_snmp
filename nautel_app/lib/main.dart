import 'dart:async';
import 'dart:io';

import 'package:at_app_flutter/at_app_flutter.dart' show AtEnv;
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart'
    show Onboarding;
import 'package:at_utils/at_logger.dart' show AtSignLogger;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nautel_app/screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

import 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory;
import 'package:window_manager/window_manager.dart';

final AtSignLogger _logger = AtSignLogger(AtEnv.appNamespace);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  if (kIsWeb) {
    print('here');
  } else {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = const WindowOptions(
        size: Size(425, 720),
        maximumSize: Size(425, 720),
        minimumSize: Size(425, 720),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
  }

  runApp(const MyApp());
}

Future<AtClientPreference> loadAtClientPreference() async {
  var dir = await getApplicationSupportDirectory();

  return AtClientPreference()
    ..rootDomain = 'root.atsign.org'
    ..namespace = 'kryz_9850'
    ..hiveStoragePath = dir.path
    ..commitLogPath = dir.path
    ..fetchOfflineNotifications = false
    ..isLocalStoreRequired = true;

  // TODO
  // * By default, this configuration is suitable for most applications
  // * In advanced cases you may need to modify [AtClientPreference]
  // * Read more here: https://pub.dev/documentation/at_client/latest/at_client/AtClientPreference-class.html
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // * load the AtClientPreference in the background
  Future<AtClientPreference> futurePreference = loadAtClientPreference();

  @override
  Widget build(BuildContext context) {
    String firstScreen;
    if (kIsWeb) {
      firstScreen = HomeScreen.id;
    } else {
      firstScreen = OnboardingScreen.id;
    }
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            backgroundColor: Colors.blue, primarySwatch: Colors.green),
        // * The onboarding screen (first screen)
        routes: {
          HomeScreen.id: (_) => HomeScreen(),
          OnboardingScreen.id: (_) => const OnboardingScreen(),
          //Next.id: (_) => const Next(),
        },
        initialRoute: firstScreen);
  }
}
