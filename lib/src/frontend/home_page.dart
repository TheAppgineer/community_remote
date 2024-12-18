import 'dart:convert';

import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/browse.dart';
import 'package:community_remote/src/frontend/full_screen_dialog.dart';
import 'package:community_remote/src/frontend/mini_now_playing.dart';
import 'package:community_remote/src/frontend/now_playing.dart';
import 'package:community_remote/src/frontend/queue.dart';
import 'package:community_remote/src/frontend/zones.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mdi/mdi.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const kkbox = "KKBOX";
const qobuz = "Qobuz";
const tidal = "TIDAL";

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.version});

  final String version;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  IconData? _profileIcon;
  bool _profileStateEnabled = true;

  _setProfileIcon(String profileName, bool enabled) {
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
      _profileIcon = icon;
      _profileStateEnabled = enabled;
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
        appState.settings['theme'] = ThemeMode.dark.name;
        saveSettings(settings: jsonEncode(appState.settings));
      },
    );
    final lightModeButton = IconButton(
      icon: const Icon(Icons.light_mode_outlined),
      tooltip: 'Light Mode',
      onPressed: () {
        appState.settings['theme'] = ThemeMode.light.name;
        saveSettings(settings: jsonEncode(appState.settings));
      },
    );
    ThemeMode theme = ThemeMode.values.byName(appState.settings['theme']);
    IconButton themeModeButton = (theme == ThemeMode.dark ? lightModeButton : darkModeButton);
    String subtitle;
    Widget? stateIcon;
    String? userName = appState.userName;
    bool smallWidth = MediaQuery.sizeOf(context).width < smallScreenMaxWidth;
    Widget nowPlaying = smallWidth ? const MiniNowPlayingWidget() : const NowPlayingWidget();

    if (appState.serverName == null) {
      subtitle = 'No Roon Server discovered!';
      stateIcon = const Icon(Icons.warning, size: 32);
    } else if (appState.token == null) {
      if (userName == null) {
        subtitle = 'Use Roon Remote to enable extension, or request access below';
      } else {
        subtitle = 'Hi ${appState.userName}, access is requested';
      }

      stateIcon = const Icon(Icons.info, size: 32);
    } else if (!appState.initialized) {
      if (userName == null) {
        subtitle = 'Use Roon Remote to set access, or request access below';
      } else {
        subtitle = 'Hi ${appState.userName}, access is requested';
      }

      stateIcon = const Icon(Icons.info, size: 32);
    } else {
      if (userName == null) {
        subtitle = 'Served by: ${appState.serverName}';
      } else {
        subtitle = 'Welcome ${appState.userName}, enjoy the music!';
      }

      stateIcon = IconButton(
        icon: Icon(_profileIcon, size: 32),
        onPressed: _profileStateEnabled
          ? () {
            BrowseLevelState.selectProfile();
          }
          : null,
      );
    }

    bool gridMode = appState.settings['gridMode'] ?? false;
    bool hideQueue = appState.settings['hideQueue'] ?? false;
    List<Widget> children = [
      const HamburgerMenu(),
      const Expanded(
        flex: 1,
        child: Browse(),
      ),
    ];
    List<Widget> menuChildren = [
      MenuItemButton(
        child: const Text("User Manual"),
        onPressed: () {
          launchUrl(Uri.parse('https://theappgineer.com/community_remote/'));
        },
      ),
      MenuItemButton(
        child: const Text("About..."),
        onPressed: () {
          showDialog(context: context, builder: (context) {
            if (smallWidth) {
              return FullScreenDialog(
                title: 'About',
                child: Card(
                  margin: const EdgeInsets.all(10),
                  child: SizedBox.expand(child: About(version: widget.version)),
                ),
              );
            } else {
              return Dialog(child: SizedBox(
                width: 600,
                child: About(version: widget.version),
              ));
            }
          });
        },
      ),
    ];

    if (!smallWidth) {
      menuChildren.insert(0, MenuItemButton(
        child: Row(
          children: [
            const Text("Hide Queue", style: TextStyle(fontSize: 14)),
            const Padding(padding: EdgeInsets.only(left: 10)),
            Icon(hideQueue ? Icons.check_box_outlined : Icons.check_box_outline_blank_outlined),
          ],
        ),
        onPressed: () {
          appState.settings['hideQueue'] = !hideQueue;
          saveSettings(settings: jsonEncode(appState.settings));
        },
      ));
    }

    Widget overflow = MenuAnchor(
      consumeOutsideTap: true,
      builder: (context, controller, child) {
        return IconButton(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.more_vert),
        );
      },
      menuChildren: menuChildren,
    );
    IconButton? mode;

    if (!smallWidth && !hideQueue) {
      children.add(const Expanded(
        flex: 1,
        child: Queue(),
      ));
    }

    if (gridMode) {
      mode = IconButton(
        onPressed: () {
          appState.settings['gridMode'] = false;
          saveSettings(settings: jsonEncode(appState.settings));
        },
        tooltip: 'List View',
        icon: const Icon(Icons.list_outlined),
      );
    } else {
      mode = IconButton(
        onPressed: () {
          appState.settings['gridMode'] = true;
          saveSettings(settings: jsonEncode(appState.settings));
        },
        tooltip: 'Grid View',
        icon: const Icon(Icons.grid_view_outlined),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        scrolledUnderElevation: 0,
        title: ListTile(
          leading: smallWidth ? null : stateIcon,
          title: const Text('Community Remote'),
          subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          mode,
          themeModeButton,
          overflow,
          const Padding(padding: EdgeInsets.only(left: 5)),
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
                children: children,
              ),
            ),
            nowPlaying,
          ],
        ),
      ),
      floatingActionButton: QuickAccessButton(appState: appState, smallWidth: smallWidth,),
    );
  }
}

