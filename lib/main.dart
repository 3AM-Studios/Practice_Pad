import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:practice_pad/features/edit_items/presentation/viewmodels/edit_items_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/today_viewmodel.dart';
import 'package:practice_pad/features/practice/presentation/pages/today_screen.dart';
import 'package:practice_pad/features/routines/presentation/viewmodels/routines_viewmodel.dart';
import 'package:practice_pad/services/device_type.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:practice_pad/widgets/wooden_border_wrapper.dart';

import 'package:practice_pad/services/storage/cloud_kit_service.dart';
import 'package:practice_pad/services/storage/local_storage_service.dart';
import 'package:practice_pad/features/edit_items/presentation/pages/edit_items_screen.dart';
import 'package:practice_pad/features/routines/presentation/pages/edit_routines_screen.dart';
import 'package:practice_pad/features/practice/presentation/viewmodels/practice_session_manager.dart';
import 'package:practice_pad/models/statistics.dart';
import 'package:practice_pad/models/practice_area.dart';
import 'package:practice_pad/services/widget/home_widget_service.dart';
import 'package:practice_pad/services/widget/widget_update_service.dart';
import 'package:practice_pad/services/widget/widget_action_handler.dart';
import 'package:practice_pad/services/widget/widget_integration.dart';
import 'package:practice_pad/services/automatic_sync_manager.dart';
import 'package:practice_pad/services/sync_integration_service.dart';
import 'package:practice_pad/onboarding.dart';
import 'dart:math' as math;

import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);   
  deviceType = await getDeviceType();
  print('device type: $deviceType');

  const String icloudContainerId = "iCloud.com.practicepad";
  // 2. Only run this code on desktop platforms.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      // --- SET YOUR FIXED DIMENSIONS HERE ---
      size: Size(1152, 864),
      minimumSize: Size(1152, 864), // Makes the window non-resizable
      maximumSize: Size(1152, 864), // Makes the window non-resizable
      // ------------------------------------
      center: true,
    );

    // 3. Wait until the window is ready to show, then apply options.
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  try {
    await CloudKitService.initialize(icloudContainerId);
    print(
        "CloudKitService initialized successfully with container: $icloudContainerId");
  } catch (e) {
    print("FATAL: CloudKitService initialization failed: $e");
  }

  // Initialize iCloud Documents sync service
  try {
    print("🔄 Initializing iCloud Documents sync service...");
    await LocalStorageService.initializeICloudSync();
    
    if (LocalStorageService.isICloudSyncEnabled) {
      print("✅ iCloud Documents sync service initialized and available");
    } else {
      print("⚠️ iCloud Documents sync service initialized but not available");
      print("   This is normal on simulators or if iCloud is not configured");
    }
  } catch (e) {
    print("❌ iCloud Documents sync initialization failed: $e");
    print("   Sync functionality will be disabled");
  }

  // Initialize home widget service
  await HomeWidgetService.initialize();
  
  // Initialize widget action handler
    await WidgetActionHandler.initialize();
    // Clear any stale widget data on startup to ensure fresh data
    await WidgetActionHandler.clearAllWidgetData();
    print('Main: Cleared all widget data on startup');

  // Initialize automatic sync manager
  try {
    print("🤖 Initializing AutomaticSyncManager...");
    await AutomaticSyncManager.instance.initialize();
    print("✅ AutomaticSyncManager initialized successfully");
  } catch (e) {
    print("⚠️ AutomaticSyncManager initialization failed: $e");
    print("   Automatic sync will not be available");
  }


  runApp(const PracticeLoverApp());
}

