import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';


Widget buildGoalRing(BuildContext context, TodayViewModel viewModel, {bool isLarge = false}) {
  final theme = Theme.of(context);
  
  // Use actual data from viewModel
  final goalMinutes = viewModel.dailyGoalMinutes;
  final practiceMinutes = viewModel.todaysPracticeMinutes;
  final progress = goalMinutes > 0 ? practiceMinutes / goalMinutes : 0.0;
  
  // Size configurations - made isLarge=false much smaller
  final ringSize = isLarge ? 160.0 : 60.0;  // Reduced from 100.0 to 60.0
  final strokeWidth = isLarge ? 12.0 : 5.0;  // Reduced from 8.0 to 5.0
  final goalFontSize = isLarge ? 18.0 : 9.0;  // Reduced from 12.0 to 9.0
  final minutesFontSize = isLarge ? 24.0 : 12.0;  // Reduced from 16.0 to 12.0
  final containerPadding = isLarge ? 24.0 : 10.0;  // Reduced from 16.0 to 10.0
  final buttonSize = isLarge ? 40.0 : 22.0;  // Reduced from 30.0 to 22.0
  final iconSize = isLarge ? 24.0 : 14.0;  // Reduced from 18.0 to 14.0
  
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

    child: ClayContainer(
      color: theme.colorScheme.surface,
      borderRadius: 20,
      child: Container(
        padding: EdgeInsets.all(containerPadding),
        child: Row(
          children: [
            // Minus button
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: ClayContainer(
                color: theme.colorScheme.surface,
                borderRadius: isLarge ? 20 : 15,
                width: buttonSize,
                height: buttonSize,
                child: Icon(
                  CupertinoIcons.minus,
                  size: iconSize,
                  color: CupertinoColors.systemRed,
                ),
              ),
              onPressed: () {
                // Decrease goal by 2 minutes
                viewModel.decreaseGoal();
              },
            ),
            
            // Goal ring in the middle
            Expanded(
              child: Center(
                child: SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      SizedBox(
                        width: ringSize,
                        height: ringSize,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: strokeWidth,
                          backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                      ),
                      // Progress circle
                      SizedBox(
                        width: ringSize,
                        height: ringSize,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: strokeWidth,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation(
                            progress >= 1.0 
                              ? CupertinoColors.systemGreen 
                              : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      // Text in center
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Goal:',
                            style: TextStyle(
                              fontSize: goalFontSize,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            '${goalMinutes}m',
                            style: TextStyle(
                              fontSize: minutesFontSize,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Plus button
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: ClayContainer(
                color: theme.colorScheme.surface,
                borderRadius: isLarge ? 20 : 15,
                width: buttonSize,
                height: buttonSize,
                child: Icon(
                  CupertinoIcons.plus,
                  size: iconSize,
                  color: CupertinoColors.systemGreen,
                ),
              ),
              onPressed: () {
                // Increase goal by 2 minutes
                viewModel.increaseGoal();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
