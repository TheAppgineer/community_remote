import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/now_playing_dialog.dart';
import 'package:community_remote/src/frontend/queue.dart';
import 'package:community_remote/src/frontend/volume.dart';
import 'package:community_remote/src/frontend/zones.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MiniNowPlayingWidget extends StatefulWidget {
  const MiniNowPlayingWidget({
    super.key,
  });

  @override
  State<MiniNowPlayingWidget> createState() => _MiniNowPlayingWidgetState();
}

class _MiniNowPlayingWidgetState extends State<MiniNowPlayingWidget> {
  double _progress = 0;

  _setProgress(int length, int? elapsed) {
    if (mounted) {
      if (elapsed != null) {
        if (length > 0) {
          double progress = (elapsed.toDouble() / length.toDouble());
          _progress = progress;
        } else {
          _progress = 0.0;
        }
      } else {
        _progress = 0.0;
      }

      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    MyAppState.addProgressCallback(_setProgress);
  }

  @override
  void dispose() {
    MyAppState.removeProgressCallback(_setProgress);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    List<Widget> zoneControl = [];
    ListTile metadata = const ListTile(title: Text('No Zone Selected'));

    if (appState.zone != null) {
      Zone zone = appState.zone!;

      if (zone.nowPlaying != null) {
        NowPlaying nowPlaying = zone.nowPlaying!;

        metadata = ListTile(
          title: Text(nowPlaying.twoLine.line1, overflow: TextOverflow.ellipsis),
          subtitle: Text(nowPlaying.twoLine.line2, overflow: TextOverflow.ellipsis),
          contentPadding: const EdgeInsets.all(0),
          minTileHeight: 56,
          onTap: () => showDialog(
            context: context,
            builder: (context) => const Dialog.fullscreen(
              child: NowPlayingDialog(),
            ),
          ),
        );
      } else {
        metadata = const ListTile(title: Text('Go find something to play'));
      }

      zoneControl.add(IconButton(
        icon: const Icon(Icons.queue_music_outlined),
        tooltip: 'Queue',
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const Dialog.fullscreen(
            child: Queue(),
          ),
        ),
      ));

      zoneControl.add(IconButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const Dialog.fullscreen(
            child: Card(
              margin: EdgeInsets.all(10),
              child: Zones(smallWidth: true),
            ),
          ),
        ),
        icon: Icon(zone.outputs.length > 1? Icons.speaker_group_outlined: Icons.speaker_outlined),
        tooltip: zone.displayName,
      ));

      Output output = zone.outputs.elementAt(0);
      String volumeLabel = 'Volume';
      IconData volumeIcon = Icons.volume_up;

      if (output.volume != null) {
        if (output.volume!.value != null) {
          volumeLabel += ' ${output.volume!.value!.toInt().toString()}';

          if (output.volume!.scale == Scale.decibel) {
            volumeLabel += ' dB';
          }
        }

        if (output.volume!.isMuted != null && output.volume!.isMuted!) {
          volumeIcon = Icons.volume_off;
        }
      }

      zoneControl.add(IconButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const Dialog.fullscreen(
            child: Card(
              margin: EdgeInsets.all(10),
              child: VolumeDialog(smallWidth: true),
            ),
          ),
        ),
        icon: Icon(volumeIcon),
        tooltip: volumeLabel,
      ));
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: zoneControl,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 80, 0),
            child:  Column(
              children: [
                metadata,
                Row(
                  children: [
                    Expanded(flex: 1, child: LinearProgressIndicator(value: _progress)),
                    const Padding(padding: EdgeInsets.fromLTRB(0, 0, 20, 20)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
