import 'dart:convert';

import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Zones extends StatelessWidget {
  const Zones({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var zones = appState.zoneList;
    Widget? listView;

    if (zones != null) {
      ListTile itemBuilder(context, index) {
        var imageKey = zones[index].imageKey;
        Image? image = appState.getImageFromCache(imageKey);
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

      listView = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView.separated(
            controller: ScrollController(),
            padding: const EdgeInsets.all(15),
            itemBuilder: itemBuilder,
            separatorBuilder: (context, index) => const Divider(),
            itemCount: zones.length,
            shrinkWrap: true,
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
