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

    appState.setQueueRemainingCallback(setQueueRemaining);

    if (appState.zone != null && appState.queue != null && appState.queue!.isNotEmpty) {
      List<QueueItem> queue = appState.queue!;

      ListTile itemBuilder(context, index) {
        Widget? leading;
        Image? image;
        var imageKey = queue[index].imageKey;

        if (imageKey != null) {
          image = _imageCache[imageKey] ?? appState.requestImage(imageKey, addToImageCache);
        }

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

        return ListTile(
          leading: leading,
          title: Text(queue[index].twoLine.line1),
          subtitle: Text(queue[index].twoLine.line2),
          trailing: Text(appState.getDuration(queue[index].length), style: const TextStyle(fontSize: 14)),
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

      ListView listView = ListView.separated(
        padding: const EdgeInsets.all(10),
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

      widget = Column(
        children: [
          ListTile(
            title: const Text('Queue', style: TextStyle(fontSize: 20)),
            trailing: _remaining > 0
              ? Text(appState.getDuration(_remaining), style: const TextStyle(fontSize: 14))
              : null,
          ),
          Expanded(child: listView),
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
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: widget,
      ),
    );
  }
}
