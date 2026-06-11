class DateUtils {
  static DateTime getResetTime(DateTime date, int resetHour) {
    if (date.hour < resetHour) {
      return DateTime(date.year, date.month, date.day - 1, resetHour);
    }
    return DateTime(date.year, date.month, date.day, resetHour);
  }

  static List<DateTime> getWeekDays(DateTime date) {
    final monday = date.subtract(Duration(days: (date.weekday - 1) % 7));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  static int getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}