import 'package:flutter/cupertino.dart';
import 'package:practice_pad/services/practice_session_manager.dart';
import 'package:provider/provider.dart';

/// Widget that shows an active practice session banner at the top of screens
class ActiveSessionBanner extends StatelessWidget {
  const ActiveSessionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PracticeSessionManager>(
      builder: (context, sessionManager, child) {
        if (!sessionManager.hasActiveSession) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: CupertinoColors.systemBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Session icon and name
              const Icon(
                CupertinoIcons.play_circle_fill,
                color: CupertinoColors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Practicing: ${sessionManager.activePracticeItem?.name ?? 'Unknown'}',
                  style: const TextStyle(
                    color: CupertinoColors.white,
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
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 32,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.minus,
                          color: CupertinoColors.systemBlue,
                          size: 18,
                        ),
                      ),
                      onPressed: sessionManager.completedReps > 0 ? () {
                        sessionManager.decrementReps();
                      } : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${sessionManager.completedReps}/${sessionManager.targetReps}',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Increase reps button
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 32,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.plus,
                          color: CupertinoColors.systemBlue,
                          size: 18,
                        ),
                      ),
                      onPressed: sessionManager.completedReps < sessionManager.targetReps ? () {
                        sessionManager.incrementReps();
                      } : null,
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
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 32,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          sessionManager.isTimerRunning
                              ? CupertinoIcons.pause_fill
                              : CupertinoIcons.play_fill,
                          color: CupertinoColors.systemBlue,
                          size: 16,
                        ),
                      ),
                      onPressed: () {
                        if (sessionManager.isTimerRunning) {
                          sessionManager.stopTimer();
                        } else {
                          sessionManager.startTimer();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
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
