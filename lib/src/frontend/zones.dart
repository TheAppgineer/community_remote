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
    required this.smallWidth,
  });

  final bool smallWidth;

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
        TextStyle? style = const TextStyle(fontWeight: FontWeight.normal);

        if (appState.zone != null && zones[index].zoneId == appState.zone!.zoneId) {
          style = TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary);
        }

        if (zones[index].state == PlayState.playing) {
          playState = IconButton(
            icon: const SizedBox(width: 48, child: Icon(Icons.pause_circle_outline, size: 24)),
            onPressed: () {
              controlByZoneId(zoneId: zones[index].zoneId, control: Control.pause);
            },
          );
        } else {
          playState = const SizedBox(width: 64);
        }


        if (appState.zone != null) {
          List<MenuItemButton>? menuChildren;

          if (appState.zone!.zoneId == zones[index].zoneId) {
            menuChildren = List<MenuItemButton>.generate(
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
            );
          } else {
            menuChildren = List<MenuItemButton>.generate(
              1,
              (index) => MenuItemButton(
                child: Text('Transfer Queue to ${appState.zone!.displayName}'),
                onPressed: () {
                  transferFromZone(zoneId: zones[index].zoneId);
                },
              ),
            );
          }

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
            menuChildren: menuChildren,
            onClose: () {
              // Delay the onClose handling to make sure onPressed can be handled first
              Future.delayed(const Duration(milliseconds: 100), () {
              });
            },
          );
        }

        if (zones[index].nowPlaying != null) {
          metaData = Text(zones[index].nowPlaying!, style: style);
        }

        return ListTile(
          contentPadding: widget.smallWidth ? EdgeInsets.zero : null,
          leading: playState,
          trailing: trailing,
          title: Text(zones[index].displayName, style: style),
          subtitle: metaData,
          focusColor: Colors.transparent,
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
              padding: EdgeInsets.all(widget.smallWidth ? 0 : 10),
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
