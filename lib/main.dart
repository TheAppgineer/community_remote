import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:community_remote/src/rust/api/roon_browse_mirror.dart';
import 'package:community_remote/src/rust/api/roon_transport_wrapper.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:community_remote/src/rust/frb_generated.dart';

const roonAccentColor = Color.fromRGBO(0x75, 0x75, 0xf3, 1.0);
const exploreId = 0;

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
      themeMode: appState.themeMode(),
      home: const MyHomePage(title: 'Community Remote'),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String? serverName;
  List<ZoneSummary>? zoneList;
  BrowseItems? browseItems;
  List<BrowseItem>? actionItems;
  String? pendingAction;
  RoonZone? zone;
  Map<String, Uint8List> imageCache = {};
  late Settings settings;

  ThemeMode themeMode() {
    ThemeMode themeMode = ThemeMode.light;

    switch (settings.theme) {
      case ThemeEnum.dark:
        themeMode = ThemeMode.dark;
        break;
      case ThemeEnum.light:
        themeMode = ThemeMode.light;
        break;
      case ThemeEnum.system:
        themeMode = ThemeMode.system;
        break;
    }

    return themeMode;
  }

  void cb(event) {
    if (event is RoonEvent_Settings) {
      settings = event.field0;
    } else if (event is RoonEvent_CoreFound) {
      serverName = event.field0;

      browse(category: settings.view, sessionId: exploreId);

      if (settings.zoneId != null) {
        selectZone(zoneId: settings.zoneId!);
      }
    } else if (event is RoonEvent_ZonesChanged) {
      zoneList = event.field0;
    } else if (event is RoonEvent_ZoneChanged) {
      zone = event.field0;
    } else if (event is RoonEvent_BrowseItems) {
      if (browseItems == null || event.field0.offset == 0) {
        browseItems = event.field0;
      } else {
        browseItems!.items.addAll(event.field0.items);
      }
    } else if (event is RoonEvent_BrowseActions) {
      actionItems = event.field0;

      if (actionItems != null && pendingAction != null) {
        for (var item in actionItems!) {
          if (item.title == pendingAction) {
            selectBrowseItem(sessionId: exploreId, item: item);
            pendingAction = null;
            break;
          }
        }
      }
    } else if (event is RoonEvent_Image) {
      imageCache[event.field0.imageKey] = event.field0.image;
    }

    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
        appState.settings.setTheme(theme: ThemeEnum.dark);
      },
    );
    final lightModeButton = IconButton(
      icon: const Icon(Icons.light_mode_outlined),
      tooltip: 'Light Mode',
      onPressed: () {
        appState.settings.setTheme(theme: ThemeEnum.light);
      },
    );
    IconButton themeModeButton = (appState.settings.theme == ThemeEnum.dark ? lightModeButton : darkModeButton);

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
          IconButton(
            icon: const Icon(Icons.search_outlined),
            tooltip: "Search",
            onPressed: () {},
          ),
          themeModeButton,
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 8,
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
                        Zones(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              flex: 2,
              child: NowPlaying(),
            ),
          ],
        ),
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
    Icon icon = Icon(appState.settings.expand ? Icons.arrow_circle_left_outlined : Icons.arrow_circle_right_outlined);

    return SingleChildScrollView(
      child: IntrinsicHeight(
        child: NavigationRail(
          extended: appState.settings.expand,
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
          selectedIndex: appState.settings.view,
          onDestinationSelected: onDestinationSelected,
        ),
      ),
    );
  }
}

class CustomRoute<T> extends MaterialPageRoute<T> {
  CustomRoute({ required super.builder, required RouteSettings super.settings });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 0);

  @override
  Widget buildTransitions(BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    return child;
  }
}

class Router {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    return CustomRoute(builder: (_) => const BrowseLevel(), settings: settings);
  }
}

class Browse extends StatelessWidget {
  const Browse({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return MaterialApp(
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
      themeMode: appState.themeMode(),
      onGenerateRoute: Router.generateRoute,
      initialRoute: "-",
    );
  }
}

class BrowseLevel extends StatefulWidget {
  const BrowseLevel({
    super.key,
  });

