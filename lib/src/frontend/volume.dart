import 'package:community_remote/src/frontend/app_state.dart';
import 'package:community_remote/src/rust/api/roon_transport_mirror.dart';
import 'package:community_remote/src/rust/api/simple.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VolumeDialog extends StatefulWidget {
  const VolumeDialog({
    super.key,
  });

  @override
  State<VolumeDialog> createState() => _VolumeDialogState();
}

class _VolumeDialogState extends State<VolumeDialog> {
  final Map<String, double> _levels = {};
  final Map<String, bool> _changing = {};

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    Widget? child;

    if (appState.zone != null) {
      var outputs = appState.zone!.outputs;

      ListTile itemBuilder(context, index) {
        Output output = outputs[index];
        List<Widget> subtitle = [];
        Widget? volumeSlider;

        if (output.sourceControls != null) {
          for (var control in output.sourceControls!) {
            if (control.supportsStandby && control.status != Status.standby) {
              subtitle.add(
                IconButton(
                  icon: const Icon(Icons.power_settings_new_outlined),
                  tooltip: 'Enter Standby',
                  onPressed: () => standby(outputId: output.outputId),
                )
              );
              break;
            }
          }
        }

        if (subtitle.isEmpty) {
          subtitle.add(const Padding(padding: EdgeInsets.fromLTRB(40, 0, 0, 0)));
        }

        if (output.volume != null) {
          var volume = output.volume!;
          var min = volume.hardLimitMin;
          var max = volume.softLimit;

          if (volume.value != null) {
            _changing[output.outputId] ??= false;

            if (!_changing[output.outputId]!) {
              _levels[output.outputId] = volume.value!;
            }

            volumeSlider = SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                min: min,
                max: max,
                value: _levels[output.outputId]!,
                onChanged: (value) {
                  setState(() {
                    _levels[output.outputId] = value;
                  });
                },
                onChangeStart: (value) {
                  _changing[output.outputId] = true;
                },
                onChangeEnd: (value) {
                  var level = value.toInt();

                  changeVolume(outputId: output.outputId, how: ChangeMode.absolute, value: level);

                  _changing[output.outputId] = false;
                },
              ),
            );
          } else {
            volumeSlider = const LinearProgressIndicator(
              value: 0,
            );
          }

          if (volume.isMuted != null) {
            subtitle.add(volume.isMuted!
              ? IconButton(
                icon: const Icon(Icons.volume_off),
                onPressed: () => mute(outputId: output.outputId, how: Mute.unmute),
              )
              : IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () => mute(outputId: output.outputId, how: Mute.mute),
              )
            );
            subtitle.add(const Padding(padding: EdgeInsets.only(left: 15)));
          }

          var level = _levels[output.outputId];

          if (level != null) {
            var levelInt = level.toInt();
            var maxInt = max.toInt();

            switch (volume.scale) {
              case Scale.number:
                  subtitle.add(Text('$levelInt / $maxInt', style: const TextStyle(fontSize: 15)));
                break;
              case Scale.decibel:
                  subtitle.add(Text('$levelInt / $maxInt dB', style: const TextStyle(fontSize: 15)));
                break;
              case Scale.incremental:
                break;
            }

            subtitle.add(Expanded(child: volumeSlider));
            subtitle.add(IconButton(
              onPressed: () => changeVolume(outputId: output.outputId, how: ChangeMode.relativeStep, value: -1),
              icon: const Icon(Icons.remove),
            ));
            subtitle.add(IconButton(
              onPressed: () => changeVolume(outputId: output.outputId, how: ChangeMode.relativeStep, value: 1),
              icon: const Icon(Icons.add),
            ));
          }
        } else {
          subtitle.add(const Text('Volume control is fixed'));
        }

        return ListTile(
          title: Text(outputs[index].displayName),
          subtitle: Row(
            children: subtitle,
          ),
        );
      }

      List<Widget> buttonRow = [];
      int volumeCount = 0;

      for (var output in outputs) {
        if (output.volume != null && output.volume!.value != null) {
          volumeCount++;
        }
      }

      if (volumeCount > 1) {
        buttonRow = [
          ElevatedButton.icon(
            onPressed: () => muteZone(),
            icon: const Icon(Icons.volume_off),
            label: const Text('Mute All'),
          ),
          const Padding(padding: EdgeInsets.only(left: 10)),
          IconButton(
            onPressed: () => changeZoneVolume(how: ChangeMode.relativeStep, value: -1),
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            onPressed: () => changeZoneVolume(how: ChangeMode.relativeStep, value: 1),
            icon: const Icon(Icons.add),
          ),
        ];
      }

      child = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView.builder(
              controller: ScrollController(),
              padding: const EdgeInsets.all(6),
              itemBuilder: itemBuilder,
              itemCount: outputs.length,
              shrinkWrap: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 30, 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: buttonRow,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: 600,
      child: child,
    );
  }
}
