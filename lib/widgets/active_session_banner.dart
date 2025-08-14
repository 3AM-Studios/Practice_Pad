import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:practice_pad/services/practice_session_manager.dart';
import 'package:practice_pad/features/practice/presentation/pages/practice_session_screen.dart';
import 'package:provider/provider.dart';

/// Widget that shows an active practice session banner at the top of screens
class ActiveSessionBanner extends StatelessWidget {
  const ActiveSessionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Use a warm, darker clay color for contrast with goal section
    const bannerColor = Color.fromARGB(255, 108, 119, 131); // Dark blue-gray
    const surfaceColor = Color(0xFFE8EAF0); // Light clay surface
    const textColor = Colors.white;

    return Consumer<PracticeSessionManager>(
      builder: (context, sessionManager, child) {
        if (!sessionManager.hasActiveSession) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: ClayContainer(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: 20,
            spread: 5,
            child: GestureDetector(
              onTap: () {
                if (sessionManager.activePracticeItem != null) {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => PracticeSessionScreen(
                        practiceItem: sessionManager.activePracticeItem!,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                    fit: BoxFit.cover,
                  ),
                 border: Border.all(color: surfaceColor, width: 4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // Session icon and name
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Practicing: ${sessionManager.activePracticeItem?.name ?? 'Unknown'}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
                            onTap: sessionManager.completedReps > 0
                                ? () {
                                    sessionManager.decrementReps();
                                  }
                                : null,
                            child: const ClayContainer(
                              color: surfaceColor,
                              borderRadius: 20,
                              width: 32,
                              height: 32,
                              spread: 0,
                              child: Icon(
                                CupertinoIcons.minus,
                                color: bannerColor,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${sessionManager.completedReps}/${sessionManager.targetReps}',
                            style: const TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Increase reps button
                          ClayContainer(
                            color: surfaceColor,
                            borderRadius: 16,
                            width: 32,
                            height: 32,
                            child: GestureDetector(
                              onTap: sessionManager.completedReps <
                                      sessionManager.targetReps
                                  ? () {
                                      sessionManager.incrementReps();
                                    }
                                  : null,
                              child: Icon(
                                CupertinoIcons.plus,
                                color: bannerColor,
                                size: 18,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
                              width: 32,
                              height: 32,
                              spread: 2,
                              child: Icon(
                                sessionManager.isTimerRunning
                                    ? CupertinoIcons.pause_fill
                                    : CupertinoIcons.play_fill,
                                color: bannerColor,
                                size: 16,
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