  @override
  State<BrowseLevel> createState() => _BrowseLevelState();
}

class _BrowseLevelState extends State<BrowseLevel> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_loadMore);
  }

  Future<void> _loadMore() async {
    if (_controller.position.extentAfter < 300) {
      await browseNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    ListView? listView;
    Widget? browseTitle;

    void onDestinationSelected(value) {
      if (value == 0) {
        appState.settings.setExpand(expand: !appState.settings.expand);
      } else {
        browse(category: value, sessionId: exploreId);
        appState.settings.setView(view: value);
        Navigator.of(context).popUntil(ModalRoute.withName('-'));
      }
    }

    var home = context.findAncestorStateOfType<_MyHomePageState>();
    home!.setOnDestinationSelected(onDestinationSelected);

    if (appState.browseItems != null) {
      var browseList = appState.browseItems!.items;
      var subtitle = appState.browseItems!.list.subtitle;
      var imageKey = appState.browseItems!.list.imageKey;

      if (subtitle != null) {
        browseTitle = ListTile(
          title: Text(appState.browseItems!.list.title),
          subtitle: Text(subtitle),
          trailing: imageKey != null ? getImageFromCache(imageKey, appState.imageCache) : null,
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 32, 0),
        );
      } else {
        browseTitle = Text(appState.browseItems!.list.title);
      }

      ListTile itemBuilder(context, index) {
        Widget? leading;
        Widget? trailing;
        Image? image = getImageFromCache(browseList[index].imageKey, appState.imageCache);
        Text? subtitle;

        if (image != null) {
          leading = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              image,
              const Padding(padding: EdgeInsets.fromLTRB(0, 0, 10, 0)),
            ],
          );
        } else {
          leading = const Padding(padding: EdgeInsets.fromLTRB(58, 0, 0, 0));
        }

        if (browseList[index].hint == BrowseItemHint.actionList) {
          trailing = MenuAnchor(
            builder: (context, controller, child) {
              return IconButton(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                    selectBrowseItem(sessionId: exploreId, item: browseList[index]);
                  }
                },
                icon: const Icon(Icons.more_vert),
              );
            },
            menuChildren: List<MenuItemButton>.generate(
              (appState.actionItems != null ? appState.actionItems!.length : 0),
              (index) => MenuItemButton(
                child: Text(appState.actionItems![index].title),
                onPressed: () {
                  selectBrowseItem(sessionId: exploreId, item: appState.actionItems![index]);
                  appState.actionItems = null;
                },
              ),
            ),
            onClose: () {
              // Delay the onClose handling to make sure onPressed can be handled first
              Future.delayed(const Duration(milliseconds: 100), () {
                if (appState.actionItems != null) {
                  appState.actionItems = null;
                  browseBack(sessionId: exploreId);
                }
              });
            },
          );
        }

        if (browseList[index].subtitle != null) {
          subtitle = Text(browseList[index].subtitle!);
        }

        return ListTile(
          leading: leading,
          trailing: trailing,
          title: Text(browseList[index].title),
          subtitle: subtitle,
          onTap: () {
            switch (browseList[index].hint) {
              case BrowseItemHint.action:
                break;
              case BrowseItemHint.actionList:
                // Take "Play Now" as default action, at least for now
                appState.pendingAction = "Play Now";
                break;
              default:
                Navigator.pushNamed(context, appState.browseItems!.list.level.toString());
                break;
            }

            selectBrowseItem(sessionId: exploreId, item: browseList[index]);
          },
        );
      }

      listView = ListView.separated(
        controller: _controller,
        padding: const EdgeInsets.all(10),
        itemBuilder: itemBuilder,
        separatorBuilder: (context, index) => const Divider(),
        itemCount: browseList.length,
      );
    }

    return PopScope(
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          title: browseTitle,
        ),
        body: Card(
          margin: const EdgeInsets.all(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: listView,
          ),
        ) ,
      ),
      onPopInvoked: (didPop) {
        if (didPop) {
          appState.browseItems = null;
          browseBack(sessionId: exploreId);
        }
      },
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
            var zoneId = zones[index].zoneId;

            appState.settings.setZoneId(zoneId: zoneId);
            selectZone(zoneId: zoneId);
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
