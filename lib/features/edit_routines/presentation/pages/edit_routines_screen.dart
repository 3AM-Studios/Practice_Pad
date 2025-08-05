import 'package:flutter/cupertino.dart';

class EditRoutinesScreen extends StatelessWidget {
  const EditRoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Edit Routines'),
      ),
      child: Center(child: Text('Edit Routines Screen - Placeholder')),
    );
  }
}
