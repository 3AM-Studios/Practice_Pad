import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For Slider, Icons
import 'package:practice_pad/features/practice/models/circle_of_fifths_keys.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/circle_of_fifths_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/widgets/circle_painter.dart';
import 'package:practice_pad/models/practice_item.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

class CircleOfFifthsScreen extends StatelessWidget {
  final PracticeItem practiceItem;
  final int numberOfCycles;

  const CircleOfFifthsScreen({
    super.key,
    required this.practiceItem,
    required this.numberOfCycles,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CircleOfFifthsViewModel(
        practiceItem: practiceItem,
        numberOfCycles: numberOfCycles,
      ),
      child: Consumer<CircleOfFifthsViewModel>(
        builder: (context, viewModel, child) {
          return WillPopScope(
            onWillPop: () async {
              // Return the number of cycles completed in this session when swiping back
              Navigator.of(context).pop(viewModel.cyclesCompletedThisSession);
              return true; // Allow pop
            },
            child: CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                middle: Text('Circle of Fifths: ${practiceItem.name}'),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text("Done",
                      style: TextStyle(color: CupertinoColors.systemRed)),
                  onPressed: () {
                    Navigator.of(context)
                        .pop(viewModel.cyclesCompletedThisSession);
                  },
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Placeholder for Interactive Circle of Fifths UI
                    Expanded(
                      flex: 3,
                      child: _buildInteractiveCircle(context, viewModel),
                    ),
                    // Settings Section
                    Expanded(
                      flex: 2,
                      child: _buildSettingsPanel(context, viewModel),
                    ),
                    // Play/Pause Controls
                    _buildPlaybackControls(context, viewModel),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInteractiveCircle(
      BuildContext context, CircleOfFifthsViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTapUp: (TapUpDetails details) {
              if (viewModel.isPlaying) return;

              final RenderBox box = context.findRenderObject() as RenderBox;
              final Offset localOffset =
                  box.globalToLocal(details.globalPosition);

              final double radius =
                  math.min(box.size.width, box.size.height) / 2 - 20;
              final Offset center =
                  Offset(box.size.width / 2, box.size.height / 2);
              final double angleStep =
                  2 * math.pi / circleOfFifthsKeyNames.length;

              for (int i = 0; i < circleOfFifthsKeyNames.length; i++) {
                final double keyAngleOnScreen =
                    (i - viewModel.currentKeyIndex) * angleStep - (math.pi / 2);

                final TextPainter tp = TextPainter(
                  text: TextSpan(
                      text: getDisplayKeyName(circleOfFifthsKeyNames[i]),
                      style: const TextStyle(fontSize: 16)),
                  textDirection: TextDirection.ltr,
                );
                tp.layout();

                final double textX = center.dx +
                    (radius - 10) * math.cos(keyAngleOnScreen) -
                    tp.width / 2;
                final double textY = center.dy +
                    (radius - 10) * math.sin(keyAngleOnScreen) -
                    tp.height / 2;

                final Rect keyRect =
                    Rect.fromLTWH(textX, textY, tp.width + 10, tp.height + 10);

                final Offset tapRelativeToCircleCenter = Offset(
                    localOffset.dx - center.dx, localOffset.dy - center.dy);

                final Offset keyCenterOnCircle = Offset(
                    (radius - 10) * math.cos(keyAngleOnScreen),
                    (radius - 10) * math.sin(keyAngleOnScreen));

                final double tapRadiusForKey =
                    tp.width > tp.height ? tp.width / 1.5 : tp.height / 1.5;

                if ((tapRelativeToCircleCenter - keyCenterOnCircle)
                        .distanceSquared <
                    tapRadiusForKey * tapRadiusForKey) {
                  viewModel.setStartingKey(circleOfFifthsKeyNames[i]);
                  return;
                }
              }
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: CirclePainter(
                currentKeyIndex: viewModel.currentKeyIndex,
                playbackKeyIndex:
                    viewModel.isPlaying ? viewModel.playbackKeyIndex : null,
                onKeyTapped: (keyName) {
                  if (!viewModel.isPlaying) {
                    viewModel.setStartingKey(keyName);
                  }
                },
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CupertinoButton(
                onPressed: viewModel.isPlaying
                    ? null
                    : () => viewModel.rotateCircle(-1),
                child: const Icon(CupertinoIcons.arrow_counterclockwise)),
            CupertinoButton(
                onPressed: viewModel.isPlaying
                    ? null
                    : () => viewModel.rotateCircle(1),
                child: const Icon(CupertinoIcons.arrow_clockwise)),
          ],
        ),
        const SizedBox(height: 10),
        if (viewModel.isPlaying)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
                'Playing: ${getDisplayKeyName(circleOfFifthsKeyNames[viewModel.playbackKeyIndex])}',
                style: const TextStyle(
                    fontSize: 18,
                    color: CupertinoColors.systemGreen,
                    fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildSettingsPanel(
      BuildContext context, CircleOfFifthsViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // Number of Cycles
          _buildSettingRow(
            context,
            labelWidget: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Cycles: ${viewModel.currentCycleDisplay}/${viewModel.numberOfCycles}',
                    style: CupertinoTheme.of(context).textTheme.textStyle),
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: viewModel.isPlaying
                          ? null
                          : viewModel.decrementTotalCycles,
                      child: const Icon(CupertinoIcons.minus_circle,
                          color: CupertinoColors.systemRed),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: viewModel.isPlaying
                          ? null
                          : viewModel.incrementTotalCycles,
                      child: const Icon(CupertinoIcons.plus_circle,
                          color: CupertinoColors.systemGreen),
                    ),
                  ],
                ),
              ],
            ),
            control: CupertinoSlider(
              value: viewModel.numberOfCycles.toDouble(),
              min: 1,
              max: 20, // Max 20 cycles
              divisions: 19,
              activeColor: CupertinoColors.systemRed,
              onChanged: viewModel.isPlaying
                  ? null
                  : (value) => viewModel.setNumberOfCycles(value.toInt()),
            ),
          ),
          // BPM
          _buildSettingRow(
            context,
            label: 'BPM: ${viewModel.bpm}',
            control: CupertinoSlider(
              value: viewModel.bpm.toDouble(),
              min: 30,
              max: 240,
              divisions: (240 - 30) ~/ 5, // divisions by 5 BPM
              activeColor: CupertinoColors.systemRed,
              onChanged: viewModel.isPlaying
                  ? null
                  : (value) => viewModel.bpm = value.toInt(),
            ),
          ),
          // Beats Per Key Change (simplified time signature)
          _buildSettingRow(
            context,
            label: 'Beats per Key: ${viewModel.beatsPerKeyChange}',
            control: CupertinoSlider(
              value: viewModel.beatsPerKeyChange.toDouble(),
              min: 1,
              max: 16,
              divisions: 15,
              activeColor: CupertinoColors.systemRed,
              onChanged: viewModel.isPlaying
                  ? null
                  : (value) => viewModel.beatsPerKeyChange = value.toInt(),
            ),
          ),
          // TODO: Add more complex time signature selection if needed
        ],
      ),
    );
  }

  Widget _buildSettingRow(BuildContext context,
      {String? label, Widget? labelWidget, required Widget control}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (labelWidget != null)
            labelWidget
          else if (label != null)
            Text(label, style: CupertinoTheme.of(context).textTheme.textStyle),
          const SizedBox(height: 4),
          control,
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(
      BuildContext context, CircleOfFifthsViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero, // Material Icon
            onPressed: viewModel.reset,
            child: const Icon(Icons.replay_circle_filled,
                size: 40, color: CupertinoColors.systemBlue),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: viewModel.isPlaying ? viewModel.pause : viewModel.play,
            child: Icon(
              viewModel.isPlaying
                  ? CupertinoIcons.pause_solid
                  : CupertinoIcons.play_arrow_solid,
              size: 60,
              color: viewModel.isPlaying
                  ? CupertinoColors.systemYellow
                  : CupertinoColors.activeGreen,
            ),
          ),
          // Placeholder for a stop button if distinct from pause/reset
          const SizedBox(width: 40), // To balance the reset button
        ],
      ),
    );
  }
}
