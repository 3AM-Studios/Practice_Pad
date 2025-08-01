import 'package:flutter/cupertino.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'package:practice_pad/widgets/practice_area_tile.dart';
import 'package:practice_pad/widgets/active_session_banner.dart';
import 'package:provider/provider.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TodayViewModel>(
      builder: (context, viewModel, child) {
        return CupertinoPageScaffold(
          navigationBar:
              const CupertinoNavigationBar(middle: Text('Today\'s Practice')),
         child: SafeArea(
            child: _buildBody(context, viewModel),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, TodayViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    
    if (viewModel.todaysAreas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'No practice areas scheduled for today.\nAdd areas to today\'s routine in the "Routines" tab.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        
        // Active session banner
        const ActiveSessionBanner(),
        
        // Practice Areas with expandable items
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Practice Areas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: viewModel.todaysAreas.length,
                    itemBuilder: (context, index) {
                      final area = viewModel.todaysAreas[index];
                      return PracticeAreaTile(area: area, viewModel: viewModel);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