class About extends StatelessWidget {
  const About({
    super.key, required this.version
  });

  final String version;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Center(child: Text("Community Remote", style: TextStyle(fontSize: 18))),
              subtitle: Center(child: Text("Version $version")),
            ),
            const Text("Copyright \u{00A9} 2024 The Appgineer"),
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text('Latest Release', style: TextStyle(fontSize: 16)),
            ),
            IconButton(
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              onPressed: () {
                launchUrl(Uri.parse(
                  'https://github.com/TheAppgineer/community_remote/releases/latest/'
                ));
              },
              icon: const Image(width: 250, image: AssetImage('images/qr-community-remote-android.png')),
            ),
            const Text('Scan for Android, Click for Full List'),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: IconButton(
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                focusColor: Colors.transparent,
                onPressed: () {
                  launchUrl(Uri.parse('https://www.buymeacoffee.com/theappgineer'));
                },
                icon: Image.network(
                  width: 250,
                  'https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text('Become a Supporter'),
            ),
          ],
        ),
      ),
    );
  }
}

class Setup extends StatefulWidget {
  const Setup({
    super.key,
  });

  @override
  State<Setup> createState() => _SetupState();
}

class _SetupState extends State<Setup> {
  String? _ip;
  String? _port;
  TextEditingController? _ipController;
  TextEditingController? _portController;

  @override
  void initState() {
    super.initState();

    _getServerProperties();
  }

  @override
  void dispose() {
    if (_ipController != null) {
      _ipController!.dispose();
    }

    if (_portController != null) {
      _portController!.dispose();
    }

    super.dispose();
  }

  _getServerProperties() async {
    (String, String)? props = await getServerProperties();

    if (mounted && props != null) {
      _ipController = TextEditingController()..text = props.$1;
      _portController = TextEditingController()..text = props.$2;

      setState(() {
        _ip = props.$1;
        _port = props.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Supply Server IP and Port to bypass Server discovery',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.left,
              ),
            ),
            const Padding(padding: EdgeInsets.only(top: 20)),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                hintText: 'Server IP',
              ),
              onChanged: (value) {
                setState(() {
                  _ip = value;
                });
              },
            ),
            const Padding(padding: EdgeInsets.only(top: 20)),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                hintText: 'Server Port',
              ),
              onChanged: (value) {
                setState(() {
                  _port = value;
                });
              },
            ),
            const Padding(padding: EdgeInsets.only(top: 20)),
            ElevatedButton.icon(
              onPressed: () {
                if (_ip != null) {
                  setServerProperties(ip: _ip!, port: _port);
                }

                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.link_outlined),
              label: const Text('Connect to Server'),
            ),
          ],
        ),
      ),
    );
  }
}

