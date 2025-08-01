import 'package:flutter/cupertino.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/pages/today_screen.dart';
import 'package:practice_pad/features/routines/presentation/viewmodels/routines_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:practice_pad/services/cloud_kit_service.dart';
import 'package:practice_pad/features/edit_items/presentation/pages/edit_items_screen.dart';
import 'package:practice_pad/features/routines/presentation/pages/edit_routines_screen.dart';
import 'package:practice_pad/features/practice/presentation/pages/practice_history_screen.dart';
import 'package:practice_pad/services/practice_session_manager.dart';
import 'package:practice_pad/models/statistics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const String icloudContainerId = "iCloud.com.practicepad";

  try {
    await CloudKitService.initialize(icloudContainerId);
    print(
        "CloudKitService initialized successfully with container: $icloudContainerId");
  } catch (e) {
    print("FATAL: CloudKitService initialization failed: $e");
  }

  runApp(const PracticeLoverApp());
}

class PracticeLoverApp extends StatelessWidget {
  const PracticeLoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EditItemsViewModel()),
        ChangeNotifierProvider(create: (_) => PracticeSessionManager()),
        ChangeNotifierProxyProvider<EditItemsViewModel, RoutinesViewModel>(
          create: (context) => RoutinesViewModel(
            editItemsViewModel: Provider.of<EditItemsViewModel>(context, listen: false),
          ),
          update: (context, editItemsViewModel, previous) =>
              previous ?? RoutinesViewModel(editItemsViewModel: editItemsViewModel),
        ),
        ChangeNotifierProxyProvider<RoutinesViewModel, TodayViewModel>(
          create: (context) => TodayViewModel(
            routinesViewModel: Provider.of<RoutinesViewModel>(context, listen: false),
          ),
          update: (context, routinesViewModel, previous) =>
              previous ?? TodayViewModel(routinesViewModel: routinesViewModel),
        ),
      ],
      child: const CupertinoApp(
        title: 'PracticeLover',
        debugShowCheckedModeBanner: false,
        theme: CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: CupertinoColors.systemRed,
        ),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en', ''),
        ],
        home: MainAppScaffold(),
      ),
    );
  }
}

class MainAppScaffold extends StatefulWidget {
  const MainAppScaffold({super.key});

  @override
  MainAppScaffoldState createState() => MainAppScaffoldState();
}

class MainAppScaffoldState extends State<MainAppScaffold> {
  final List<Widget> _tabs = [
    ChangeNotifierProxyProvider<RoutinesViewModel, TodayViewModel>(
      create: (context) => TodayViewModel(
          routinesViewModel:
              Provider.of<RoutinesViewModel>(context, listen: false)),
      update: (context, routinesViewModel, previousTodayViewModel) =>
          TodayViewModel(routinesViewModel: routinesViewModel),
      child: const TodayScreen(),
    ),
    const EditRoutinesScreen(),
    const EditItemsScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: 'Practice',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'Routines',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.pencil_ellipsis_rectangle),
            label: 'Items',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar_square),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'Settings',
          ),
        ],
        activeColor: CupertinoColors.systemRed,
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          builder: (BuildContext context) {
            return _tabs[index];
          },
        );
      },
    );
  }
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, int> _totalPracticeTime = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all stats and calculate practice time per date
      final allStats = await Statistics.getAll();
      final Map<String, int> timeByDate = {};
      
      for (final stat in allStats) {
        final dateKey = '${stat.timestamp.year}-${stat.timestamp.month.toString().padLeft(2, '0')}-${stat.timestamp.day.toString().padLeft(2, '0')}';
        final timeSeconds = stat.totalTime.inSeconds;
        timeByDate[dateKey] = (timeByDate[dateKey] ?? 0) + timeSeconds;
      }
      
      setState(() {
        _totalPracticeTime = timeByDate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _totalPracticeTime = {};
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Practice Stats'),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _totalPracticeTime.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.chart_bar,
                          size: 64,
                          color: CupertinoColors.systemGrey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No practice data yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start practicing to see your stats!',
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey2,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Practice History button at the top
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton.filled(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(CupertinoIcons.clock, color: CupertinoColors.white),
                                SizedBox(width: 8),
                                Text('View Practice History'),
                              ],
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) => const PracticeHistoryScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        const Text(
                          'Total Practice Time by Date',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Expanded(
                          child: ListView.builder(
                            itemCount: _totalPracticeTime.keys.length,
                            itemBuilder: (context, index) {
                              final date = _totalPracticeTime.keys.elementAt(index);
                              final totalSeconds = _totalPracticeTime[date]!;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemBackground.resolveFrom(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: CupertinoColors.separator.resolveFrom(context),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDisplayDate(date),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.systemBlue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _formatDuration(totalSeconds),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: CupertinoColors.systemBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _formatDisplayDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateTime = DateTime(date.year, date.month, date.day);
    
    if (selectedDateTime == today) {
      return 'Today';
    } else if (selectedDateTime == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Settings')),
      child: Center(child: Text('Settings Screen - Placeholder')),
    );
  }
}
