import 'dart:convert';

import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/browse.dart';
import 'package:community_remote/src/frontend/now_playing.dart';
import 'package:community_remote/src/frontend/queue.dart';
import 'package:community_remote/src/frontend/zones.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mdi/mdi.dart';
import 'package:provider/provider.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  Icon? _profileIcon;

  _setProfileIcon(String profileName) {
    IconData icon;

    switch (profileName[0].toLowerCase()) {
      case 'a':
        icon = Mdi.alphaACircleOutline;
      case 'b':
        icon = Mdi.alphaBCircleOutline;
      case 'c':
        icon = Mdi.alphaCCircleOutline;
      case 'd':
        icon = Mdi.alphaDCircleOutline;
      case 'e':
        icon = Mdi.alphaECircleOutline;
      case 'f':
        icon = Mdi.alphaFCircleOutline;
      case 'g':
        icon = Mdi.alphaGCircleOutline;
      case 'h':
        icon = Mdi.alphaHCircleOutline;
      case 'i':
        icon = Mdi.alphaICircleOutline;
      case 'j':
        icon = Mdi.alphaJCircleOutline;
      case 'k':
        icon = Mdi.alphaKCircleOutline;
      case 'l':
        icon = Mdi.alphaLCircleOutline;
      case 'm':
        icon = Mdi.alphaMCircleOutline;
      case 'n':
        icon = Mdi.alphaNCircleOutline;
      case 'o':
        icon = Mdi.alphaOCircleOutline;
      case 'p':
        icon = Mdi.alphaPCircleOutline;
      case 'q':
        icon = Mdi.alphaQCircleOutline;
      case 'r':
        icon = Mdi.alphaRCircleOutline;
      case 's':
        icon = Mdi.alphaSCircleOutline;
      case 't':
        icon = Mdi.alphaTCircleOutline;
      case 'u':
        icon = Mdi.alphaUCircleOutline;
      case 'v':
        icon = Mdi.alphaVCircleOutline;
      case 'w':
        icon = Mdi.alphaWCircleOutline;
      case 'x':
        icon = Mdi.alphaXCircleOutline;
      case 'y':
        icon = Mdi.alphaYCircleOutline;
      case 'z':
        icon = Mdi.alphaZCircleOutline;
      default:
        icon = Mdi.alphaPCircleOutline;
    }

    setState(() {
      _profileIcon = Icon(icon, size: 32);
    });
  }

  @override void initState() {
    super.initState();

    MyAppState.setProfileCallback(_setProfileIcon);
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
    String subtitle = appState.serverName != null
      ? 'Served by: ${appState.serverName}'
      : 'Use Roon Remote to Enable Extension';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        scrolledUnderElevation: 0,
        title: ListTile(
          leading: _profileIcon,
          title: Text(widget.title),
          subtitle: Text(subtitle),
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
              flex: 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HamburgerMenu(),
                  Expanded(
                    flex: 5,
                    child: Browse(),
                  ),
                  Expanded(
                    flex: 5,
                    child: Queue(),
                  ),
                ],
              ),
            ),
            NowPlayingWidget(),
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

    if (appState.serverName == null) {
      icon = Icons.help_center_outlined;
    } else if (appState.zone == null) {
      icon = Icons.speaker_outlined;
    } else if (appState.pauseOnTrackEnd) {
      icon = Icons.timelapse_outlined;
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

  String? getTooltip() {
    String? tooltip;

    if (appState.serverName == null) {
      tooltip = "How To Connect?";
    } else if (appState.zone == null) {
      tooltip = "Select Zone";
    } else if (appState.pauseOnTrackEnd) {
      tooltip = "Pausing at End of Track...";
    }

    return tooltip;
  }

  takeAction(context) {
    if (appState.serverName == null) {
    } else if (appState.zone == null) {
      showDialog(
        context: context,
        builder: (context) => const Dialog(
          child: Zones(),
        ),
      );
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

  onLongPress() {
    if (appState.zone != null && appState.zone!.nowPlaying != null) {
      var zone = appState.zone!;
      var nowPlaying = zone.nowPlaying!;

      if (zone.state == PlayState.playing && nowPlaying.length != null && nowPlaying.length! > 0) {
        pauseOnTrackEnd();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onLongPress: () {
          onLongPress();
        },
        child: FloatingActionButton(
          onPressed: () => takeAction(context),
          tooltip: getTooltip(),
          child: getIcon(),
        ),
      ),
    );
  }
}

class HamburgerMenu extends StatelessWidget {
  const HamburgerMenu({super.key});

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
          onDestinationSelected: (value) {
            if (value == 0) {
              appState.settings["expand"] = !appState.settings["expand"];
              saveSettings(settings: jsonEncode(appState.settings));
            } else {
              if (value != appState.settings["view"]) {
                appState.settings["view"] = value;
                saveSettings(settings: jsonEncode(appState.settings));
              }

              BrowseLevelState.onDestinationSelected(value);
            }
          },
        ),
      ),
    );
  }
}