class Request extends StatefulWidget {
  const Request({
    super.key,
    required this.appState,
  });

  final MyAppState appState;

  @override
  State<Request> createState() => _RequestState();
}

class _RequestState extends State<Request> {
  String? _userName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Enter your name to request access',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.left,
              ),
            ),
            const Padding(padding: EdgeInsets.only(top: 20)),
            TextField(
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                hintText: 'Your Name',
              ),
              onChanged: (value) {
                setState(() {
                  _userName = value;
                });
              },
            ),
            const Padding(padding: EdgeInsets.only(top: 20)),
            ElevatedButton.icon(
              onPressed: () {
                if (_userName != null) {
                  widget.appState.setUserName(_userName!);
                  String message = '${_userName!} requested access';
                  setStatusMessage(message: message);
                }

                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Request Access'),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickAccessButton extends StatelessWidget {
  const QuickAccessButton({
    super.key,
    required this.appState,
    required this.smallWidth,
  });

  final MyAppState appState;
  final bool smallWidth;

  Widget getIcon(String? userName) {
    IconData icon;

    if (appState.serverName == null) {
      icon = Icons.link_outlined;
    } else if (appState.token == null || !appState.initialized) {
      if (userName == null) {
        icon = Icons.lock_open_outlined;
      } else {
        icon = Icons.timelapse_outlined;
      }
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

  String? getTooltip(String? userName) {
    String? tooltip;

    if (appState.serverName == null) {
      tooltip = 'Connect Manually';
    } else if (appState.token == null || !appState.initialized) {
      if (userName == null) {
        tooltip = 'Request Access';
      } else {
        tooltip = 'Access is requested';
      }
    } else if (appState.zone == null) {
      tooltip = 'Select Zone';
    } else if (appState.pauseOnTrackEnd) {
      tooltip = 'Pausing at End of Track...';
    }

    return tooltip;
  }

  takeAction(context) {
    if (appState.serverName == null) {
      showDialog(
        context: context,
        builder: (context) {
          if (smallWidth) {
            return const FullScreenDialog(
              title: 'Server Setup',
              child: Card(
                margin: EdgeInsets.all(10),
                child: SizedBox.expand(child: Setup()),
              ),
            );
          } else {
            return const Dialog(
              child: Setup(),
            );
          }
        }
      );
    } else if (appState.token == null || !appState.initialized) {
      showDialog(
        context: context,
        builder: (context) {
          if (smallWidth) {
            return FullScreenDialog(
              title: 'Request Access',
              child: Card(
                margin: const EdgeInsets.all(10),
                child: SizedBox.expand(child: Request(appState: appState)),
              ),
            );
          } else {
            return Dialog(
              child: Request(appState: appState),
            );
          }
        }
      );
    } else if (appState.zone == null) {
      showDialog(
        context: context,
        builder: (context) {
          if (smallWidth) {
            return const FullScreenDialog(
              title: 'Zones',
              child: Zones(smallWidth: true),
            );
          } else {
            return const Dialog(
              child: Zones(smallWidth: false),
            );
          }
        },
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
    String? userName = appState.userName;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onLongPress: () {
          onLongPress();
        },
        child: FloatingActionButton(
          onPressed: appState.serverName != null && appState.token == null && userName != null
            ? null
            : () => takeAction(context),
          tooltip: getTooltip(userName),
          child: getIcon(userName),
        ),
      ),
    );
  }
}

class HamburgerMenu extends StatefulWidget {
  const HamburgerMenu({super.key});

  @override
  State<HamburgerMenu> createState() => _HamburgerMenuState();
}

class _HamburgerMenuState extends State<HamburgerMenu> {
  bool _setup = false;

  NavigationRailDestination _getDivider({String? label}) {
    return NavigationRailDestination(
      icon: const Divider(indent: 10, endIndent: 10),
      label: Text(label ?? "", style: const TextStyle(fontSize: 18)),
      disabled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    IconData icon = appState.settings['expand'] || _setup
      ? Icons.arrow_circle_left_outlined
      : Icons.arrow_circle_right_outlined;
    Map<int, Category> browsePath = {};
    bool smallWidth = MediaQuery.sizeOf(context).width < smallWindowMaxWidth;
    var destinations = [
      NavigationRailDestination(
        icon: Icon(icon),
        label: const Text(""),
        disabled: smallWidth,
      ),
      _getDivider(label: "Library"),
    ];

    NavigationRailDestination? getDestination(Category category, List<String> services) {
      IconData icon;
      String name;
      double? size;

      switch (category) {
        case Category.search:
          icon = Icons.search_outlined;
          name = "Search";
          break;
        case Category.artists:
          icon = Symbols.artist_rounded;
          name = 'Artists';
          break;
        case Category.albums:
          icon = Icons.album_outlined;
          name = 'Albums';
          break;
        case Category.tracks:
          icon = Icons.music_note_outlined;
          name = 'Tracks';
          break;
        case Category.genres:
          icon = Symbols.genres_rounded;
          name = 'Genres';
          break;
        case Category.composers:
          icon = Icons.person_3_outlined;
          name = 'Composers';
          break;
        case Category.tags:
          icon = Icons.label_outlined;
          name = 'Tags';
          break;
        case Category.liveRadio:
          icon = Icons.radio_outlined;
          name = 'Live Radio';
          break;
        case Category.playlists:
          icon = Icons.playlist_play_outlined;
          name = 'Playlists';
          break;
        case Category.kkbox:
          if (services.contains(kkbox)) {
            icon = Mdi.alphaKBoxOutline;
            name = kkbox;
            size = 32;
            break;
          }
          return null;
        case Category.qobuz:
          if (services.contains(qobuz)) {
            icon = Mdi.alphaQBoxOutline;
            name = qobuz;
            size = 32;
            break;
          }
          return null;
        case Category.tidal:
          if (services.contains(tidal)) {
            icon = Mdi.alphaTBoxOutline;
            name = tidal;
            size = 32;
            break;
          }
          return null;
        case Category.settings:
          icon = Icons.settings_outlined;
          name = 'Settings';
          break;
      }

      List hidden = appState.settings['hidden'] ?? [];
      Icon stateIcon = _setup
        ? hidden.contains(category.index) ? const Icon(Icons.toggle_off_outlined) : const Icon(Icons.toggle_on_outlined)
        : Icon(icon, size: size);

      return NavigationRailDestination(
        icon: stateIcon,
        label: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
      );
    }

    if (smallWidth && _setup) {
      _setup = false;
    }

    for (var category in Category.values) {
      if (category == Category.search) {
        continue;
      }

      List hidden = appState.settings['hidden'] ?? [];
      bool visible = _setup || !hidden.contains(category.index);
      NavigationRailDestination? destination = getDestination(category, appState.services);

      if (visible && destination != null) {
        if (category == Category.settings) {
          destinations.add(_getDivider());
        }

        browsePath[destinations.length] = category;
        destinations.add(destination);
      }
    }

    int? selectedIndex;

    for (var entry in browsePath.entries) {
      if (entry.value.index == appState.settings['view']) {
        selectedIndex = entry.key;
      }
    }

    return SingleChildScrollView(
      child: IntrinsicHeight(
        child: GestureDetector(
          onLongPress: smallWidth ? null : () {
            setState(() {
              _setup = true;
            });
          },
          child: NavigationRail(
            extended: (appState.settings['expand'] || _setup) && !smallWidth,
            minWidth: smallWidth ? 56 : 72,
            minExtendedWidth: 192,
            destinations: destinations,
            selectedIndex: selectedIndex,
            onDestinationSelected: (value) {
              if (value == 0) {
                if (_setup) {
                  saveSettings(settings: jsonEncode(appState.settings));

                  setState(() {
                    _setup = false;
                  });
                } else {
                  appState.settings['expand'] = !appState.settings['expand'];
                  saveSettings(settings: jsonEncode(appState.settings));
                }
              } else {
                Category? category = browsePath[value];

                if (category != null) {
                  if (_setup) {
                    List hidden = appState.settings['hidden'] ?? [];

                    if (hidden.contains(category.index)) {
                      hidden.remove(category.index);
                    } else {
                      hidden.add(category.index);
                    }

                    appState.settings['hidden'] = hidden;

                    setState(() {});
                  } else {
                    if (category.index != appState.settings['view']) {
                      appState.settings['view'] = category.index;
                      saveSettings(settings: jsonEncode(appState.settings));
                    }

                    BrowseLevelState.onDestinationSelected(category.index);
                  }
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
