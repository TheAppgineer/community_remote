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
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  String jsonString = await startRoon(supportPath: supportPath.path, cb: appState.cb);
  Map<String, dynamic> stored = jsonDecode(jsonString) as Map<String, dynamic>;
  Map<String, dynamic> settings = stored.isNotEmpty ? stored : {
    "expand": false,
    "theme": "light",
    "view": Category.artists.index,
    "zoneId": null,
    "userName": null,
  };

  appState.setSettings(settings);

  runApp(
    ChangeNotifierProvider(
      create: (context) => appState,
      child: Main(version: packageInfo.version),
    )
  );
}

class Main extends StatefulWidget {
  const Main({super.key, required this.version});

  final String version;

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> with WidgetsBindingObserver {
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: roonAccentColor,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: roonAccentColor,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.values.byName(appState.settings['theme']),
      home: HomePage(version: widget.version),
    );
  }
}
