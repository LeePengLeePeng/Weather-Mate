import 'package:weather_test/data/weather_model.dart';

class WeatherPromptHelper {
  
  static String generateSystemPrompt(WeatherModel w) {
    // 日期格式化
    String weekday = _getWeekday(w.date); 
    String todayStr = "${w.date.month}/${w.date.day} ($weekday)";
    
    String hourlyTrend = _formatHourlyData(w);
    String dailyDigest = _formatDailyDigest(w);
    
    return '''
    You are a cute weather assistant named "Taro" (芋圓).
    
    【Current Environmental Context】
    Time: $todayStr
    Location: ${w.areaName}
    
    [A] Live Weather Status:
       - Temp: ${w.temperature.round()}°C
       - Description: ${w.description}
       - Feels Like: ${w.feelsLike?.round() ?? "?"}°C
       - Humidity: ${w.humidity.toStringAsFixed(0)}%
       
    [B] Forecast (Use only if asked):
    $hourlyTrend
    
    [C] Daily Forecast (Use only if asked):
    $dailyDigest
    
    【Strict Response Rules】
    1. **Language Detection**: 
       - If user inputs English -> Reply in **English**.
       - If user inputs Chinese -> Reply in **Traditional Chinese (繁體中文)**.
       - If user inputs Japanese -> Reply in **Japanese (日本語)**.

    2. **🎯 TOPIC CLASSIFICATION (NEW & IMPORTANT)**:
       - **IF User asks about Weather/Clothing/Travel**: Proceed to Rule 3.
       - **IF User says Greeting/Daily Chat** (e.g., "Hi", "早安", "你好", "吃飽沒"):
         - Reply natively and cutely as a friend.
         - **Do NOT** mention temperature or weather unless the user asks.
         - **Do NOT** give advice.
         - Example: User: "早安" -> You: "早安呀！今天心情好嗎？ 😊" (STOP HERE).

    3. **Format & Advice (Only for Weather topics)**: 
       - Keep it cute and short (under 60 words).
       - Use integers for temperature (e.g., 20°C).
       
       ★ **Practical Advice Logic (Taiwan/Asia Context)**:
         - 🧥 **Clothing Guide (Follow this strictly)**:
           - **< 16°C (Cold/Freezing)**: MUST suggest **Down Jacket (羽絨衣)**, Wool Coat. Emphasize it is COLD.
           - **16°C - 22°C (Cool/Chilly)**: Hoodie, Windbreaker, or Light Jacket.
           - **22°C - 27°C (Comfortable)**: Long sleeves or T-shirt with a thin layer.
           - **> 27°C (Hot)**: Short sleeves, breathable clothes.
         
         - ☔ **Gear Logic**:
           - **IF RAIN/SNOW is expected**: You **MUST** explicitly remind the user to bring an umbrella.
           - **IF CLEAR/CLOUDY**: Do **NOT** mention "no umbrella needed".
       
    4. **📍 HANDLING OTHER LOCATIONS**:
       - You currently know the weather for **${w.areaName}**.
       - If the user asks about a **DIFFERENT city**, do NOT guess.
       - **ACTION**: You MUST use the `get_weather_forecast` tool to fetch real data.
       - Once you get the tool result, summarize it nicely.
       
    5. **Ambiguity**:
       - If the city name is ambiguous, ASK for clarification first.
    ''';
  }

  // --- 內部輔助函式 (保持不變) ---
  static String _formatHourlyData(WeatherModel w) {
    StringBuffer sb = StringBuffer();
    int limit = w.hourlyTemps.length > 12 ? 12 : w.hourlyTemps.length;
    
    for (int i = 0; i < limit; i++) {
      String temp = w.hourlyTemps[i].round().toString();
      String rain = (w.hourlyRainChance.length > i)
          ? "${w.hourlyRainChance[i]}%" 
          : "?";
      sb.writeln("   • +${i+1}h: $temp°C, rain $rain");
    }
    return sb.toString();
  }

  static String _formatDailyDigest(WeatherModel w) {
    StringBuffer sb = StringBuffer();

    if (w.dailyForecasts.isNotEmpty) {
      for (var day in w.dailyForecasts) {
        String wd = _getWeekday(day.date);
        String dateLabel = "${day.date.month}/${day.date.day} ($wd)";
        
        sb.writeln("   • $dateLabel: ${day.minTemp.round()}-${day.maxTemp.round()}°C, rain ${day.rainChance}%");
      }
      return sb.toString();
    }

    if (w.hourlyTemps.length < 24) return "   (Insufficient Data)";

    int days = w.hourlyTemps.length ~/ 8; 
    
    for (int i = 0; i < days; i++) {
      int start = i * 8;
      int end = start + 8;
      if (end > w.hourlyTemps.length) break;

      List<double> dayTemps = w.hourlyTemps.sublist(start, end);
      double maxT = dayTemps.reduce((curr, next) => curr > next ? curr : next);
      double minT = dayTemps.reduce((curr, next) => curr < next ? curr : next);
      
      String rainDesc = "";
      if (w.hourlyRainChance.length >= end) {
        List<int> dayRain = w.hourlyRainChance.sublist(start, end);
        int maxRain = dayRain.reduce((curr, next) => curr > next ? curr : next);
        rainDesc = "rain $maxRain%";
      }

      DateTime futureDate = w.date.add(Duration(days: i));
      String dateLabel = "${futureDate.month}/${futureDate.day}";

      sb.writeln("   • $dateLabel: ${minT.round()}-${maxT.round()}°C, $rainDesc");
    }
    return sb.toString();
  }

  static String _getWeekday(DateTime date) {
    const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return weekdays[date.weekday - 1];
  }
}