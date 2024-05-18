import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/rust/api/roon_browse_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

enum Category {
  search,
  artists,
  albums,
  tracks,
  genres,
  composers,
  tags,
  liveRadio,
  playlists,
  settings,
}

final MyNavigator _navigator = MyNavigator();

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

class MyNavigator {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  List<String> routes = ['-'];

  dynamic pushNamed(String route, {dynamic arguments}) {
    routes.add(route);
    return navigatorKey.currentState?.pushNamed(route, arguments: arguments);
  }

  dynamic pop() {
    routes.removeLast();
    return navigatorKey.currentState?.pop();
  }

  void popUntil(String name) {
    if (_isAncestor(name)) {
      int start = routes.indexOf(name) + 1;
      routes.removeRange(start, routes.length);
    }

    navigatorKey.currentState?.popUntil(ModalRoute.withName(name));
  }

  void popUntilRoot() {
    routes = ['-'];
    navigatorKey.currentState?.popUntil(ModalRoute.withName('-'));
  }

  bool canPop() {
    if (navigatorKey.currentState != null) {
      return navigatorKey.currentState!.canPop();
    } else {
      return false;
    }
  }

  String get currentRoute {
    return routes[routes.length - 1];
  }

  bool _isAncestor(String name) {
    return (currentRoute != name && routes.contains(name));
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
      themeMode: ThemeMode.values.byName(appState.settings['theme']),
      onGenerateRoute: Router.generateRoute,
      initialRoute: "-",
      navigatorKey: _navigator.navigatorKey,
    );
  }
}

class BrowseLevel extends StatefulWidget {
  const BrowseLevel({
    super.key,
  });

  @override
  State<BrowseLevel> createState() => BrowseLevelState();
}

class BrowseLevelState extends State<BrowseLevel> with WidgetsBindingObserver {
  static bool _viewChanged = false;
  late final ScrollController _controller;
  late String _route;
  BrowseItems? _browseItems;
  final Map<String, Image> _imageCache = {};
  bool _isScrolling = false;

  static void onDestinationSelected(int category) {
    _viewChanged = true;

    _navigator.popUntilRoot();

    browse(category: category, sessionId: exploreId);
  }

  void addToImageCache(ImageKeyValue keyValue) {
    if (mounted) {
      setState(() {
        _imageCache[keyValue.imageKey] = Image.memory(keyValue.image);
      });
    }
  }

