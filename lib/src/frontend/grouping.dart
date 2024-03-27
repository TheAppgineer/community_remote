import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Grouping extends StatefulWidget {
  const Grouping({
    super.key,
  });

  @override
  State<Grouping> createState() => _GroupingState();
}

class _GroupingState extends State<Grouping> {
  List<String> _grouping = [];

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    Widget? listView;

    setGrouping() {
      var zoneList = appState.zoneList!;
      var zone = appState.zone!;

      for (var summary in zoneList) {
        if (summary.zoneId == zone.zoneId) {
          _grouping = List<String>.from(summary.outputIds);
          break;
        }
      }
    }

    if (appState.zone != null && appState.outputs != null) {
      var zone = appState.zone!;
      var primOutput = zone.outputs.elementAt(0);
      var outputIds = primOutput.canGroupWithOutputIds;

      outputIds.remove(primOutput.outputId);

      if (_grouping.isEmpty) {
        setGrouping();
      }

      ListTile itemBuilder(context, index) {
        return ListTile(
          leading: Checkbox(
            value: _grouping.contains(outputIds[index]),
            onChanged: (value) {
              if (value != null) {
                if (value) {
                  if (!_grouping.contains(outputIds[index])) {
                    setState(() {
                      _grouping.add(outputIds[index]);
                    });
                  }
                } else {
                  setState(() {
                    _grouping.remove(outputIds[index]);
                  });
                }
              }
            },
          ),
          title: Text(appState.outputs![outputIds[index]]!),
          onTap: () {
            if (_grouping.contains(outputIds[index])) {
              setState(() {
                _grouping.remove(outputIds[index]);
              });
            } else {
              setState(() {
                _grouping.add(outputIds[index]);
              });
            }
          },
        );
      }

      listView = Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Group ${primOutput.displayName} with:', style: const TextStyle(fontSize: 20),),
            ),
            ListView.separated(
              padding: const EdgeInsets.all(10),
              itemBuilder: itemBuilder,
              separatorBuilder: (context, index) => const Divider(),
              itemCount: outputIds.length,
              shrinkWrap: true,
            ),
            const Padding(padding: EdgeInsets.only(top: 10)),
            ElevatedButton.icon(
              onPressed: () {
                groupOutputs(outputIds: _grouping);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.speaker_group_outlined),
              label: const Text('Group Zones'),
            ),
          ],
        ),
      );
    }

    return PopScope(
      child: SizedBox(
        width: 600,
        child: listView,
      ),
      onPopInvoked: (didPop) {
        if (didPop) {
          setGrouping();
        }
      },
    );
  }
}
