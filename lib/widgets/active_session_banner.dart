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
    final surfaceColor = Theme.of(context).colorScheme.surface; // Light clay surface

    return Consumer<PracticeSessionManager>(
      builder: (context, sessionManager, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: ClayContainer(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: 20,
         
            child: GestureDetector(
              onTap: sessionManager.hasActiveSession
                ? () {
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
                  }
                : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/images/wood_texture_rotated.jpg'),
                    fit: BoxFit.cover,
                  ),
                 border: Border.all(color: surfaceColor, width: 4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: sessionManager.hasActiveSession
                  ? Row(
                      children: [
                        // Session icon and name
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sessionManager.activePracticeItem?.name ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                    // Timer-based controls
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
                            color: const Color.fromARGB(255, 141, 110, 75),
                            borderRadius: 16,
                            width: 32,
                            height: 32,
                            child: Icon(
                              sessionManager.isTimerRunning
                                  ? CupertinoIcons.pause_fill
                                  : CupertinoIcons.play_fill,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                      ],
                    )
                  : const Center(
                      child: Text(
                        'No active practice session',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
