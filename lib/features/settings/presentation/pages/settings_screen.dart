import 'package:flutter/cupertino.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Settings'),
        transitionBetweenRoutes: false,
      ),
      child: Center(child: Text('Settings Screen - Placeholder')),
    );
  }
}
