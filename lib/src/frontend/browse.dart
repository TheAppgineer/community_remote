import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/rust/api/roon_browse_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  dynamic pushNamed(String route, {dynamic arguments}) {
    return navigatorKey.currentState?.pushNamed(route, arguments: arguments);
  }

  dynamic pop() {
    return navigatorKey.currentState?.pop();
  }

  void popUntil(bool Function(Route<dynamic>) predicate) {
    navigatorKey.currentState?.popUntil(predicate);
  }

  bool canPop() {
    if (navigatorKey.currentState != null) {
      return navigatorKey.currentState!.canPop();
    } else {
      return false;
    }
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
      themeMode: ThemeMode.values.byName(appState.settings["theme"]),
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

class BrowseLevelState extends State<BrowseLevel> {
  static bool _viewChanged = false;
  late final ScrollController _controller;
  BrowseItems? _browseItems;
  final Map<String, Image> _imageCache = {};
  bool _isScrolling = false;

  static void onDestinationSelected(value) {
    _viewChanged = true;

    _navigator.popUntil(ModalRoute.withName('-'));

    browse(category: value, sessionId: exploreId);
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
    if (mounted) {
      if (_browseItems == null || _viewChanged) {
        _viewChanged = false;

        if (_controller.positions.isNotEmpty) {
          _controller.jumpTo(0);
        }

        setState(() {
          _browseItems = newItems;
        });
      } else if (_browseItems!.list.level == newItems.list.level && _browseItems!.items.length == newItems.offset) {
        setState(() {
          _browseItems!.items.addAll(newItems.items);
        });
      }
    }
  }

  void addToImageCache(ImageKeyValue keyValue) {
    if (mounted) {
      setState(() {
        _imageCache[keyValue.imageKey] = Image.memory(keyValue.image);
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = ScrollController(
      onAttach: _handlePositionAttach,
      onDetach: _handlePositionDetach,
    )
    ..addListener(_loadMore);
  }

  Future<void> _loadMore() async {
    if (_controller.position.extentAfter < 500) {
      await browseNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    ListView? listView;
    Widget? browseTitle;

    appState.setBrowseCallback(_setBrowseItems);

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
      } else if (_navigator.canPop()) {
        browseTitle = Text(_browseItems!.list.title);
      } else {
        browseTitle = Text(_browseItems!.list.title.replaceFirst('My ', ''));
      }

      ListTile itemBuilder(context, index) {
        Widget? leading;
        Widget? trailing;
        Image? image;
        Text? subtitle;
        var imageKey = browseList[index].imageKey;

        if (!_isScrolling && imageKey != null) {
          image = _imageCache[imageKey] ?? appState.requestImage(imageKey, addToImageCache);
        }

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
                appState.takeDefaultAction = true;
                break;
              default:
                _navigator.pushNamed(_browseItems!.list.level.toString());
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
          actions: [
            IconButton(
              icon: const Icon(Icons.search_outlined),
              tooltip: "Search",
              onPressed: () {
                _viewChanged = true;
                _navigator.popUntil(ModalRoute.withName('-'));
                _navigator.pushNamed("search");

                showSearch(
                  context: context,
                  delegate: LibSearchDelegate(),
                );
              },
            ),
          ],
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
    browseWithInput(category: 1, sessionId: exploreId, input: query);

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
