import 'dart:convert';

import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/browse.dart';
import 'package:community_remote/src/frontend/now_playing.dart';
import 'package:community_remote/src/frontend/queue.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  void Function(int)? _onDestinationSelected;

  void setOnDestinationSelected(onDestinationSelected) {
    _onDestinationSelected = onDestinationSelected;
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final darkModeButton = IconButton(
      icon: const Icon(Icons.dark_mode_outlined),
      tooltip: 'Dark Mode',
      onPressed: () {
        appState.settings["theme"] = ThemeMode.dark.name;
        saveSettings(settings: jsonEncode(appState.settings));
      },
    );
    final lightModeButton = IconButton(
      icon: const Icon(Icons.light_mode_outlined),
      tooltip: 'Light Mode',
      onPressed: () {
        appState.settings["theme"] = ThemeMode.light.name;
        saveSettings(settings: jsonEncode(appState.settings));
      },
    );
    ThemeMode theme = ThemeMode.values.byName(appState.settings["theme"]);
    IconButton themeModeButton = (theme == ThemeMode.dark ? lightModeButton : darkModeButton);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        scrolledUnderElevation: 0,
        title: ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(widget.title),
          subtitle: Text('Served by: ${appState.serverName}'),
        ),
        actions: [
          themeModeButton,
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HamburgerMenu(onDestinationSelected: _onDestinationSelected),
                  const Expanded(
                    flex: 5,
                    child: Browse(),
                  ),
                  const Expanded(
                    flex: 5,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        Queue(),
                        //Zones(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const NowPlayingWidget(),
          ],
        ),
      ),
      floatingActionButton: QuickAccessButton(appState: appState),
    );
  }
}

class QuickAccessButton extends StatelessWidget {
  const QuickAccessButton({
    super.key,
    required this.appState,
  });

  final MyAppState appState;

  Widget getIcon() {
    IconData icon;

    if (appState.zone == null) {
      icon = Icons.speaker_outlined;
    } else {
      switch (appState.zone!.state) {
        case PlayState.playing:
          icon = Icons.pause_circle_outline;
          break;
        case PlayState.paused:
        case PlayState.stopped:
          icon = Icons.play_circle_outline;
          break;
        case PlayState.loading:
          icon = Icons.hourglass_top_outlined;
          break;
      }
    }

    return Icon(icon, size: 36);
  }

  String getTooltip() {
    String tooltip;

    if (appState.zone == null) {
      tooltip = "Select Zone";
    } else {
      switch (appState.zone!.state) {
        case PlayState.playing:
          tooltip = "Pause";
          break;
        case PlayState.paused:
        case PlayState.stopped:
          tooltip = "Play";
          break;
        case PlayState.loading:
          tooltip = "Loading...";
          break;
      }
    }

    return tooltip;
  }

  takeAction() {
    if (appState.zone == null) {
    } else {
      switch (appState.zone!.state) {
        case PlayState.playing:
          control(control: Control.pause);
          break;
        case PlayState.paused:
        case PlayState.stopped:
          control(control: Control.play);
          break;
        case PlayState.loading:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FloatingActionButton(
        onPressed: () {
          takeAction();
        },
        tooltip: getTooltip(),
        child: getIcon(),
      ),
    );
  }
}

class HamburgerMenu extends StatelessWidget {
  const HamburgerMenu({super.key, this.onDestinationSelected});

  final void Function(int)? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    Icon icon = Icon(appState.settings["expand"] ? Icons.arrow_circle_left_outlined : Icons.arrow_circle_right_outlined);

    return SingleChildScrollView(
      child: IntrinsicHeight(
        child: NavigationRail(
          extended: appState.settings["expand"],
          minWidth: 72,
          minExtendedWidth: 192,
          destinations: [
            NavigationRailDestination(
              icon: icon,
              label: const Text(""),
            ),
            const NavigationRailDestination(
              icon: Divider(indent: 10, endIndent: 10),
              label: Text("Library", style: TextStyle(fontSize: 18)),
              disabled: true,
            ),
            const NavigationRailDestination(
              icon: Icon(Symbols.artist_rounded),
              label: Text("Artists", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.album_outlined),
              label: Text("Albums", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.music_note_outlined),
              label: Text("Tracks", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            ),
            const NavigationRailDestination(
              icon: Icon(Symbols.genres_rounded),
              label: Text("Genres", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.person_3_outlined),
              label: Text("Composers", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.label_outlined),
              label: Text("Tags", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.radio_outlined),
              label: Text("Live Radio", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.playlist_play_outlined),
              label: Text("Playlists", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            ),
            const NavigationRailDestination(
              icon: Divider(indent: 10, endIndent: 10),
              label: Text(""),
              disabled: true,
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              label: Text("Settings", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            ),
          ],
          selectedIndex: appState.settings["view"],
          onDestinationSelected: onDestinationSelected,
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
        Image? image = appState.getImageFromCache(imageKey);
        Icon? playState;
        Text? metaData;

        switch (zones[index].state) {
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

        if (zones[index].nowPlaying != null) {
          metaData = Text(zones[index].nowPlaying!);
        }

        return ListTile(
          leading: playState,
          trailing: image,
          title: Text(zones[index].displayName),
          subtitle: metaData,
          onTap: () {
            var zoneId = zones[index].zoneId;

            appState.settings["zoneId"] = zoneId;
            selectZone(zoneId: zoneId);
            saveSettings(settings: jsonEncode(appState.settings));
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
