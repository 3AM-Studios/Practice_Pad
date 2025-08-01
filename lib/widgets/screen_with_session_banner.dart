import 'package:flutter/material.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';

/// A simple wrapper that adds an active session banner to any screen
class ScreenWithSessionBanner extends StatelessWidget {
  final Widget child;
  final String title;

  const ScreenWithSessionBanner({
    super.key,
    required this.child,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Active session banner
          const ActiveSessionBanner(),
          
          // Main content
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}
