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
        Widget? leading;
        Widget? trailing;
        Widget? volumeSlider;

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
                onChangeEnd: (value) async {
                  var level = value.toInt();

                  await changeVolume(outputId: output.outputId, how: ChangeMode.absolute, value: level);

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
            leading = volume.isMuted!
              ? IconButton(
                icon: const Icon(Icons.volume_off_outlined),
                tooltip: 'Unmute',
                onPressed: () => mute(outputId: output.outputId, how: Mute.unmute),
              )
              : IconButton(
                icon: const Icon(Icons.volume_up_outlined),
                tooltip: 'Mute',
                onPressed: () => mute(outputId: output.outputId, how: Mute.mute),
              );
          }

          var level = _levels[output.outputId];

          if (level != null) {
            var current = level.toInt().toString();

            switch (volume.scale) {
              case Scale.number:
                  trailing = Text('$current / $max', style: const TextStyle(fontSize: 14));
                break;
              case Scale.decibel:
                  trailing = Text('$current / $max dB', style: const TextStyle(fontSize: 14));
                break;
              case Scale.incremental:
                break;
            }
          }
        }

        return ListTile(
          leading: leading,
          trailing: trailing,
          title: volumeSlider,
        );
      }

      child = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView.separated(
            controller: ScrollController(),
            padding: const EdgeInsets.all(15),
            itemBuilder: itemBuilder,
            separatorBuilder: (context, index) => const Divider(),
            itemCount: outputs.length,
            shrinkWrap: true,
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: () => muteAll(),
              icon: const Icon(Icons.volume_off_outlined),
              label: const Text('Mute All'),
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
