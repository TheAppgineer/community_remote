import 'dart:typed_data';

import 'package:community_remote/src/rust/api/roon_browse_mirror.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';

const roonAccentColor = Color.fromRGBO(0x75, 0x75, 0xf3, 1.0);
const exploreId = 0;

class MyAppState extends ChangeNotifier {
  String? serverName;
  List<ZoneSummary>? zoneList;
  BrowseItems? browseItems;
  List<BrowseItem>? actionItems;
  List<QueueItem>? queue;
  bool takeDefaultAction = false;
  Zone? zone;
  Map<String, Uint8List> imageCache = {};
  late Map<String, dynamic> settings;

  setSettings(settings) {
    this.settings = settings;
  }

  void cb(event) {
    if (event is RoonEvent_CoreFound) {
      serverName = event.field0;

      browse(category: settings["view"], sessionId: exploreId);

      if (settings["zoneId"] != null) {
        selectZone(zoneId: settings["zoneId"]!);
      }
    } else if (event is RoonEvent_ZonesChanged) {
      zoneList = event.field0;
    } else if (event is RoonEvent_ZoneChanged) {
      zone = event.field0;
    } else if (event is RoonEvent_BrowseItems) {
      if (browseItems == null || event.field0.offset == 0) {
        browseItems = event.field0;
      } else {
        browseItems!.items.addAll(event.field0.items);
      }
    } else if (event is RoonEvent_BrowseActions) {
      actionItems = event.field0;

      if (actionItems != null && takeDefaultAction) {
        // Take first as default action, at least for now
        selectBrowseItem(sessionId: exploreId, item: actionItems![2]);
        takeDefaultAction = false;
      }
    } else if (event is RoonEvent_BrowseReset) {
      browse(category: settings["view"], sessionId: exploreId);
    } else if (event is RoonEvent_QueueItems) {
      queue = event.field0;
    } else if (event is RoonEvent_Image) {
      imageCache[event.field0.imageKey] = event.field0.image;
    }

    notifyListeners();
  }
}

Image? getImageFromCache(String? imageKey, Map<String, Uint8List> imageCache) {
  Image? image;

  if (imageKey != null) {
    var byteList = imageCache[imageKey];

    if (byteList != null) {
      image = Image.memory(byteList);
    } else {
      getImage(imageKey: imageKey, width: 100, height: 100);
    }
  }

  return image;
}
