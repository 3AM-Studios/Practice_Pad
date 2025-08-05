import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/services/practice_session_manager.dart';
import 'package:provider/provider.dart';

/// Widget that shows an active practice session banner at the top of screens
class ActiveSessionBanner extends StatelessWidget {
  const ActiveSessionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final onPrimaryColor = theme.colorScheme.onPrimary;
    
    return Consumer<PracticeSessionManager>(
      builder: (context, sessionManager, child) {
        if (!sessionManager.hasActiveSession) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(12),
          child: ClayContainer(
            color: primaryColor,
            borderRadius: 20,
            depth: 15,
            spread: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Session icon and name
                  Icon(
                    CupertinoIcons.play_circle_fill,
                    color: onPrimaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Practicing: ${sessionManager.activePracticeItem?.name ?? 'Unknown'}',
                      style: TextStyle(
                        color: onPrimaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Progress display and controls
                  if (sessionManager.isRepsBased) ...[
                    // Reps-based controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Decrease reps button
                        GestureDetector(
                          onTap: sessionManager.completedReps > 0 ? () {
                            sessionManager.decrementReps();
                          } : null,
                          child: ClayContainer(
                            color: surfaceColor,
                            borderRadius: 16,
                            depth: 8,
                            spread: 0,
                            curveType: CurveType.concave,
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                CupertinoIcons.minus,
                                color: primaryColor,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${sessionManager.completedReps}/${sessionManager.targetReps}',
                          style: TextStyle(
                            color: onPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Increase reps button
                        GestureDetector(
                          onTap: sessionManager.completedReps < sessionManager.targetReps ? () {
                            sessionManager.incrementReps();
                          } : null,
                          child: ClayContainer(
                            color: surfaceColor,
                            borderRadius: 16,
                            depth: 8,
                            spread: 2,
                            curveType: CurveType.none,
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                CupertinoIcons.plus,
                                color: primaryColor,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Time-based controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(sessionManager.elapsedSeconds),
                          style: TextStyle(
                            color: onPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            if (sessionManager.isTimerRunning) {
                              sessionManager.stopTimer();
                            } else {
                              sessionManager.startTimer();
                            }
                          },
                          child: ClayContainer(
                            color: surfaceColor,
                            borderRadius: 16,
                            depth: 8,
                            spread: 2,
                            curveType: sessionManager.isTimerRunning ? CurveType.concave : CurveType.none,
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                sessionManager.isTimerRunning
                                    ? CupertinoIcons.pause_fill
                                    : CupertinoIcons.play_fill,
                                color: primaryColor,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
