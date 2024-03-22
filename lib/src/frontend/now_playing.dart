import 'package:community_remote/src/frontend/app_state.dart';
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

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    ListTile metadata = const ListTile(title: Text('Go find something to play'));
    Widget prev = const Icon(Icons.skip_previous, size: 32);
    Widget next = const Icon(Icons.skip_next, size: 32);
    String progress = '';

    appState.setProgressCallback(setProgress);

    if (appState.zone != null) {
      if (appState.zone!.nowPlaying != null) {
        NowPlaying nowPlaying = appState.zone!.nowPlaying!;
        Widget? leading;
        Image? image = appState.getImageFromCache(nowPlaying.imageKey);

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
      }

      Function()? onNextPressed;

      if (appState.zone!.isNextAllowed) {
        onNextPressed = () {
          control(control: Control.next);
        };
      } else if (appState.queue != null && appState.queue!.isNotEmpty) {
        onNextPressed = () {
          selectQueueItem(queueItemId: appState.queue![0].queueItemId);
        };
      }

      prev = IconButton(
        icon: prev,
        tooltip: appState.zone!.isPreviousAllowed ? 'Previous Track' : null,
        onPressed: appState.zone!.isPreviousAllowed ? () {
          control(control: Control.previous);
        } : null,
      );
      next = IconButton(
        icon: next,
        tooltip: onNextPressed != null
          ? (appState.zone!.isNextAllowed ? 'Next Track' : 'Play from Queue')
          : null,
        onPressed: onNextPressed,
      );
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: metadata,
                ),
                ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => const Dialog(
                      child: Zones(),
                    ),
                  ),
                  icon: const Icon(Icons.speaker_outlined),
                  label: const Text('Zones'),
                ),
                const Padding(padding: EdgeInsets.only(left: 10)),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Volume'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 80, 0),
              child:  Row(
                children: [
                  Expanded(flex: 1, child: LinearProgressIndicator(value: _progress)),
                  const Padding(padding: EdgeInsets.only(left: 10)),
                  Text(progress),
                  const Padding(padding: EdgeInsets.only(left: 20)),
                  prev,
                  const Padding(padding: EdgeInsets.only(left: 10)),
                  next,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
