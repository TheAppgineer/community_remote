import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/frontend/home_page.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

enum ExtractType {
  album,
  artist,
}

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
  int _extractHash = 0;
  ExtractType _extractType = ExtractType.album;
  late final ScrollController _controller;

  _setProgress(int length, int? elapsed) {
    if (mounted) {
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

      setState(() {});
    }
  }

  void _setImage(ImageKeyValue keyValue) {
    if (mounted) {
      setState(() {
        _image = Image.memory(keyValue.image);
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = ScrollController();
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
    ListTile metadata = const ListTile(title: Text('No Zone Selected'));
    Function()? onNextPressed;
    Function()? onPrevPressed;
    String? tooltipNext;
    String? tooltipPrev;
    String progress = '';
    String headline = '';
    bool smallWidth = MediaQuery.sizeOf(context).width < smallScreenMaxWidth;

    if (_extractType == ExtractType.album
      && appState.wikiExtractAlbum == null
      && appState.wikiExtractArtist != null)
    {
      _extractType = ExtractType.artist;
    } else if (_extractType == ExtractType.artist
      && appState.wikiExtractAlbum != null
      && appState.wikiExtractArtist == null)
    {
      _extractType = ExtractType.album;
    }

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

        headline = _extractType == ExtractType.album
          ? "About ${nowPlaying.threeLine.line3}"
          : "About ${nowPlaying.threeLine.line2}";
        if (_length > 0) {
          if (appState.pauseOnTrackEnd || smallWidth) {
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
    }

    String? extract = _extractType == ExtractType.album
      ? appState.wikiExtractAlbum
      : appState.wikiExtractArtist;
    List<Widget> controls;
    List<Widget> nowPlaying;
    List<Widget> toggle = [
      Html(data: extract ?? ''),
    ];

    if (extract.hashCode != _extractHash) {
      _extractHash = extract.hashCode;

      if (_controller.positions.isNotEmpty) {
        _controller.jumpTo(0);
      }
    }

    if (appState.wikiExtractAlbum != null && appState.wikiExtractArtist != null) {
      IconButton switchType = _extractType == ExtractType.album
        ? IconButton(
          onPressed: () {
            setState(() {
              _extractType = ExtractType.artist;
            });
          },
          icon: const Icon(Symbols.artist_rounded),
          tooltip: "About Artist",
        )
        : IconButton(
          onPressed: () {
            setState(() {
              _extractType = ExtractType.album;
            });
          },
          icon: const Icon(Icons.album_outlined),
          tooltip: "About Album",
        );

      toggle.insert(
        0,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(flex: 1, child: Text(headline, style: Theme.of(context).textTheme.headlineSmall)),
            switchType,
            const Padding(padding: EdgeInsets.only(right: 10)),
          ],
        ),
      );
    }

    if (smallWidth) {
      toggle.insert(
        0,
        Padding(padding: const EdgeInsets.all(40), child: _image),
      );
      controls = [
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
      ];
      nowPlaying = [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              controller: _controller,
              child: Column(
                children: toggle,
              ),
            ),
          ),
        ),
        metadata,
        Row(
          children: controls,
        ),
        QuickAccessButton(appState: appState, smallWidth: true),
      ];
    } else {
      controls = [
        Expanded(child: LinearProgressIndicator(value: _progress)),
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
        const Padding(padding: EdgeInsets.only(left: 10)),
        QuickAccessButton(appState: appState, smallWidth: false),
      ];

      nowPlaying = [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: SizedBox(child: _image)),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SingleChildScrollView(
                      controller: _controller,
                      child: Column(
                        children: toggle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(padding: EdgeInsets.only(top: 20)),
        metadata,
        Row(
          children: controls,
        ),
      ];
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: nowPlaying,
          ),
        ),
      ),
    );
  }
}
