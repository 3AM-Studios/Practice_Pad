import 'package:flutter_test/flutter_test.dart';
import 'package:music_sheet/src/sheet_music_metrics.dart';

class MockSheetMusicMetrics extends Fake implements SheetMusicMetrics {
  MockSheetMusicMetrics({
    this.staffsHeightSum = 0,
    this.maximumStaffHorizontalMarginSum = 0,
    this.maximumStaffWidth = 0,
  });

  @override
  final double staffsHeightSum;
  @override
  final double maximumStaffHorizontalMarginSum;
  @override
  final double maximumStaffWidth;
}
