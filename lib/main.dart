import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:community_remote/src/rust/api/roon_browse_wrapper.dart';
import 'package:community_remote/src/rust/api/roon_transport_wrapper.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:community_remote/src/rust/frb_generated.dart';

const roonAccentColor = Color.fromRGBO(0x75, 0x75, 0xf3, 1.0);

Future<void> main() async {
  var appState = MyAppState();

  await RustLib.init();
  await startRoon(cb: appState.cb);

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
      themeMode: appState.themeMode,
      home: const MyHomePage(title: 'Community Remote'),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String serverName = '';
  ThemeMode themeMode = ThemeMode.light;
  List<ZoneSummary>? zoneList;
  List<BrowseItem>? browseList;
  int pageSize = 0;
  int total = 0;
  RoonZone? zone;
  Map<String, Uint8List> imageCache = {};

  setThemeMode(newThemeMode) {
    themeMode = newThemeMode;

    notifyListeners();
  }

  void cb(event) {
    if (event is RoonEvent_CoreFound) {
      serverName = event.field0;
    } else if (event is RoonEvent_ZonesChanged) {
      zoneList = event.field0;
    } else if (event is RoonEvent_ZoneSelected) {
      zone = event.field0;
    } else if (event is RoonEvent_BrowseItems) {
      if (event.field0.offset == 0) {
        pageSize = event.field0.items.length;
        total = event.field0.total;
        browseList = event.field0.items;
      } else {
        browseList?.addAll(event.field0.items);
      }
    } else if (event is RoonEvent_Image) {
      imageCache[event.field0.imageKey] = event.field0.image;
    }

    notifyListeners();
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final darkModeButton = IconButton(
      icon: const Icon(Icons.dark_mode_outlined),
      tooltip: 'Dark Mode',
      onPressed: () {
        appState.setThemeMode(ThemeMode.dark);
      },
    );
    final lightModeButton = IconButton(
      icon: const Icon(Icons.light_mode_outlined),
      tooltip: 'Light Mode',
      onPressed: () {
        appState.setThemeMode(ThemeMode.light);
      },
    );
    var themeModeButton = (appState.themeMode == ThemeMode.dark ? lightModeButton : darkModeButton);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(title),
          subtitle: Text('Connected to: ${appState.serverName}'),
        ),
        actions: [
          themeModeButton,
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: Browse(),
                  ),
                  Expanded(
                    flex: 5,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        Queue(),
                        Zones(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: NowPlaying(),
            ),
          ],
        ),
      ),
    );
  }
}

class Browse extends StatelessWidget {
  const Browse({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var browseList = appState.browseList;
    ListView? listView;

    if (browseList != null) {
      ListTile itemBuilder(context, index) {
        Image? image = getImageFromCache(browseList[index].imageKey, appState.imageCache);
        Text? subtitle;

        if (browseList[index].subtitle != null) {
          subtitle = Text(browseList[index].subtitle!);
        }

        return ListTile(
          trailing: image,
          title: Text(browseList[index].title),
          subtitle: subtitle,
          onTap: () {
            selectBrowseItem(itemKey: browseList[index].itemKey);
          },
        );
      }

      listView = ListView.separated(
        controller: ScrollController(),
        padding: const EdgeInsets.all(10),
        itemBuilder: itemBuilder,
        separatorBuilder: (context, index) => const Divider(),
        itemCount: browseList.length,
      );
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: listView,
      ),
    );
  }
}

class Queue extends StatelessWidget {
  const Queue({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(10),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Text(''),
      ),
    );
  }
}

class Zones extends StatelessWidget {
  const Zones({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var zones = appState.zoneList;
    ListView? listView;

    if (zones != null) {
      ListTile itemBuilder(context, index) {
        var imageKey = zones[index].imageKey;
        Image? image = getImageFromCache(imageKey, appState.imageCache);
        Icon? playState;
        Text? metaData;

        switch (zones[index].state) {
          case ZoneState.playing:
            playState = const Icon(Icons.play_circle_outline);
            break;
          case ZoneState.paused:
            playState = const Icon(Icons.pause_circle_outline);
            break;
          case ZoneState.loading:
            playState = const Icon(Icons.hourglass_top_outlined);
            break;
          case ZoneState.stopped:
            playState = const Icon(Icons.stop_circle_outlined);
            break;
        }

        if (zones[index].nowPlaying != null) {
          metaData = Text(zones[index].nowPlaying!);
        }

        return ListTile(
          leading: playState,
          trailing: image,
          title: Text(zones[index].displayName),
          subtitle: metaData,
          onTap: () {
            selectZone(zoneId: zones[index].zoneId);
          },
        );
      }

      listView = ListView.separated(
        controller: ScrollController(),
        padding: const EdgeInsets.all(10),
        itemBuilder: itemBuilder,
        separatorBuilder: (context, index) => const Divider(),
        itemCount: zones.length,
      );
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: listView,
    );
  }
}

class NowPlaying extends StatelessWidget {
  const NowPlaying({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    ListTile child = const ListTile(
      title: Text('Go find something to play'),
    );

    if (appState.zone != null && appState.zone!.nowPlaying != null) {
      ZoneNowPlaying nowPlaying = appState.zone!.nowPlaying!;

      child = ListTile(
        leading: getImageFromCache(nowPlaying.imageKey, appState.imageCache),
        title: Text(nowPlaying.threeLine[0]),
        subtitle: Text('${nowPlaying.threeLine[1]}\n${nowPlaying.threeLine[2]}'),
        isThreeLine: true,
      );
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: child,
          ),
          ElevatedButton.icon(
            onPressed: () {

            },
            icon: const Icon(Icons.speaker_outlined),
            label: const Text('Zones'),
          ),
          ElevatedButton.icon(
            onPressed: () {

            },
            icon: const Icon(Icons.volume_up),
            label: const Text('Volume'),
          ),
        ],
      ),
    );
  }
}

Image? getImageFromCache(String? imageKey, Map<String, Uint8List> imageCache) {
  Image? image;

  if (imageKey != null) {
    var byteList = imageCache[imageKey];

    if (byteList != null) {
      image = Image.memory(byteList);
    } else {
      getImage(imageKey: imageKey, width: 100, height: 100);
    }
  }

  return image;
}
