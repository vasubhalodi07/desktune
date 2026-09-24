/// English clock/date text without pulling in `intl` (whose DateFormat objects
/// were being rebuilt on every clock tick).
class TimeFormat {
  const TimeFormat._();

  // DateTime.weekday: Monday = 1 ... Sunday = 7.
  static const List<String> _weekdaysShort = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// 1-12, no leading zero.
  static String hour12(DateTime time) {
    final hour = time.hour % 12;
    return (hour == 0 ? 12 : hour).toString();
  }

  /// 00-23.
  static String hour24(DateTime time) => _two(time.hour);

  static String minute(DateTime time) => _two(time.minute);

  static String second(DateTime time) => _two(time.second);

  static String meridiem(DateTime time) => time.hour < 12 ? 'AM' : 'PM';

  /// Upper-case three-letter weekday, e.g. `WED`.
  static String weekdayShort(DateTime time) => _weekdaysShort[time.weekday - 1];

  /// Day of month, no leading zero.
  static String dayOfMonth(DateTime time) => time.day.toString();

  /// Full English month name, e.g. `September`.
  static String monthName(DateTime time) => _months[time.month - 1];
}
