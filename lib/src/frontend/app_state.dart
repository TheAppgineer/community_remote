import 'package:community_remote/src/frontend/browse.dart';
import 'package:community_remote/src/rust/api/roon_browse_mirror.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';

const roonAccentColor = Color.fromRGBO(0x75, 0x75, 0xf3, 1.0);
const exploreId = 0;

class MyAppState extends ChangeNotifier {
  static final Map<String, Function(BrowseItems)> _browseCallbacks = {};
  static Function? _profileCallback;
  String? serverName;
  List<ZoneSummary>? zoneList;
  Map<String, String>? outputs;
  List<BrowseItem>? actionItems;
  List<QueueItem>? queue;
  bool takeDefaultAction = false;
  Zone? zone;
  late Map<String, dynamic> settings;
  Function? _progressCallback;
  Function? _queueRemainingCallback;
  final Map<String, List<Function>> _pendingImages = {};
  bool pauseOnTrackEnd = false;
  bool initialized = false;

  static setBrowseCallback(String route, Function(BrowseItems) callback) {
    _browseCallbacks[route] = callback;
  }

  static removeBrowseCallback(String route) {
    _browseCallbacks.remove(route);
  }

  static setProfileCallback(Function? callback) {
    _profileCallback = callback;
  }

  setSettings(settings) {
    this.settings = settings;
  }

  setProgressCallback(Function(int, int?)? callback) {
    _progressCallback = callback;
  }

  setQueueRemainingCallback(Function(int)? callback) {
    _queueRemainingCallback = callback;
  }

  requestImage(String? imageKey, Function callback) {
    if (imageKey != null) {
      if (_pendingImages[imageKey] == null) {
        _pendingImages[imageKey] = [callback];

        getImage(imageKey: imageKey);
      } else {
        _pendingImages[imageKey]!.add(callback);
      }
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

  incVolume() {
    if (zone != null) {
      changeZoneVolume(how: ChangeMode.relativeStep, value: 1);
    }
  }

  decVolume() {
    if (zone != null) {
      changeZoneVolume(how: ChangeMode.relativeStep, value: -1);
    }
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

      if (_queueRemainingCallback != null
        && seek.queueTimeRemaining > 0
        && zone!.nowPlaying != null
        && zone!.nowPlaying!.length != null)
      {
        _queueRemainingCallback!(seek.queueTimeRemaining);
      }

      return;
    } else if (event is RoonEvent_Image) {
      var callbacks = _pendingImages.remove(event.field0.imageKey);

      if (callbacks != null) {
        for (var callback in callbacks) {
          callback(event.field0);
        }
      }

      return;
    } else if (event is RoonEvent_BrowseItems) {
      String route = Uri.encodeComponent(event.field0.list.title);
      Function(BrowseItems)? callback = _browseCallbacks[route] ?? _browseCallbacks['-'];

      if (callback != null) {
        callback(event.field0);
      }

      return;
    } else if (event is RoonEvent_CoreFound) {
      serverName = event.field0;

      initialized = false;
      queryProfile(sessionId: exploreId);

      if (settings["zoneId"] != null) {
        selectZone(zoneId: settings["zoneId"]!);
      }
    } else if (event is RoonEvent_Profile) {
      if (_profileCallback != null) {
        _profileCallback!(event.field0);
      }

      if (!initialized) {
        initialized = true;
        BrowseLevelState.onDestinationSelected(settings["view"]);
      }
    } else if (event is RoonEvent_ZonesChanged) {
      zoneList = event.field0;
    } else if (event is RoonEvent_ZoneChanged) {
      zone = event.field0;

      if (_progressCallback != null && zone != null) {
        if (zone!.nowPlaying != null) {
          var seekPosition = zone!.nowPlaying!.seekPosition;

          if (zone!.nowPlaying!.length != null) {
            _progressCallback!(zone!.nowPlaying!.length, seekPosition);
          } else {
            _progressCallback!(0, seekPosition);
          }
        } else {
            _progressCallback!(0, null);
        }
      }

      if (_queueRemainingCallback != null
        && zone != null
        && zone!.queueTimeRemaining >= 0
        && zone!.nowPlaying != null
        && zone!.nowPlaying!.length != null)
      {
        _queueRemainingCallback!(zone!.queueTimeRemaining);
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
