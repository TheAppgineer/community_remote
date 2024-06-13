import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/browse.dart';
import 'package:community_remote/src/frontend/home_page.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:community_remote/src/rust/frb_generated.dart';

var appState = MyAppState();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RustLib.init();

  Directory supportPath = await getApplicationSupportDirectory();
  String jsonString = await startRoon(supportPath: supportPath.path, cb: appState.cb);
  Map<String, dynamic> stored = jsonDecode(jsonString) as Map<String, dynamic>;
  Map<String, dynamic> settings = stored.isNotEmpty ? stored : {
    "expand": false,
    "theme": "light",
    "view": Category.artists.index,
    "zoneId": null,
  };
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  appState.setSettings(settings);

  runApp(
    ChangeNotifierProvider(
      create: (context) => appState,
      child: MyApp(title: 'Community Remote v${packageInfo.version}'),
    )
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.title});

  final String title;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<HardwareButton>? _volumeListener;

  _registerVolumeListener() {
    if (Platform.isAndroid) {
      _volumeListener = FlutterAndroidVolumeKeydown.stream.listen((event) {
        if (event == HardwareButton.volume_up) {
          appState.incVolume();
        } else if (event == HardwareButton.volume_down) {
          appState.decVolume();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerVolumeListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _volumeListener?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _registerVolumeListener();
        break;
      default:
        _volumeListener?.cancel();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return MaterialApp(
      title: widget.title,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: roonAccentColor,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: roonAccentColor,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.values.byName(appState.settings['theme']),
      home: MyHomePage(title: widget.title),
    );
  }
}
