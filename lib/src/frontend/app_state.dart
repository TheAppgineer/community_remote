import 'package:community_remote/src/frontend/browse.dart';
import 'package:community_remote/src/rust/api/roon_browse_mirror.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';

const roonAccentColor = Color.fromRGBO(0x75, 0x75, 0xf3, 1.0);
const exploreId = 0;

class MyAppState extends ChangeNotifier {
  String? serverName;
  List<ZoneSummary>? zoneList;
  Map<String, String>? outputs;
  BrowseItems? browseItems;
  List<BrowseItem>? actionItems;
  List<QueueItem>? queue;
  bool takeDefaultAction = false;
  Zone? zone;
  late Map<String, dynamic> settings;
  Function? _progressCallback;
  Function? _browseCallback;
  final Map<String, Function> _pendingImages = {};
  bool pauseOnTrackEnd = false;

  setSettings(settings) {
    this.settings = settings;
  }

  setProgressCallback(Function(int, int?)? callback) {
    _progressCallback = callback;
  }

  setBrowseCallback(Function(BrowseItems)? callback) {
    _browseCallback = callback;
  }

  requestImage(String? imageKey, Function callback) {
    if (imageKey != null) {
      getImage(imageKey: imageKey, width: 100, height: 100);

      _pendingImages[imageKey] = callback;
    }
  }

  String getDuration(int length) {
    int hours = length ~/ 3600;
    String minutes = ((length % 3600) ~/ 60).toString();
    String seconds = (length % 60).toString().padLeft(2, '0');
    String duration;

    if (hours > 0) {
      duration = '$hours:${minutes.padLeft(2, '0')}:$seconds';
    } else {
      duration = '$minutes:$seconds';
    }

    return duration;
  }

  void cb(event) {
    if (event is RoonEvent_ZoneSeek) {
      ZoneSeek seek = event.field0;

      if (_progressCallback != null) {
        if (zone!.nowPlaying != null && zone!.nowPlaying!.length != null) {
          _progressCallback!(zone!.nowPlaying!.length, seek.seekPosition);
        } else if (seek.seekPosition != null) {
          _progressCallback!(0, seek.seekPosition);
        }
      }

      return;
    } else if (event is RoonEvent_Image) {
      var callback = _pendingImages.remove(event.field0.imageKey);

      if (callback != null) {
        callback(event.field0);
      }

      return;
    } else if (event is RoonEvent_BrowseItems) {
      if (_browseCallback != null) {
        _browseCallback!(event.field0);
      }

      return;
    } else if (event is RoonEvent_CoreFound) {
      serverName = event.field0;

      browse(category: settings["view"], sessionId: exploreId);

      if (settings["zoneId"] != null) {
        selectZone(zoneId: settings["zoneId"]!);
      }
    } else if (event is RoonEvent_ZonesChanged) {
      zoneList = event.field0;
    } else if (event is RoonEvent_ZoneChanged) {
      zone = event.field0;

      if (_progressCallback != null && zone != null) {
        if (zone!.nowPlaying == null || zone!.nowPlaying!.length == null) {
          _progressCallback!(0, null);
        } else {
          _progressCallback!(zone!.nowPlaying!.length!, 0);
        }
      }
    } else if (event is RoonEvent_OutputsChanged) {
      outputs = event.field0;
    } else if (event is RoonEvent_BrowseActions) {
      actionItems = event.field0;

      if (actionItems != null && takeDefaultAction) {
        // Take first as default action, at least for now
        selectBrowseItem(sessionId: exploreId, item: actionItems![2]);
        takeDefaultAction = false;
      }
    } else if (event is RoonEvent_BrowseReset) {
      BrowseLevelState.onDestinationSelected(settings["view"]);
    } else if (event is RoonEvent_QueueItems) {
      queue = event.field0;
    } else if (event is RoonEvent_PauseOnTrackEnd) {
      pauseOnTrackEnd = event.field0;
    }

    notifyListeners();
  }
}
