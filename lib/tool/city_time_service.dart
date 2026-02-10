import 'package:intl/intl.dart';

class CityTimeService {
  /// 根據 API 提供的 timezone offset（秒）計算城市當地時間
  static DateTime getCityLocalTime(int timezoneOffsetSeconds) {
    return DateTime.now().toUtc().add(
      Duration(seconds: timezoneOffsetSeconds),
    );
  }

  static DateTime convertUtcToCityTime(DateTime utc, int offsetSeconds) {
    return utc.toUtc().add(Duration(seconds: offsetSeconds));
  }

  /// 格式化顯示時間
  static String formatCityTime(int timezoneOffsetSeconds) {
    final localTime = getCityLocalTime(timezoneOffsetSeconds);
    return DateFormat('HH:mm').format(localTime);
  }

  /// 判斷是否為白天（可給動畫或背景用）
  static bool isDayTime(int timezoneOffsetSeconds) {
    final hour = getCityLocalTime(timezoneOffsetSeconds).hour;
    return hour >= 6 && hour < 18;
  }
}
