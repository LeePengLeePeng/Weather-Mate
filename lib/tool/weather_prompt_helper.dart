import 'package:weather_test/data/weather_model.dart';

class WeatherPromptHelper {
  
  /// 主要入口：將 WeatherModel 轉為 AI 用的 System Prompt
  static String generateSystemPrompt(WeatherModel w) {
    // 取得當前時間字串
    String todayStr = "${w.date.month}/${w.date.day} (${_getWeekday(w.date.weekday)})";
    
    String hourlyTrend = _formatHourlyData(w);
    String dailyDigest = _formatDailyDigest(w);
    
    return '''
    你是一個叫 芋圓 的可愛氣象電子雞。
    個性：活潑、貼心、喜歡用可愛的語氣、顏文字。
    任務：回答使用者的天氣與穿搭問題。

    【目前時間與地點】
    今天是：$todayStr
    地點：${w.areaName}
    
    [A] 即時現況：
       - 氣溫：${w.temperature.toStringAsFixed(1)}°C
       - 天氣：${w.description}
       - 體感：${w.feelsLike?.toStringAsFixed(1) ?? "未知"}°C
       - 濕度：${w.humidity.toStringAsFixed(0)}%
       - 日出/日落：${_formatTime(w.sunrise)} / ${_formatTime(w.sunset)}
       
    [B] 短期細節 (未來 12 小時)：
    $hourlyTrend
    
    [C] 長期預報 (未來 5 天)：
    $dailyDigest
    
    【回答規則】
    1. 只能根據上述資料回答，若資料不足請誠實告知。
    2. 若問「現在/今天」，參考 [A] 與 [B]。
    3. 若問「明天/後天/週幾」，請對照 [C] 的日期回答。
    4. [C] 區塊中已標示具體日期與星期，請仔細對應。
    5. 針對氣溫給予穿搭建議。
    6. 回答盡量簡短可愛（80字以內）。
    ''';
  }

  // --- 內部輔助函式 ---

  static String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  // 數字轉中文星期
  static String _getWeekday(int weekday) {
    const map = {1: '週一', 2: '週二', 3: '週三', 4: '週四', 5: '週五', 6: '週六', 7: '週日'};
    return map[weekday] ?? '';
  }

  static String _formatHourlyData(WeatherModel w) {
    StringBuffer sb = StringBuffer();
    int limit = w.hourlyTemps.length > 12 ? 12 : w.hourlyTemps.length;
    
    for (int i = 0; i < limit; i++) {
      // 這裡每筆資料間隔視為 1 小時 (或是依據你的資料源可能是 3 小時)
      // 為了讓機器人更有時間感，我們把時間推算出來
      DateTime time = w.date.add(Duration(hours: i)); // 假設每格1小時，若是OpenWeather原始資料可能是3小時
      // 註：因為經過 Repository 處理，這裡的 hourlyTemps 對應的時間間隔需確認
      // 簡單起見，我們顯示 "+N 小時" 最保險
      
      String temp = w.hourlyTemps[i].toStringAsFixed(1);
      String rain = (w.hourlyRainChance != null && w.hourlyRainChance!.length > i)
          ? "${w.hourlyRainChance![i]}%" 
          : "未知";
      sb.writeln("   • ${i+1}小時後: $temp°C, 降雨機率 $rain");
    }
    return sb.toString();
  }

  static String _formatDailyDigest(WeatherModel w) {
    StringBuffer sb = StringBuffer();
    if (w.hourlyTemps.length < 24) return "   (資料不足，僅有短期預報)";

    // 假設每 8 筆資料 = 1 天 (3hr * 8 = 24hr)
    // 我們從「今天」開始算
    int days = w.hourlyTemps.length ~/ 8; 
    
    for (int i = 0; i < days; i++) {
      int start = i * 8;
      int end = start + 8;
      if (end > w.hourlyTemps.length) break;

      List<double> dayTemps = w.hourlyTemps.sublist(start, end);
      double maxT = dayTemps.reduce((curr, next) => curr > next ? curr : next);
      double minT = dayTemps.reduce((curr, next) => curr < next ? curr : next);
      
      String rainDesc = "";
      if (w.hourlyRainChance != null && w.hourlyRainChance!.length >= end) {
        List<int> dayRain = w.hourlyRainChance!.sublist(start, end);
        // 算出這天的平均降雨機率，或最大降雨機率
        int maxRain = dayRain.reduce((curr, next) => curr > next ? curr : next);
        rainDesc = "降雨機率 $maxRain%";
      }

      // 🔥 關鍵修正：把具體的日期和星期算出來
      DateTime futureDate = w.date.add(Duration(days: i));
      String dateLabel = "${futureDate.month}/${futureDate.day} (${_getWeekday(futureDate.weekday)})";

      sb.writeln("   • $dateLabel: 高溫 ${maxT.toStringAsFixed(1)} / 低溫 ${minT.toStringAsFixed(1)}, $rainDesc");
    }
    return sb.toString();
  }
}