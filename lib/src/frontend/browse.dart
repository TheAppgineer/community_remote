import 'dart:convert';

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
  kkbox,
  qobuz,
  tidal,
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
  static bool _toProfile = false;
  static int _category = 0;
  late final ScrollController _controller;
  late String _route;
  BrowseItems? _browseItems;
  final Map<String, Image> _imageCache = {};
  bool _isScrolling = false;

  static void onDestinationSelected(int category) {
    _viewChanged = true;

    _navigator.popUntilRoot();
    _category = category;

    browse(category: category);
  }

  static void selectProfile() {
    if (_navigator.currentRoute != 'Profile') {
      _viewChanged = true;
      _toProfile = true;

      browse(category: Category.settings.index);
    }
  }

  void _addToImageCache(ImageKeyValue keyValue) {
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

  void _setBrowseItems(BrowseItems? newItems) {
    if (newItems == null) {
      _navigator.popUntilRoot();
      _browseItems = null;
    } else if (_browseItems == null || _viewChanged) {
      if (_controller.positions.isNotEmpty) {
        _controller.jumpTo(0);
      }

      if (_toProfile) {
        if ((_browseItems == null || _browseItems!.list.title != "Profile")
          && newItems.list.title == 'Settings')
        {
          _navigator.popUntilRoot();

          for (var item in newItems.items) {
            if (item.title == "Profile") {
              _navigator.pushNamed(item.title);

              // Delay the browse request to give the pushed route time to register its callback
              Future.delayed(const Duration(milliseconds: 20), () {
                selectBrowseItem(item: item);
              });
              break;
            }
          }
        } else {
          _toProfile = false;
          _viewChanged = false;
          return;
        }
      }

      _viewChanged = false;
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

    Widget getListView(bool smallWidth) {
      double dynPadding = smallWidth ? 0 : 10;

      if (_browseItems != null) {
        var browseList = _browseItems!.items;

        ListTile itemBuilder(context, index) {
          Widget? leading;
          Widget? trailing;
          String? imageKeyTitle = browseList[index].title.contains('Play ') ? _browseItems!.list.imageKey : null;
          String? imageKey = browseList[index].imageKey ?? (index == 0 ? imageKeyTitle : null);
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
            leading = SizedBox(width: 48, child: image);
          } else if (track != null) {
            String id = disk != null ? '$disk-$track' : track.toString();

            leading = SizedBox(
              width: 48,
              child: Text(id, style: const TextStyle(fontSize: 14)),
            );
          } else {
            if (!_isScrolling && imageKey != null) {
              appState.requestThumbnail(imageKey, _addToImageCache);
            }

            leading = const SizedBox(width: 48);
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
                      selectBrowseItem(item: browseList[index]);
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
                    selectBrowseItem(item: appState.actionItems![index]);
                    appState.actionItems = null;
                  },
                ),
              ),
            );
          }

          if (browseList[index].subtitle != null) {
            subtitle = Text(
              browseList[index].subtitle!,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: smallWidth ? 13 : 14)
            );
          }

          return ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading,
                Padding(padding: EdgeInsets.fromLTRB(0, 0, dynPadding, 0)),
              ],
            ),
            trailing: trailing,
            title: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: smallWidth ? 15 : 16)),
            subtitle: subtitle,
            contentPadding: const EdgeInsets.only(left: 10),
            focusColor: Colors.transparent,
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
                selectBrowseItem(item: browseList[index]);
              });
            },
          );
        }

        return ListView.separated(
          controller: _controller,
          padding: EdgeInsets.all(dynPadding),
          itemBuilder: itemBuilder,
          separatorBuilder: (context, index) => const Divider(),
          itemCount: browseList.length,
        );
      }

      return const SizedBox.expand();
    }

    if (_toProfile) {
      _toProfile = false;
      appState.settings['view'] = Category.settings.index;
      saveSettings(settings: jsonEncode(appState.settings));
    }

    if (_browseItems != null) {
      var subtitle = _browseItems!.list.subtitle;

      if (subtitle != null && subtitle.isNotEmpty) {
        browseTitle = ListTile(
          title: Text(_browseItems!.list.title, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
          contentPadding: const EdgeInsets.all(0),
        );

        if (appState.settings['view'] == Category.albums.index && _browseItems!.list.level == 3) {
          actions.insert(
            0,
            IconButton(
              onPressed: () {
                _navigator.pushNamed(Uri.encodeComponent(subtitle));

                searchArtist(artist: subtitle);
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
    }

    return PopScope(
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          title: browseTitle,
          actions: actions,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            bool smallWidth = (constraints.maxWidth < smallWindowMaxWidth);

            return Card(
              margin: const EdgeInsets.all(10),
              child: getListView(smallWidth),
            );
          },
        ),
      ),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_viewChanged) {
          _navigator.routes.removeLast();

          if (!_navigator.canPop() && _browseItems?.list.title == "Search") {
            // Refresh selected category when leaving Search
            _viewChanged = true;
            browse(category: _category);
          } else {
            browseBack();
          }
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
    browseWithInput(category: Category.search.index, input: query);

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
