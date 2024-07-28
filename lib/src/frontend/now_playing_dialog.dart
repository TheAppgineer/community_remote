import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/home_page.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NowPlayingDialog extends StatefulWidget {
  const NowPlayingDialog({super.key});

  @override
  State<NowPlayingDialog> createState() => _NowPlayingDialogState();
}

class _NowPlayingDialogState extends State<NowPlayingDialog> {
  int _length = 0;
  int _elapsed = 0;
  double _progress = 0;
  String? _imageKey;
  Image? _image;

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

  void _setImage(ImageKeyValue keyValue) {
    if (mounted) {
      setState(() {
        _image = Image.memory(keyValue.image);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
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

        if (_imageKey != nowPlaying.imageKey) {
          if (nowPlaying.imageKey != null) {
            _imageKey = nowPlaying.imageKey;
            appState.requestImage(_imageKey, _setImage);
          } else {
            _image = null;
          }
        }

        metadata = ListTile(
          title: Text(nowPlaying.threeLine.line1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${nowPlaying.threeLine.line2}\n${nowPlaying.threeLine.line3}', overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          contentPadding: const EdgeInsets.all(0),
          minTileHeight: 72,
        );

        if (_length > 0) {
          progress = appState.getDuration(_length - _elapsed);
        } else {
          progress = appState.getDuration(_elapsed);
        }
      } else {
        metadata = const ListTile(title: Text('Go find something to play'));
      }
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    Expanded(child: SizedBox(child: _image)),
                    metadata,
                    Row(
                      children: [
                        Expanded(child: LinearProgressIndicator(value: _progress)),
                        const Padding(padding: EdgeInsets.only(left: 10)),
                        Text(progress),
                        IconButton(
                          icon: const Icon(Icons.skip_previous, size: 32),
                          tooltip: tooltipPrev,
                          onPressed: onPrevPressed,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, size: 32),
                          tooltip: tooltipNext,
                          onPressed: onNextPressed,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            QuickAccessButton(appState: appState, smallWidth: true),
          ],
        ),
      ),
    );
  }
}
