import 'dart:convert';

import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/home_page.dart';
import 'package:community_remote/src/rust/api/roon_browse_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      themeMode: ThemeMode.values.byName(appState.settings["theme"]),
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
        appState.settings["expand"] = !appState.settings["expand"];
        saveSettings(settings: jsonEncode(appState.settings));
      } else {
        browse(category: value, sessionId: exploreId);
        appState.settings["view"] = value;
        Navigator.of(context).popUntil(ModalRoute.withName('-'));
        saveSettings(settings: jsonEncode(appState.settings));
        _controller.jumpTo(0);
      }
    }

    var home = context.findAncestorStateOfType<MyHomePageState>();
    home!.setOnDestinationSelected(onDestinationSelected);

    if (appState.browseItems != null) {
      var browseList = appState.browseItems!.items;
      var subtitle = appState.browseItems!.list.subtitle;
      var imageKey = appState.browseItems!.list.imageKey;

      if (subtitle != null && subtitle.isNotEmpty) {
        browseTitle = ListTile(
          title: Text(appState.browseItems!.list.title),
          subtitle: Text(subtitle),
          trailing: imageKey != null ? appState.getImageFromCache(imageKey) : null,
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 32, 0),
        );
      } else if (Navigator.of(context).canPop()) {
        browseTitle = Text(appState.browseItems!.list.title);
      } else {
        browseTitle = Text(appState.browseItems!.list.title.replaceFirst('My ', ''));
      }

      ListTile itemBuilder(context, index) {
        Widget? leading;
        Widget? trailing;
        Image? image = appState.getImageFromCache(browseList[index].imageKey);
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
                  if (!browseList[index].itemKey!.contains('random_')) {
                    browseBack(sessionId: exploreId);
                  }
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
                appState.takeDefaultAction = true;
                break;
              default:
                Navigator.of(context).pushNamed(appState.browseItems!.list.level.toString());
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
                Navigator.of(context).popUntil(ModalRoute.withName('-'));
                Navigator.of(context).pushNamed("search");
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
        if (didPop) {
          appState.browseItems = null;
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
            Navigator.of(context).pop();
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
        Navigator.of(context).pop();
      },
      icon: const BackButtonIcon(),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    browseWithInput(category: 1, sessionId: exploreId, input: query);
    close(context, null);
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}