class PracticeLoverApp extends StatelessWidget {
  const PracticeLoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EditItemsViewModel()..fetchPracticeAreas()),
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
      child: MaterialApp(
        title: 'PracticeLover',
        debugShowCheckedModeBanner: false,
        theme: FlexThemeData.light(
          scheme: FlexScheme.bigStone,
          surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
          blendLevel: 7,
          subThemesData: const FlexSubThemesData(
            blendOnLevel: 10,
            blendOnColors: false,
            useTextTheme: true,
            useM2StyleDividerInM3: true,
          ),
          visualDensity: FlexColorScheme.comfortablePlatformDensity,
          useMaterial3: true,
          swapLegacyOnMaterial3: true,
        ),
        darkTheme: FlexThemeData.dark(
          scheme: FlexScheme.indigoM3,
          surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
          blendLevel: 13,
          subThemesData: const FlexSubThemesData(
            blendOnLevel: 20,
            useTextTheme: true,
            useM2StyleDividerInM3: true,
          ),
          visualDensity: FlexColorScheme.comfortablePlatformDensity,
          useMaterial3: true,
          swapLegacyOnMaterial3: true,
        ),
        themeMode: ThemeMode.light,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
        ],
        home: const AppRouter(),
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
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize widget update service after the build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWidgetService();
    });
  }

  void _initializeWidgetService() {
    final todayViewModel = Provider.of<TodayViewModel>(context, listen: false);
    final sessionManager = Provider.of<PracticeSessionManager>(context, listen: false);
    final editItemsViewModel = Provider.of<EditItemsViewModel>(context, listen: false);
    
    WidgetUpdateService.instance.initialize(
      todayViewModel: todayViewModel,
      sessionManager: sessionManager,
    );
    
    // Set up widget action callbacks
    WidgetIntegration.setupWidgetCallbacks(
      todayViewModel: todayViewModel,
      sessionManager: sessionManager,
      editItemsViewModel: editItemsViewModel,
      onNavigateToPractice: (itemId) {
        // For now, this just starts the practice session
        // TODO: Later enhance this to navigate to the practice session screen
        print('Main: Navigation requested for practice item: $itemId');
      },
    );
    
    // Initialize sync integration service for automatic background sync
    SyncIntegrationService.instance.initialize(context);
    
    // Force initial widget update after initialization
    print('Main: Forcing initial widget update after setup');
    WidgetUpdateService.instance.updateWidget();
  }

  @override
  void dispose() {
    WidgetUpdateService.instance.dispose();
    SyncIntegrationService.instance.dispose();
    super.dispose();
  }

  List<Widget> get _tabs => [
    ChangeNotifierProxyProvider<RoutinesViewModel, TodayViewModel>(
      create: (context) => TodayViewModel(
          routinesViewModel:
              Provider.of<RoutinesViewModel>(context, listen: false)),
      update: (context, routinesViewModel, previousTodayViewModel) =>
          TodayViewModel(routinesViewModel: routinesViewModel),
      child: TodayScreen(
        onStatsPressed: () {
          setState(() {
            _currentIndex = 3; // Switch to Stats tab
          });
        },
      ),
    ),
    const EditRoutinesScreen(),
    const EditItemsScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];

  final List<TabItem> _tabItems = const [
    TabItem(
      icon: CupertinoIcons.house_fill,
      label: 'Practice',
    ),
    TabItem(
      icon: CupertinoIcons.list_bullet,
      label: 'Routines',
    ),
    TabItem(
      icon: CupertinoIcons.pencil_ellipsis_rectangle,
      label: 'Items',
    ),
    TabItem(
      icon: CupertinoIcons.chart_bar_square,
      label: 'Stats',
    )
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white, // White app background
      body: SafeArea(
        top:false,
        bottom: false,
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs,
              ),
            ),
            // Custom neumorphic navigation bar positioned at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClayNavigationBar(
                items: _tabItems,
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TabItem {
  final IconData icon;
  final String label;

  const TabItem({
    required this.icon,
    required this.label,
  });
}

