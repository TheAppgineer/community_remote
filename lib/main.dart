import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/home_page.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:community_remote/src/rust/frb_generated.dart';

Future<void> main() async {
  var appState = MyAppState();

  await RustLib.init();

  String jsonString = await startRoon(cb: appState.cb);
  Map<String, dynamic> stored = jsonDecode(jsonString) as Map<String, dynamic>;
  Map<String, dynamic> settings = stored.isNotEmpty ? stored : {
    "expand": false,
    "theme": "light",
    "view": 11,
    "zoneId": null,
  };

  appState.setSettings(settings);

  runApp(
    ChangeNotifierProvider(
      create: (context) => appState,
      child: const MyApp(),
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return MaterialApp(
      title: 'Community Remote',
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
      themeMode: ThemeMode.values.byName(appState.settings["theme"]),
      home: const MyHomePage(title: 'Community Remote'),
    );
  }
}
