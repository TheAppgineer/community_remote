import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:community_remote/src/rust/backend/roon.dart';
import 'package:community_remote/src/rust/frb_generated.dart';

const roonAccentColor = Color.fromRGBO(0x75, 0x75, 0xf3, 1.0);

var appState = MyAppState();

Future<void> main() async {
  await RustLib.init();
  await startRoon(cb: appState.cb);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => appState,
      child: MaterialApp(
        title: 'Community Remote',
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
        themeMode: ThemeMode.light,
        home: const MyHomePage(title: 'Community Remote'),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String serverName = '';
  dynamic zoneList;
  var count = 0;
  Map<String, Uint8List> imageCache = {};

  void cb(event) {
    if (event is RoonEvent_CoreFound) {
      serverName = event.field0;
    } else if (event is RoonEvent_ZonesChanged) {
      zoneList = event.field0;
    } else if (event is RoonEvent_Image) {
      for (var (key, image) in event.field0) {
        imageCache[key] = image;
      }
    }
    notifyListeners();
  }

  Future<void> incrementCounter() async {
    count = await incCounter();
    notifyListeners();
  }

  int counter() {
    return count;
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('$title (${appState.serverName})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dark_mode),
            tooltip: 'Dark Mode',
            onPressed: () {

            },
          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: appState.incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.shuffle),
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
    return const Card(
      margin: EdgeInsets.all(10),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Text(
          'You have pushed the ',
          textAlign: TextAlign.center,
        ),
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
        child: Text(
          'button this many times:',
        ),
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
        Image? image;
        Icon? playState;
        Text? metaData;

        if (imageKey != null) {
          var byteList = appState.imageCache[imageKey];

          if (byteList != null) {
            image = Image.memory(byteList);
          } else {
            getImage(imageKey: imageKey, width: 100, height: 100);
          }
        }

        switch (zones[index].playState) {
          case PlayState.playing:
            playState = const Icon(Icons.play_circle_outline);
            break;
          case PlayState.paused:
            playState = const Icon(Icons.pause_circle_outline);
            break;
          case PlayState.loading:
            playState = const Icon(Icons.hourglass_top_outlined);
            break;
          case PlayState.stopped:
            playState = const Icon(Icons.stop_circle_outlined);
            break;
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

    return Card(
      margin: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '${appState.counter()}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
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