class ClayNavigationBar extends StatelessWidget {
  final List<TabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ClayNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Indigo San Marino inspired colors
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    
    return Container(
      margin: const EdgeInsets.only(left: 10, right: 10, bottom: 16),
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (index) {
            final isSelected = index == currentIndex;
            final item = items[index];
            
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: GestureDetector(
                  onTap: () => onTap(index),
      
                  child: ClayContainer(
                    color: surfaceColor, // Use theme surface color
                    width:150,
                    height: 150,
                    borderRadius: 70, // Perfect circle (half of 70)
                    depth: 10,
                    spread: 15,
                    emboss: false, // Emboss when selected
                    // Concave when pressed (selected), none when not selected
                    curveType: isSelected ? CurveType.concave : CurveType.none,

                    child: SizedBox(
                      height: 70,
                      width: 70, // Make it square for perfect circle
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: isSelected ? 28 : 24, // Slightly smaller to fit circle
                            color: isSelected 
                                ? primaryColor // Selected icons use primary color
                                : onSurfaceColor, // Unselected icons use onSurface color
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10, // Smaller text to fit in circle
                              color: isSelected ? Colors.black : Colors.black45,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
          
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
    );
  }
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<PracticeArea> _practiceAreas = [];
  String? _selectedAreaId;
  bool _isLoading = true;
  Map<String, int> _sessionCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final editItemsViewModel = Provider.of<EditItemsViewModel>(context, listen: false);
      final practiceAreas = editItemsViewModel.areas;
      final allStats = await Statistics.getAll();
      
      final Map<String, int> sessionCounts = {};
      
      for (final stat in allStats) {
        sessionCounts[stat.practiceItemId] = (sessionCounts[stat.practiceItemId] ?? 0) + 1;
      }
      
      setState(() {
        _practiceAreas = practiceAreas;
        _sessionCounts = sessionCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _getPracticeIntensityColor(String itemId) {
    final sessionCount = _sessionCounts[itemId] ?? 0;
    if (sessionCount == 0) return const Color(0xFFE0E0E0);
    if (sessionCount <= 2) return const Color(0xFF64B5F6);
    if (sessionCount <= 5) return const Color(0xFFFFB74D);
    return const Color(0xFFEF5350);
  }

  double _getBubbleThickness(String itemId) {
    final sessionCount = _sessionCounts[itemId] ?? 0;
    return (sessionCount * 2.0).clamp(2.0, 10.0);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Practice Stats'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.time, size: 24),
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const PracticeTimeHistoryScreen()),
            );
          },
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _practiceAreas.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.chart_bar, size: 64, color: CupertinoColors.systemGrey),
                        SizedBox(height: 16),
                        Text('No practice areas yet', style: TextStyle(fontSize: 18, color: CupertinoColors.systemGrey)),
                        SizedBox(height: 8),
                        Text('Create practice areas to see your stats!', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey2)),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Practice Area Selection
                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Text('Area: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            Expanded(
                              child: ClayContainer(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: 12,
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Text(
                                    _selectedAreaId == null 
                                        ? 'Select Practice Area' 
                                        : _practiceAreas.firstWhere((a) => a.recordName == _selectedAreaId).name,
                                    style: const TextStyle(color: CupertinoColors.label),
                                  ),
                                  onPressed: () => _showAreaSelector(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Color Legend
                      if (_selectedAreaId != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ClayContainer(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: 12,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _ColorLegendItem(color: Color(0xFFE0E0E0), label: 'No practice'),
                                  _ColorLegendItem(color: Color(0xFF64B5F6), label: '1-2 sessions'),
                                  _ColorLegendItem(color: Color(0xFFFFB74D), label: '3-5 sessions'),
                                  _ColorLegendItem(color: Color(0xFFEF5350), label: '6+ sessions'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Bubble Visualization
                      Expanded(
                        child: _selectedAreaId == null
                            ? const Center(
                                child: Text(
                                  'Select a practice area to view bubble visualization',
                                  style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
                                ),
                              )
                            : BubbleVisualizationWidget(
                                practiceArea: _practiceAreas.firstWhere((a) => a.recordName == _selectedAreaId),
                                sessionCounts: _sessionCounts,
                                getIntensityColor: _getPracticeIntensityColor,
                                getBubbleThickness: _getBubbleThickness,
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  void _showAreaSelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Practice Area'),
        actions: _practiceAreas.map((area) => 
          CupertinoActionSheetAction(
            child: Text(area.name),
            onPressed: () {
              setState(() => _selectedAreaId = area.recordName);
              Navigator.pop(context);
            },
          ),
        ).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _ColorLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: CupertinoColors.secondaryLabel),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class BubbleVisualizationWidget extends StatelessWidget {
  final PracticeArea practiceArea;
  final Map<String, int> sessionCounts;
  final Color Function(String) getIntensityColor;
  final double Function(String) getBubbleThickness;

  const BubbleVisualizationWidget({
    super.key,
    required this.practiceArea,
    required this.sessionCounts,
    required this.getIntensityColor,
    required this.getBubbleThickness,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade50,
            Colors.grey.shade100,
          ],
        ),
      ),
      child: CustomPaint(
        painter: BubblePainter(
          practiceArea: practiceArea,
          sessionCounts: sessionCounts,
          getIntensityColor: getIntensityColor,
          getBubbleThickness: getBubbleThickness,
        ),
        child: Container(),
      ),
    );
  }
}

class BubblePainter extends CustomPainter {
  final PracticeArea practiceArea;
  final Map<String, int> sessionCounts;
  final Color Function(String) getIntensityColor;
  final double Function(String) getBubbleThickness;

  BubblePainter({
    required this.practiceArea,
    required this.sessionCounts,
    required this.getIntensityColor,
    required this.getBubbleThickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw center bubble (practice area) with gradient
    const centerRadius = 80.0;
    final centerGradient = RadialGradient(
      colors: [
        Colors.white,
        Colors.grey.shade100,
        Colors.grey.shade200,
      ],
      stops: const [0.0, 0.7, 1.0],
    );
    
    final centerPaint = Paint()
      ..shader = centerGradient.createShader(Rect.fromCircle(center: center, radius: centerRadius))
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, centerRadius, centerPaint);
    
    // Draw center shadow
    final shadowPaint = Paint()
      ..color = Colors.black12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center + const Offset(2, 2), centerRadius, shadowPaint);
    
    // Draw center border with subtle gradient
    final centerBorderPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, centerRadius, centerBorderPaint);
    
    // Draw practice area name
    final centerTextPainter = TextPainter(
      text: TextSpan(
        text: practiceArea.name,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    centerTextPainter.layout(maxWidth: centerRadius * 1.5);
    centerTextPainter.paint(
      canvas,
      center - Offset(centerTextPainter.width / 2, centerTextPainter.height / 2),
    );
    
    // Draw practice item bubbles around the center
    final items = practiceArea.practiceItems;
    if (items.isEmpty) return;
    
    const itemRadius = 50.0;
    const orbitRadius = 180.0;
    final angleStep = (2 * math.pi) / items.length;
    
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final angle = angleStep * i - math.pi / 2; // Start from top
      final itemCenter = Offset(
        center.dx + orbitRadius * math.cos(angle),
        center.dy + orbitRadius * math.sin(angle),
      );
      
      // Ensure bubble stays within bounds
      final clampedCenter = Offset(
        itemCenter.dx.clamp(itemRadius, size.width - itemRadius),
        itemCenter.dy.clamp(itemRadius, size.height - itemRadius),
      );
      
      // Draw shadow for practice item bubble
      final itemShadowPaint = Paint()
        ..color = Colors.black12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(clampedCenter + const Offset(1, 1), itemRadius, itemShadowPaint);
      
      // Draw practice item bubble with gradient
      final itemColor = getIntensityColor(item.id);
      final itemGradient = RadialGradient(
        colors: [
          itemColor.withOpacity(0.8),
          itemColor,
          itemColor.withOpacity(0.9),
        ],
        stops: const [0.0, 0.6, 1.0],
      );
      
      final itemPaint = Paint()
        ..shader = itemGradient.createShader(Rect.fromCircle(center: clampedCenter, radius: itemRadius))
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(clampedCenter, itemRadius, itemPaint);
      
      // Draw bubble border with thickness based on practice frequency
      final borderThickness = getBubbleThickness(item.id);
      final borderPaint = Paint()
        ..color = itemColor.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderThickness;
      
      canvas.drawCircle(clampedCenter, itemRadius, borderPaint);
      
      // Draw practice item name
      final itemTextPainter = TextPainter(
        text: TextSpan(
          text: item.name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      itemTextPainter.layout(maxWidth: itemRadius * 1.8);
      itemTextPainter.paint(
        canvas,
        clampedCenter - Offset(itemTextPainter.width / 2, itemTextPainter.height / 2 + 5),
      );
      
      // Draw session count
      final sessionCount = sessionCounts[item.id] ?? 0;
      final countTextPainter = TextPainter(
        text: TextSpan(
          text: '$sessionCount',
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      countTextPainter.layout();
      countTextPainter.paint(
        canvas,
        clampedCenter - Offset(countTextPainter.width / 2, -10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PracticeTimeHistoryScreen extends StatefulWidget {
  const PracticeTimeHistoryScreen({super.key});

  @override
  State<PracticeTimeHistoryScreen> createState() => _PracticeTimeHistoryScreenState();
}

class _PracticeTimeHistoryScreenState extends State<PracticeTimeHistoryScreen> {
  Map<String, int> _totalPracticeTime = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Practice Time History'),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _totalPracticeTime.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.time, size: 64, color: CupertinoColors.systemGrey),
                        SizedBox(height: 16),
                        Text('No practice data yet', style: TextStyle(fontSize: 18, color: CupertinoColors.systemGrey)),
                        SizedBox(height: 8),
                        Text('Start practicing to see your history!', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey2)),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Practice Time by Date',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Settings'),
        transitionBetweenRoutes: false,
      ),
      child: Center(child: Text('Settings Screen - Placeholder')),
    );
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _isCheckingOnboarding = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    // Development: Always show onboarding
    final isCompleted = await OnboardingService.isOnboardingCompleted();
    setState(() {
      _showOnboarding = true; // Always show during development
      _isCheckingOnboarding = false;
    });
    
    // Production: Uncomment below and comment out above
    // final isCompleted = await OnboardingService.isOnboardingCompleted();
    // setState(() {
    //   _showOnboarding = !isCompleted;
    //   _isCheckingOnboarding = false;
    // });
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingOnboarding) {
      return const Scaffold(
        body: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: _onOnboardingComplete,
      );
    }

    return const MainAppScaffold();
  }
}
