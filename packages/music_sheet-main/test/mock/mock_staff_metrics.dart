import 'package:flutter_test/flutter_test.dart';
import 'package:music_sheet/src/staff/staff_metrics.dart';

class MockStaffMetrics extends Fake implements StaffMetrics {
  MockStaffMetrics({this.width = 0});

  @override
  final double width;
}
