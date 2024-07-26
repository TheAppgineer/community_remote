import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/volume.dart';
import 'package:community_remote/src/frontend/zones.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NowPlayingWidget extends StatefulWidget {
  const NowPlayingWidget({
    super.key,
  });

  @override
  State<NowPlayingWidget> createState() => _NowPlayingWidgetState();
}

class _NowPlayingWidgetState extends State<NowPlayingWidget> {
  int _length = 0;
  int _elapsed = 0;
  double _progress = 0;
  final Map<String, Image> _imageCache = {};

  setProgress(int length, int? elapsed) {
    setState(() {
      if (elapsed != null) {
        _length = length;
        _elapsed = elapsed;

        if (length > 0) {
          double progress = (elapsed.toDouble() / length.toDouble());
          _progress = progress;
        } else {
          _progress = 0.0;
        }
      } else {
        _length = 0;
        _elapsed = 0;
        _progress = 0.0;
      }
    });
  }

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
    List<Widget> zoneControl = [];
    ListTile metadata = const ListTile(title: Text('No Zone Selected'));
    Function()? onNextPressed;
    Function()? onPrevPressed;
    String? tooltipNext;
    String? tooltipPrev;
    String progress = '';

    appState.setProgressCallback(setProgress);

    if (appState.zone != null) {
      Zone zone = appState.zone!;

      if (zone.nowPlaying != null) {
        NowPlaying nowPlaying = zone.nowPlaying!;
        Widget? leading;
        Image? image;
        var imageKey = nowPlaying.imageKey;

        if (imageKey != null) {
          image = _imageCache[imageKey] ?? appState.requestImage(imageKey, addToImageCache);
        }

        if (image != null) {
          leading = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 48, child: image),
              const Padding(padding: EdgeInsets.fromLTRB(0, 0, 10, 0)),
            ],
          );
        } else {
          leading = const Padding(padding: EdgeInsets.fromLTRB(58, 0, 0, 0));
        }

        metadata = ListTile(
          titleAlignment: ListTileTitleAlignment.center,
          leading: leading,
          title: Text(nowPlaying.threeLine.line1),
          subtitle: Text('${nowPlaying.threeLine.line2}\n${nowPlaying.threeLine.line3}'),
          isThreeLine: true,
        );

        if (_length > 0) {
          if (appState.pauseOnTrackEnd) {
            progress = appState.getDuration(_length - _elapsed);
          } else {
            progress = '${appState.getDuration(_elapsed)} / ${appState.getDuration(_length)}';
          }
        } else {
          progress = appState.getDuration(_elapsed);
        }
      } else {
        metadata = const ListTile(title: Text('Go find something to play'));
      }

      if (zone.isNextAllowed) {
        tooltipNext = 'Next Track';
        onNextPressed = () {
          control(control: Control.next);
        };
      } else if (appState.queue != null && appState.queue!.isNotEmpty) {
        tooltipNext = 'Play from Queue';
        onNextPressed = () {
          selectQueueItem(queueItemId: appState.queue![0].queueItemId);
        };
      }

      if (zone.isPreviousAllowed) {
        tooltipPrev = 'Previous Track';
        onPrevPressed = () {
          control(control: Control.previous);
        };
      }

      zoneControl.add(ElevatedButton.icon(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const Dialog(
            child: Zones(smallWidth: false),
          ),
        ),
        icon: Icon(zone.outputs.length > 1? Icons.speaker_group_outlined: Icons.speaker_outlined),
        label: Text(zone.displayName),
      ));

      zoneControl.add(const Padding(padding: EdgeInsets.only(left: 10)));

      Output output = zone.outputs.elementAt(0);
      String volumeLabel = 'Volume';
      IconData volumeIcon = Icons.volume_up;

      if (output.volume != null) {
        if (output.volume!.value != null) {
          volumeLabel = output.volume!.value!.toInt().toString();

          if (output.volume!.scale == Scale.decibel) {
            volumeLabel += ' dB';
          }
        }

        if (output.volume!.isMuted != null && output.volume!.isMuted!) {
          volumeIcon = Icons.volume_off;
        }
      }

      zoneControl.add(ElevatedButton.icon(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const Dialog(
            child: VolumeDialog(smallWidth: false),
          ),
        ),
        icon: Icon(volumeIcon),
        label: Text(volumeLabel),
      ));
    }

    zoneControl.insert(0, Expanded(
      flex: 1,
      child: metadata,
    ));

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: zoneControl,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 80, 0),
              child:  Row(
                children: [
                  Expanded(flex: 1, child: LinearProgressIndicator(value: _progress)),
                  const Padding(padding: EdgeInsets.only(left: 10)),
                  Text(progress),
                  const Padding(padding: EdgeInsets.only(left: 20)),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 32),
                    tooltip: tooltipPrev,
                    onPressed: onPrevPressed,
                  ),
                  const Padding(padding: EdgeInsets.only(left: 10)),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 32),
                    tooltip: tooltipNext,
                    onPressed: onNextPressed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
