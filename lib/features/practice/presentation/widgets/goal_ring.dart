import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';


Widget buildGoalRing(BuildContext context, TodayViewModel viewModel) {
  final theme = Theme.of(context);
  
  // Use actual data from viewModel
  final goalMinutes = viewModel.dailyGoalMinutes;
  final practiceMinutes = viewModel.todaysPracticeMinutes;
  final progress = goalMinutes > 0 ? practiceMinutes / goalMinutes : 0.0;
  
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

    child: ClayContainer(
      color: theme.colorScheme.surface,
      borderRadius: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Minus button
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: ClayContainer(
                color: theme.colorScheme.surface,
                borderRadius: 15,
                width: 30,
                height: 30,
                child: const Icon(
                  CupertinoIcons.minus,
                  size: 18,
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
                child: Container(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 8,
                          backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                      ),
                      // Progress circle
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 8,
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
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            '${goalMinutes}m',
                            style: TextStyle(
                              fontSize: 16,
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
                borderRadius: 15,
                width: 30,
                height: 30,
                child: const Icon(
                  CupertinoIcons.plus,
                  size: 18,
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
