import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Queue extends StatelessWidget {
  const Queue({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    ListView? listView;

    if (appState.queue != null) {
      List<QueueItem> queue = appState.queue!;

      ListTile itemBuilder(context, index) {
        Widget? leading;
        Image? image = getImageFromCache(queue[index].imageKey, appState.imageCache);

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
          onTap: () {
            selectQueueItem(queueItemId: queue[index].queueItemId);
          },
        );
      }

      listView = ListView.separated(
        padding: const EdgeInsets.all(10),
        itemBuilder: itemBuilder,
        separatorBuilder: (context, index) => const Divider(),
        itemCount: appState.queue!.length,
      );
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: listView,
      ),
    );
  }
}
