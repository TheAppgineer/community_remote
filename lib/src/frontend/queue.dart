import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Queue extends StatefulWidget {
  const Queue({
    super.key,
  });

  @override
  State<Queue> createState() => _QueueState();
}

class _QueueState extends State<Queue> {
  List<int> stops = [];
  final Map<String, Image> _imageCache = {};
  int _remaining = 0;

  void addToImageCache(ImageKeyValue keyValue) {
    if (mounted) {
      setState(() {
        _imageCache[keyValue.imageKey] = Image.memory(keyValue.image);
      });
    }
  }

  setQueueRemaining(int remaining) {
    if (mounted) {
      setState(() {
        _remaining = remaining;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    Widget? widget;

    Widget getListView(bool smallWidth) {
      double dynPadding = smallWidth ? 0 : 10;
      List<QueueItem> queue = appState.queue!;

      ListTile itemBuilder(context, index) {
        Widget? leading;
        Image? image;
        var imageKey = queue[index].imageKey;

        if (imageKey != null) {
          image = _imageCache[imageKey] ?? appState.requestImage(imageKey, addToImageCache);
        }

        leading = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 48, child: image),
            Padding(padding: EdgeInsets.fromLTRB(0, 0, dynPadding, 0)),
          ],
        );

        return ListTile(
          leading: leading,
          title: Text(
            queue[index].twoLine.line1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: smallWidth ? 15 : 16)
          ),
          subtitle: Text(
            queue[index].twoLine.line2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: smallWidth ? 15 : 16)
          ),
          trailing: Text(appState.getDuration(queue[index].length), style: const TextStyle(fontSize: 14)),
          contentPadding: const EdgeInsets.only(left: 10),
          onTap: () {
            selectQueueItem(queueItemId: queue[index].queueItemId);
          },
          onLongPress: () {
            if (index < queue.length - 1) {
              setState(() {
                if (stops.contains(queue[index].queueItemId)) {
                  stops.remove(queue[index].queueItemId);
                } else {
                  stops.add(queue[index].queueItemId);
                }
              });

              pauseAfterQueueItems(queueItemIds: stops);
            }
          },
        );
      }

      return ListView.separated(
        padding: EdgeInsets.all(dynPadding),
        itemBuilder: itemBuilder,
        separatorBuilder: (_, index) => Divider(
          color: index < queue.length - 1 && stops.contains(queue[index].queueItemId)
            ? Theme.of(context).colorScheme.primary
            : null,
        ),
        itemCount: queue.length,
        scrollDirection: Axis.vertical,
        shrinkWrap: true,
      );
    }

    appState.setQueueRemainingCallback(setQueueRemaining);

    if (appState.zone != null && appState.queue != null && appState.queue!.isNotEmpty) {
      widget = Column(
        children: [
          ListTile(
            title: const Text('Queue', style: TextStyle(fontSize: 20)),
            trailing: _remaining > 0
              ? Text(appState.getDuration(_remaining), style: const TextStyle(fontSize: 14))
              : null,
          ),
          Expanded(child: LayoutBuilder(
            builder: (context, constraints) {
              bool smallWidth = (constraints.maxWidth < smallWindowMaxWidth);

              return getListView(smallWidth);
            },
          )),
        ],
      );
    } else {
      widget = const ListTile(
        title: Text('Queue'),
        subtitle: Text('Use the Browser to add tracks'),
      );
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: widget,
    );
  }
}
