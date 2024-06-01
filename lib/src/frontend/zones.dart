import 'dart:convert';

import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/grouping.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Zones extends StatefulWidget {
  const Zones({
    super.key,
  });

  @override
  State<Zones> createState() => _ZonesState();
}

class _ZonesState extends State<Zones> {
  final Map<String, Image> _imageCache = {};

  void addToImageCache(ImageKeyValue keyValue) {
    if (mounted) {
      setState(() {
        _imageCache[keyValue.imageKey] = Image.memory(keyValue.image);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var zones = appState.zoneList;
    Widget? listView;

    if (zones != null) {
      ListTile itemBuilder(context, index) {
        Widget? trailing;
        Widget? playState;
        Text? metaData;

        switch (zones[index].state) {
          case PlayState.playing:
            playState = IconButton(
              icon: const Icon(Icons.pause_circle_outline),
              onPressed: () {
                controlByZoneId(zoneId: zones[index].zoneId, control: Control.pause);
              },
            );
            break;
          case PlayState.paused:
            playState = const Padding(padding: EdgeInsets.fromLTRB(40, 0, 0, 0));
            break;
          case PlayState.loading:
            playState = const Padding(padding: EdgeInsets.fromLTRB(40, 0, 0, 0));
            break;
          case PlayState.stopped:
            playState = const Padding(padding: EdgeInsets.fromLTRB(40, 0, 0, 0));
            break;
        }

        if (appState.zone != null && appState.zone!.zoneId == zones[index].zoneId) {
          trailing = MenuAnchor(
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
            menuChildren: List<MenuItemButton>.generate(
              (zones[index].outputIds.length == 1 ? 1 : 2),
              (index) => MenuItemButton(
                child: Text(index > 0 ? 'Ungroup' : 'Group...'),
                onPressed: () {
                  if (index > 0) {
                    groupOutputs(outputIds: [appState.zone!.outputs[0].outputId]);
                  } else {
                    showDialog(
                      context: context,
                      builder: (context) => const Dialog(
                        child: Grouping(),
                      ),
                    );
                  }
                },
              ),
            ),
            onClose: () {
              // Delay the onClose handling to make sure onPressed can be handled first
              Future.delayed(const Duration(milliseconds: 100), () {
              });
            },
          );
        } else {
          var imageKey = zones[index].imageKey;

          if (imageKey != null) {
            trailing = _imageCache[imageKey] ?? appState.requestImage(imageKey, addToImageCache);
          }
        }

        if (zones[index].nowPlaying != null) {
          metaData = Text(zones[index].nowPlaying!);
        }

        return ListTile(
          leading: playState,
          trailing: trailing,
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

      listView = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView.separated(
              controller: ScrollController(),
              padding: const EdgeInsets.all(15),
              itemBuilder: itemBuilder,
              separatorBuilder: (context, index) => const Divider(),
              itemCount: zones.length,
              shrinkWrap: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: () => pauseAll(),
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Pause All'),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: 600,
      child: listView,
    );
  }
}
