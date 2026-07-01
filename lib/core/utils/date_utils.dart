import 'package:intl/intl.dart';

class AppDateUtils {
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatDisplayDate(DateTime date, [String? localeName]) {
    return DateFormat('MMM dd, yyyy', localeName).format(date);
  }

  static String formatDateTime(DateTime date, [String? localeName]) {
    return DateFormat('MMM dd, yyyy hh:mm a', localeName).format(date);
  }

  static DateTime get today => DateTime.now();
  static DateTime get todayStart => getStartOfDay(today);
  static DateTime get todayEnd => getEndOfDay(today);
}