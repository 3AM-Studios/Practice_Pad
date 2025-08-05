enum DayOfWeek {
  sunday,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday
}

// Helper to get a short string representation (e.g., 'S', 'M', 'T')
String dayOfWeekToString(DayOfWeek day) {
  switch (day) {
    case DayOfWeek.sunday:
      return 'S';
    case DayOfWeek.monday:
      return 'M';
    case DayOfWeek.tuesday:
      return 'T';
    case DayOfWeek.wednesday:
      return 'W';
    case DayOfWeek.thursday:
      return 'T';
    case DayOfWeek.friday:
      return 'F';
    case DayOfWeek.saturday:
      return 'S';
    default:
      return '';
  }
}

// Helper to get full name
String dayOfWeekToFullName(DayOfWeek day) {
  switch (day) {
    case DayOfWeek.sunday:
      return 'Sunday';
    case DayOfWeek.monday:
      return 'Monday';
    case DayOfWeek.tuesday:
      return 'Tuesday';
    case DayOfWeek.wednesday:
      return 'Wednesday';
    case DayOfWeek.thursday:
      return 'Thursday';
    case DayOfWeek.friday:
      return 'Friday';
    case DayOfWeek.saturday:
      return 'Saturday';
    default:
      return '';
  }
}