  void _handleScrollChange() {
    if (_isScrolling != _controller.position.isScrollingNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isScrolling = _controller.position.isScrollingNotifier.value;
        });
      });
    }
  }

  void _handlePositionAttach(ScrollPosition position) {
    position.isScrollingNotifier.addListener(_handleScrollChange);
  }

  void _handlePositionDetach(ScrollPosition position) {
    position.isScrollingNotifier.removeListener(_handleScrollChange);
  }

  void _setBrowseItems(BrowseItems newItems) {
    if (_browseItems == null || _viewChanged) {
      _viewChanged = false;

      if (_controller.positions.isNotEmpty) {
        _controller.jumpTo(0);
      }

      _browseItems = newItems;

      if (mounted) {
        setState(() {});
      }
    } else if (_browseItems!.list.level == newItems.list.level) {
      if (_browseItems!.items.length == newItems.offset) {
        _browseItems!.items.addAll(newItems.items);

        if (mounted) {
          setState(() {});
        }
      } else {
        int end = newItems.offset + newItems.items.length;

        _browseItems!.items.removeRange(newItems.offset, end);
        _browseItems!.items.insertAll(newItems.offset, newItems.items);

        // Roon API sometimes jumps up in the hierarchy, pop if we are not the current route
        if (_navigator.canPop() && _navigator.currentRoute != _route) {
          _navigator.popUntil(_route);
        }

        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  Future<void> _loadMore() async {
    if (_controller.position.extentAfter < 500) {
      await browseNextPage();
    }
  }

  @override
  void initState() {
    super.initState();

    _route = _navigator.currentRoute;
    MyAppState.setBrowseCallback(_route, _setBrowseItems);
    WidgetsBinding.instance.addObserver(this);

    _controller = ScrollController(
      onAttach: _handlePositionAttach,
      onDetach: _handlePositionDetach,
    )
    ..addListener(_loadMore);
  }

  @override
  void dispose() {
    MyAppState.removeBrowseCallback(_route);
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _viewChanged = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    ListView? listView;
    Widget? browseTitle;
    List<Widget> actions = [
      IconButton(
        icon: const Icon(Icons.search_outlined),
        tooltip: "Search",
        onPressed: () {
          _viewChanged = true;
          _navigator.popUntilRoot();
          _navigator.pushNamed("Search");

          showSearch(
            context: context,
            delegate: LibSearchDelegate(),
          );
        },
      ),
    ];

    if (_browseItems != null) {
      var browseList = _browseItems!.items;
      var subtitle = _browseItems!.list.subtitle;

      if (subtitle != null && subtitle.isNotEmpty) {
        var imageKey = _browseItems!.list.imageKey;
        Widget? trailing;

        if (imageKey != null) {
          trailing = _imageCache[imageKey] ?? appState.requestImage(imageKey, addToImageCache);
        }

        browseTitle = ListTile(
          title: Text(_browseItems!.list.title),
          subtitle: Text(subtitle),
          trailing: trailing,
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 32, 0),
        );

        if (appState.settings['view'] == Category.albums.index && _browseItems!.list.level == 3) {
          actions.insert(
            0,
            IconButton(
              onPressed: () {
                _navigator.pushNamed(Uri.encodeComponent(subtitle));

                searchArtist(sessionId: exploreId, artist: subtitle);
              },
              tooltip: 'More by $subtitle',
              icon: const Icon(Symbols.artist_rounded),
            )
          );
        }
      } else if (_navigator.canPop()) {
        browseTitle = Text(_browseItems!.list.title);
      } else {
        browseTitle = Text(_browseItems!.list.title.replaceFirst('My ', ''));
      }

      ListTile itemBuilder(context, index) {
        Widget? leading;
        Widget? trailing;
        String? imageKey = browseList[index].imageKey;
        Image? image = _imageCache[imageKey];
        String title = browseList[index].title;
        Text? subtitle;
        int? disk;
        int? track;

        (int, String)? leadingNumber(String input, Pattern pattern) {
          List<String> split = input.split(pattern);

          if (split.isNotEmpty && split[0] != input) {
            track = int.tryParse(split[0]);

            if (track != null) {
              return (track!, split.sublist(1).join(' '));
            }
          }

          return null;
        }

        if (browseList[index].hint == BrowseItemHint.actionList) {
          // Track from single disk: "<track>. <title>"
          (int, String)? result = leadingNumber(title, '. ');

          if (result != null) {
            track = result.$1;
            title = result.$2;
          } else {
            // Track from multi disk: "<disk>-<track> <title>"
            result = leadingNumber(title, '-');

            if (result != null) {
              disk = result.$1;
              result = leadingNumber(result.$2, ' ');

              if (result != null) {
                track = result.$1;
                title = result.$2;
              }
            }
          }
        }

        if (image != null) {
          leading = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              image,
              const Padding(padding: EdgeInsets.fromLTRB(0, 0, 10, 0)),
            ],
          );
        } else if (track != null) {
          String id = disk != null ? '$disk-$track' : track.toString();

          leading = SizedBox(
            width: 58,
            child: Text(id, style: const TextStyle(fontSize: 14)),
          );
        } else {
          if (!_isScrolling && imageKey != null) {
            appState.requestImage(imageKey, addToImageCache);
          }

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
          );
        }

        if (browseList[index].subtitle != null) {
          subtitle = Text(browseList[index].subtitle!);
        }

        return ListTile(
          leading: leading,
          trailing: trailing,
          title: Text(title),
          subtitle: subtitle,
          onTap: () {
            switch (browseList[index].hint) {
              case BrowseItemHint.action:
                break;
              case BrowseItemHint.actionList:
                appState.takeDefaultAction = true;
                break;
              default:
                String name = Uri.encodeComponent(browseList[index].title);
                _navigator.pushNamed(name);
                break;
            }

            // Delay the browse request to give the pushed route time to register its callback
            Future.delayed(const Duration(milliseconds: 20), () {
              selectBrowseItem(sessionId: exploreId, item: browseList[index]);
            });
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
          actions: actions,
        ),
        body: Card(
          margin: const EdgeInsets.all(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: listView ?? const SizedBox.expand(),
          ),
        ),
      ),
      onPopInvoked: (didPop) {
        if (didPop && !_viewChanged) {
          browseBack(sessionId: exploreId);
        }
      },
    );
  }
}

class LibSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          if (query.isNotEmpty) {
            query = '';
          } else {
            close(context, null);
            _navigator.pop();
          }
        },
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
        _navigator.pop();
      },
      icon: const BackButtonIcon(),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    browseWithInput(category: Category.search.index, sessionId: exploreId, input: query);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      close(context, null);
    });

    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}
