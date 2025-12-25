import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:weather/weather.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart'; // 用於日期格式化
import 'weather_model.dart';

class WeatherRepository {
  String get openWeatherApiKey => dotenv.env['OPEN_WEATHER_API_KEY'] ?? '';
  String get cwaApiKey => dotenv.env['CWA_API_KEY'] ?? '';

  bool _isInTaiwan(double lat, double lon) {
    return (lat > 21.5 && lat < 25.5) && (lon > 119.0 && lon < 122.5);
  }

  String? _getCountyDataId(String countyName) {
    if (countyName.contains("宜蘭")) return "F-D0047-001";
    if (countyName.contains("桃園")) return "F-D0047-005";
    if (countyName.contains("新竹縣")) return "F-D0047-009";
    if (countyName.contains("苗栗")) return "F-D0047-013";
    if (countyName.contains("彰化")) return "F-D0047-017";
    if (countyName.contains("南投")) return "F-D0047-021";
    if (countyName.contains("雲林")) return "F-D0047-025";
    if (countyName.contains("嘉義縣")) return "F-D0047-029";
    if (countyName.contains("屏東")) return "F-D0047-033";
    if (countyName.contains("臺東") || countyName.contains("台東")) return "F-D0047-037";
    if (countyName.contains("花蓮")) return "F-D0047-041";
    if (countyName.contains("澎湖")) return "F-D0047-045";
    if (countyName.contains("基隆")) return "F-D0047-049";
    if (countyName.contains("新竹市")) return "F-D0047-053";
    if (countyName.contains("嘉義市")) return "F-D0047-057";
    if (countyName.contains("臺北") || countyName.contains("台北")) return "F-D0047-061";
    if (countyName.contains("高雄")) return "F-D0047-065";
    if (countyName.contains("新北")) return "F-D0047-069"; 
    if (countyName.contains("臺中") || countyName.contains("台中")) return "F-D0047-073";
    if (countyName.contains("臺南") || countyName.contains("台南")) return "F-D0047-077";
    if (countyName.contains("連江")) return "F-D0047-081";
    if (countyName.contains("金門")) return "F-D0047-085";
    return null;
  }

  // ===============================================================
  // 🚀 給 Groq AI 專用的函式
  // ===============================================================
  Future<String> getWeatherForecastForGroq(String locationName) async {
    try {
      List<Location> locations = await locationFromAddress(locationName);
      if (locations.isEmpty) return "找不到 $locationName 的座標資料";
      
      double lat = locations.first.latitude;
      double lon = locations.first.longitude;

      // 呼叫你已經寫好的主要 getWeather 邏輯 (會自動判斷 CWA 或 OpenWeather)
      WeatherModel weather = await getWeather(lat, lon);
      
      return _generateAIReport(locationName, weather);
    } catch (e) {
      return "查詢 $locationName 天氣時發生錯誤: $e";
    }
  }

  // 產生給 AI 看的報告 (把數據轉文字)
  String _generateAIReport(String city, WeatherModel w) {
    StringBuffer sb = StringBuffer();
    
    // 1. 基本資訊
    sb.writeln("【地點】：$city (${w.areaName})");
    sb.writeln("【目前】：${w.description}, 氣溫 ${w.temperature}°C, 體感 ${w.feelsLike}°C, 降雨機率 ${w.rainChance}%");
    
    // 2. 未來 12 小時 (短期細節)
    sb.writeln("\n--- 未來 12 小時預報 (短期) ---");
    DateTime now = DateTime.now();
    
    // 確保數據安全
    int hourlyCount = w.hourlyTemps.length;
    if (w.hourlyRainChance.length < hourlyCount) hourlyCount = w.hourlyRainChance.length;
    if (hourlyCount > 12) hourlyCount = 12; // 只取前 12 小時避免太長

    for (int i = 0; i < hourlyCount; i += 3) { // 每 3 小時取一筆，節省 Token
      DateTime time = now.add(Duration(hours: i));
      String timeStr = DateFormat('MM/dd HH:mm').format(time);
      double temp = w.hourlyTemps[i];
      int rain = w.hourlyRainChance[i];
      sb.writeln("$timeStr -> 溫 ${temp.toStringAsFixed(1)}°C, 雨 $rain%");
    }

    // 3. 未來 7 天 (長期趨勢 - 關鍵修改 🔥)
    if (w.dailyForecasts != null && w.dailyForecasts!.isNotEmpty) {
      sb.writeln("\n--- 未來 7 天預報 (長期) ---");
      for (var d in w.dailyForecasts!) {
        String dateStr = DateFormat('MM/dd (E)', 'zh_TW').format(d.date); // 例如: 12/26 (週四)
        // 為了讓 AI 讀懂，明確標示高低溫與降雨
        sb.writeln("📅 $dateStr : 低溫 ${d.minTemp.toStringAsFixed(1)}°C / 高溫 ${d.maxTemp.toStringAsFixed(1)}°C, 降雨機率 ${d.rainChance}%");
      }
    } else {
      sb.writeln("\n(無長期預報資料)");
    }
    
    sb.writeln("\n--- 報告結束 ---");
    sb.writeln("注意：回答時請根據使用者問的日期（今天、明天、或是具體星期幾）從上方數據找答案。");
    
    return sb.toString();
  }

  // ===============================================================
  // 1. 主要進入點
  // ===============================================================
  Future<WeatherModel> getWeather(double lat, double lon) async {
     if (openWeatherApiKey.isEmpty || cwaApiKey.isEmpty) {
        throw Exception("❌ API Key 遺失！請檢查 .env 檔案是否設定正確。");
     }

    // 先取得 OpenWeather 資料當作基底
    WeatherModel openWeatherData = await _fetchFromOpenWeather(lat, lon);

    if (_isInTaiwan(lat, lon)) {
      try {
        // 嘗試取得 CWA 台灣真實數據
        return await _fetchTaiwanTownshipWeather(lat, lon, openWeatherData);
      } catch (e) {
        print("⚠️ 鄉鎮資料取得失敗, 降級使用 OpenWeather: $e");
        return openWeatherData;
      }
    } else {
      return openWeatherData;
    }
  }

  // ===============================================================
  // 2. 處理 OpenWeather
  // ===============================================================
  Future<WeatherModel> _fetchFromOpenWeather(double lat, double lon) async {
    WeatherFactory wf = WeatherFactory(openWeatherApiKey, language: Language.CHINESE_TRADITIONAL);
    
    // 1. 取得「目前天氣」與「五天預報 (每3小時一筆)」
    Weather current = await wf.currentWeatherByLocation(lat, lon);
    List<Weather> forecast = await wf.fiveDayForecastByLocation(lat, lon);

    // 2. 處理逐時資料 (24 小時)
    List<double> hourlyTemps = [];
    List<int> hourlyRainChances = [];
    List<int> hourlyCodes = [];
    
    // 將 3 小時一筆的預報擴充為逐時
    for (var w in forecast.take(8)) {
      double temp = w.temperature?.celsius ?? 0;
      int pop = _calculateRainChanceFromOWMCode(w.weatherConditionCode ?? 800);
      String desc = w.weatherDescription ?? "";
      
      for (int i = 0; i < 3; i++) {
        if (hourlyTemps.length < 24) {
          hourlyTemps.add(temp);
          hourlyRainChances.add(pop);
          hourlyCodes.add(hourlyIconFromWxAndPop(desc, pop));
        }
      }
    }

    // 3. 處理每日預報 (確保包含今天在內的 6 天)
    Map<String, List<Weather>> groupedByDay = {};
    
    // 先把今天存進去 (因為 forecast 有時從 3 小時後才開始)
    String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    groupedByDay[todayKey] = [current];

    // 分類預報資料
    for (var w in forecast) {
      if (w.date != null) {
        String dateKey = DateFormat('yyyy-MM-dd').format(w.date!);
        groupedByDay.putIfAbsent(dateKey, () => []).add(w);
      }
    }

    List<DailyWeather> dailyForecasts = [];
    List<String> sortedKeys = groupedByDay.keys.toList()..sort();

    // 強制取 6 天，如果 API 資料不夠（例如第 6 天剛好沒資料），則用最後一天模擬補齊
    for (int i = 0; i < 6; i++) {
      String dateKey;
      List<Weather> dayData;
      
      if (i < sortedKeys.length) {
        dateKey = sortedKeys[i];
        dayData = groupedByDay[dateKey]!;
      } else {
        // 補丁：如果 API 沒給到第 6 天，用最後一天的日期加 1 天模擬
        DateTime lastDate = DateTime.parse(sortedKeys.last).add(Duration(days: i - sortedKeys.length + 1));
        dateKey = DateFormat('yyyy-MM-dd').format(lastDate);
        dayData = groupedByDay[sortedKeys.last]!; // 使用最後一天的天氣當參考
      }

      double maxT = dayData.map((e) => e.tempMax?.celsius ?? e.temperature?.celsius ?? 0).reduce((a, b) => a > b ? a : b);
      double minT = dayData.map((e) => e.tempMin?.celsius ?? e.temperature?.celsius ?? 0).reduce((a, b) => a < b ? a : b);
      
      // 取該日中間時段的天氣作為代表
      Weather representative = dayData[dayData.length ~/ 2];
      int pop = _calculateRainChanceFromOWMCode(representative.weatherConditionCode ?? 800);

      dailyForecasts.add(DailyWeather(
        date: DateTime.parse(dateKey),
        maxTemp: maxT,
        minTemp: minT,
        rainChance: pop,
        conditionCode: representative.weatherConditionCode ?? 800,
      ));
    }

    // 4. 回傳模型
    int currentPop = _calculateRainChanceFromOWMCode(current.weatherConditionCode ?? 800);
    
    return WeatherModel(
      temperature: current.temperature?.celsius ?? 0,
      tempMax: dailyForecasts[0].maxTemp,
      tempMin: dailyForecasts[0].minTemp,
      description: current.weatherDescription ?? "",
      conditionCode: decideConditionCode(current.weatherDescription ?? "", currentPop),
      hourlyConditionCodes: hourlyCodes,
      hourlyRainChance: hourlyRainChances,
      areaName: current.areaName ?? "國外地區",
      date: current.date ?? DateTime.now(),
      sunrise: current.sunrise ?? DateTime.now(),
      sunset: current.sunset ?? DateTime.now(),
      humidity: current.humidity ?? 0,
      windSpeed: current.windSpeed ?? 0,
      hourlyTemps: hourlyTemps,
      rainChance: currentPop,
      dewPoint: _calculateDewPoint(current.temperature?.celsius ?? 0, current.humidity ?? 50),
      feelsLike: current.tempFeelsLike?.celsius ?? current.temperature?.celsius ?? 0,
      windDirection: _windDegreeToDirection(current.windDegree),
      weatherForecast: null,
      dailyForecasts: dailyForecasts,
    );
  }

  // ===============================================================
  // 3. 處理 CWA 台灣資料 (包含 7 天預報)
  // ===============================================================
  Future<WeatherModel> _fetchTaiwanTownshipWeather(
      double lat, double lon, WeatherModel baseData) async {
    
    // 1. 取得地點資訊
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
    Placemark place = placemarks.first;
    
    String city = (place.administrativeArea ?? "臺北市").replaceAll('台', '臺'); 
    String district = place.locality ?? place.subLocality ?? place.subAdministrativeArea ?? "";
    if (district == city) district = place.subLocality ?? "";

    print("📍 CWA 請求地點: $city $district");

    String? dataId = _getCountyDataId(city);
    if (dataId == null) return baseData;

    // 2. 發送 API 請求
    final uri = Uri.https(
      'opendata.cwa.gov.tw', 
      '/api/v1/rest/datastore/$dataId', 
      {
        'Authorization': cwaApiKey,
        'format': 'JSON',
        'locationName': district,
      } 
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('CWA API Error: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data['success'] != 'true') throw Exception("CWA API 回傳錯誤");
      
    var locationsNode = _safeGetList(_safeGet(data, 'records'), 'Locations')[0];
    List locationListRaw = _safeGetList(locationsNode, 'Location');
    
    // 3. 尋找對應的行政區 (District)
    var targetLocation;
    try {
      targetLocation = locationListRaw.firstWhere((loc) {
        return (_safeGet(loc, 'LocationName')?.toString() ?? "") == district;
      }, orElse: () => null);

      if (targetLocation == null) {
         targetLocation = locationListRaw.firstWhere((loc) {
          String name = _safeGet(loc, 'LocationName')?.toString() ?? "";
          return name.contains(district) || district.contains(name);
        });
      }
    } catch (e) {
      targetLocation = locationListRaw[0];
    }
    if (targetLocation == null) targetLocation = locationListRaw[0];

    final weatherElements = _safeGetList(targetLocation, 'WeatherElement');

    print("🔍 API 包含元素: ${weatherElements.map((e) => e['ElementName']).toList()}");

    // --- Helper: 通用取值函式 (增強容錯) ---
    // 說明：同時尋找 elementValue, ElementValue 以及 value, Value
    String? getElementValue(List<String> possibleNames) {
        try {
          var el = weatherElements.firstWhere(
            (e) => possibleNames.contains(_safeGet(e, 'ElementName')), 
            orElse: ()=>null
          );
          if (el == null) return null;
          var timeList = _safeGetList(el, 'Time');
          if (timeList.isEmpty) return null;
          
          // 🔥 修正：同時找 'ElementValue' 和 'elementValue'
          var item = timeList[0];
          var valList = _safeGetList(item, 'ElementValue');
          if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
          
          if (valList.isEmpty) return null;
          
          // 🔥 修正：同時找 'value' 和 'Value'
          return _safeGet(valList[0], 'value')?.toString() ?? 
                 _safeGet(valList[0], 'Value')?.toString();
        } catch (e) { return null; }
    }

    // 4. 解析基礎數值
    double currentTemp = double.tryParse(getElementValue(['T', '溫度']) ?? '') ?? baseData.temperature;
    double humidity = double.tryParse(getElementValue(['RH', '相對濕度']) ?? '') ?? baseData.humidity;
    double windSpeed = double.tryParse(getElementValue(['WindSpeed', '風速']) ?? '') ?? baseData.windSpeed;
    String wx = baseData.description; // 先用預設值
    try {
      var wxNode = weatherElements.firstWhere(
        (e) => ['Wx', '天氣現象'].contains(_safeGet(e, 'ElementName')), 
        orElse: () => null
      );
      if (wxNode != null) {
        var wxTimeList = _safeGetList(wxNode, 'Time');
        if (wxTimeList.isNotEmpty) {
          // 使用第一個區間的天氣（與逐時預報邏輯一致）
          var item = wxTimeList[0];
          var valList = _safeGetList(item, 'ElementValue');
          if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
          if (valList.isNotEmpty) {
            wx = (_safeGet(valList[0], 'Weather') ?? 
                  _safeGet(valList[0], 'weather') ?? 
                  _safeGet(valList[0], 'value') ?? 
                  "多雲").toString();
          }
        }
      }
    } catch (e) {
      print("⚠️ 取得當前天氣描述失敗: $e");
    }

    print("📊 基礎數值解析: 溫=$currentTemp, 濕=$humidity, 風=$windSpeed, 況=$wx");

    // --- 逐時溫度 (Hourly Temp) ---
    print("⏳ 開始解析逐時溫度 (Hourly Temp)...");
    List<double> cwaHourlyTemps = [];
    try {
      var tempNode = weatherElements.firstWhere(
        (e) => ['T', '溫度'].contains(_safeGet(e, 'ElementName')), 
        orElse: ()=>null
      );
      
      if (tempNode != null) {
        var timeList = _safeGetList(tempNode, 'Time');
        
        // 🔥 修改點：使用 helper 展開數據，而不是直接 add
        cwaHourlyTemps = _expandTempToHourly(timeList);

      } else {
        print("   ⚠️ 找不到 [T, 溫度] 節點");
      }
    } catch (e) {
      print("   ❌ 解析逐時溫度發生錯誤: $e");
    }
    
    // 如果還是空的，或解析失敗，用目前溫度補滿
    if (cwaHourlyTemps.isEmpty) {
      cwaHourlyTemps = List.filled(24, currentTemp);
    }
    // 強制截斷或補齊至 24 筆 (雙重保險)
    if (cwaHourlyTemps.length > 24) cwaHourlyTemps = cwaHourlyTemps.sublist(0, 24);
    while (cwaHourlyTemps.length < 24) cwaHourlyTemps.add(cwaHourlyTemps.isNotEmpty ? cwaHourlyTemps.last : currentTemp);

    // --- 逐時降雨 (Hourly Rain) ---
    List<int> cwaHourlyRainChance = [];
    int currentRainChance = 0;

    try {
      var pop3hNode = weatherElements.firstWhere(
        (e) => ['PoP3h', '3小時降雨機率'].contains(_safeGet(e, 'ElementName')),
        orElse: () => null,
      );

      if (pop3hNode != null) {
        var timeList = _safeGetList(pop3hNode, 'Time');
        cwaHourlyRainChance = expandPoP3hToHourly(timeList);

        if (cwaHourlyRainChance.length > 24) {
          cwaHourlyRainChance = cwaHourlyRainChance.sublist(0, 24);
        }

        // 🔥 修正：如果天氣說有雨，但前 3 小時機率都是 0，就推估機率
        if (wx.contains('雨') && cwaHourlyRainChance.isNotEmpty) {
          int estimatedPop = _estimateRainFromWx(wx);
          for (int i = 0; i < 3 && i < cwaHourlyRainChance.length; i++) {
            if (cwaHourlyRainChance[i] == 0) {
              cwaHourlyRainChance[i] = estimatedPop;
              print("   🔧 修正第 $i 小時降雨機率: 0% -> $estimatedPop% (依據天氣描述)");
            }
          }
        }

        if (cwaHourlyRainChance.isNotEmpty) {
          currentRainChance = cwaHourlyRainChance.first;
        }
      }
    } catch (e) {
      print("   ❌ PoP3h 解析失敗: $e");
    }

    if (cwaHourlyRainChance.isEmpty) {
      cwaHourlyRainChance = List.filled(24, 0);
    }

    // 2️⃣ 🔥 關鍵：提前計算 openWeatherMapCode（在使用它之前）
    int openWeatherMapCode = 800; // 預設值

    // 先做第一次同步
    if (cwaHourlyRainChance.isNotEmpty) {
      currentRainChance = cwaHourlyRainChance.first;
    }

    // 如果文字說有雨但機率還是 0（雙重保險）
    if (wx.contains('雨') && currentRainChance == 0) {
      currentRainChance = 15;
    }

    // ✅ 現在計算 openWeatherMapCode（此時 currentRainChance 已經正確）
    openWeatherMapCode = decideConditionCode(wx, currentRainChance);

    print("🎯 提前計算大圖示: code=$openWeatherMapCode, 降雨=$currentRainChance%");
    

    // --- 未來 7 天預報 (從已解析的逐時溫度推算) ---
    print("📅 開始解析 7 天預報 (從逐時溫度推算)...");
    List<DailyWeather> dailyForecasts = [];

    try {
      var wxNode = weatherElements.firstWhere(
        (e) => ['Wx', '天氣現象'].contains(_safeGet(e, 'ElementName')), 
        orElse: () => null
      );
      var popNode = weatherElements.firstWhere(
        (e) => ['PoP12h', '12小時降雨機率'].contains(_safeGet(e, 'ElementName')), 
        orElse: () => null
      );

      // 🔥 關鍵改動：直接使用已經解析好的 cwaHourlyTemps
      Map<String, List<double>> dayTemps = {};
      
      // 將 24 小時的溫度按日期分組
      DateTime now = DateTime.now();
      for (int i = 0; i < cwaHourlyTemps.length; i++) {
        DateTime time = now.add(Duration(hours: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(time);
        
        dayTemps.putIfAbsent(dateKey, () => []).add(cwaHourlyTemps[i]);
      }
      
      print("📊 每日溫度資料: ${dayTemps.map((k, v) => MapEntry(k, '${v.reduce((a,b) => a<b?a:b).toStringAsFixed(1)}~${v.reduce((a,b) => a>b?a:b).toStringAsFixed(1)}°C'))}");

      // 解析天氣現象 (取白天為主)
      Map<String, String> dayWx = {};
      if (wxNode != null) {
        var timeList = _safeGetList(wxNode, 'Time');
        
        for (var item in timeList) {
          String startTime = _safeGet(item, 'StartTime')?.toString() ?? "";
          
          if (startTime.length >= 10) {
            String dateKey = startTime.substring(0, 10);
            
            // 優先使用白天（06:00-18:00）的天氣
            bool isDaytime = startTime.contains('06:00') || 
                            startTime.contains('09:00') || 
                            startTime.contains('12:00') ||
                            startTime.contains('15:00');
            
            if (!dayWx.containsKey(dateKey) || isDaytime) {
              var valList = _safeGetList(item, 'ElementValue');
              if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
              
              if (valList.isNotEmpty) {
                String wx = (_safeGet(valList[0], 'Weather') ?? 
                            _safeGet(valList[0], 'weather') ?? 
                            _safeGet(valList[0], 'value') ?? 
                            "多雲").toString();
                dayWx[dateKey] = wx;
              }
            }
          }
        }
      }

      // 解析降雨機率 (取最大值)
      Map<String, int> dayPop = {};
      if (popNode != null) {
        var timeList = _safeGetList(popNode, 'Time');
        
        for (var item in timeList) {
          String startTime = _safeGet(item, 'StartTime')?.toString() ?? "";
          
          if (startTime.length >= 10) {
            String dateKey = startTime.substring(0, 10);
            
            var valList = _safeGetList(item, 'ElementValue');
            if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
            
            if (valList.isNotEmpty) {
              var popVal = _safeGet(valList[0], 'value') ?? 
                          _safeGet(valList[0], 'PoP');
              int pop = int.tryParse(popVal?.toString() ?? '0') ?? 0;
              
              if (!dayPop.containsKey(dateKey) || pop > dayPop[dateKey]!) {
                dayPop[dateKey] = pop;
              }
            }
          }
        }
      }

      // 組合成 DailyWeather 物件
      List<String> sortedDates = dayTemps.keys.toList()..sort();
      
      for (String dateKey in sortedDates) {
        if (dayTemps[dateKey]!.isNotEmpty) {
          DateTime date = DateTime.parse(dateKey);
          
          // 從逐時溫度計算高低溫
          List<double> temps = dayTemps[dateKey]!;
          double maxT = temps.reduce((a, b) => a > b ? a : b);
          double minT = temps.reduce((a, b) => a < b ? a : b);
          
          String wxText = dayWx[dateKey] ?? "多雲";
          int pop = dayPop[dateKey] ?? _estimateRainFromWx(wxText);
          
          // 如果是今天，使用更精準的當前降雨機率
          String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
          if (dateKey == todayKey) {
            pop = currentRainChance;
            wxText = wx; // 使用當前天氣描述
          }

          dailyForecasts.add(DailyWeather(
            date: date,
            maxTemp: maxT,
            minTemp: minT,
            rainChance: pop,
            conditionCode: _wxTextToOpenWeatherCode(wxText),
          ));
          
          print("📅 $dateKey: ${minT.toStringAsFixed(1)}°C ~ ${maxT.toStringAsFixed(1)}°C, 降雨 $pop%, $wxText");
        }
      }

    } catch (e) {
      print("❌ 解析 7 天預報失敗: $e");
    }

    // 如果 CWA 資料不足 7 天，補充 OpenWeather 的預報
    if (dailyForecasts.length < 7 && baseData.dailyForecasts != null) {
      print("⚠️ CWA 預報只有 ${dailyForecasts.length} 天，補充 OpenWeather 至 7 天");
      
      // 找出 CWA 最後一天的日期
      DateTime lastCwaDate = dailyForecasts.isNotEmpty 
          ? dailyForecasts.last.date 
          : DateTime.now();
      
      for (var owmDay in baseData.dailyForecasts!) {
        // 只補充 CWA 沒有的未來日期
        if (owmDay.date.isAfter(lastCwaDate) && dailyForecasts.length < 7) {
          dailyForecasts.add(owmDay);
          print("📅 補充 ${DateFormat('yyyy-MM-dd').format(owmDay.date)}: "
                "${owmDay.minTemp.toStringAsFixed(1)}°C ~ ${owmDay.maxTemp.toStringAsFixed(1)}°C "
                "(OpenWeather)");
        }
      }
    }

   // --- 逐時天氣圖示與機率校正 (精準修正版) ---
  List<int> hourlyConditionCodes = [];

  try {
    var wxNode = weatherElements.firstWhere(
      (e) => ['Wx', '天氣現象'].contains(_safeGet(e, 'ElementName')), 
      orElse: () => null
    );

    if (wxNode != null) {
      var wxTimeList = _safeGetList(wxNode, 'Time');
      
      // 🔥 移到迴圈外面，只印一次！
      print("📋 天氣現象資料筆數: ${wxTimeList.length}");
      for (int idx = 0; idx < 3 && idx < wxTimeList.length; idx++) {
        var item = wxTimeList[idx];
        print("  第 $idx 筆: StartTime=${_safeGet(item, 'StartTime')}, "
              "EndTime=${_safeGet(item, 'EndTime')}");
        
        // 順便印出天氣內容
       var valList = _safeGetList(item, 'ElementValue');
        if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');

        String wx = "未知";
        if (valList.isNotEmpty) {
          var rawValue = _safeGet(valList[0], 'value') ?? 
                        _safeGet(valList[0], 'Value');
          
          if (rawValue != null && rawValue.toString().isNotEmpty) {
            wx = rawValue.toString();
          }
          
          // 🔥 加入更多可能的欄位名稱
          if (wx == "未知") {
            var weatherValue = _safeGet(valList[0], 'Weather') ?? 
                              _safeGet(valList[0], 'weather');
            if (weatherValue != null && weatherValue.toString().isNotEmpty) {
              wx = weatherValue.toString();
            }
          }
        }

        print("    → 天氣: '$wx' (valList長度: ${valList.length})");
        if (valList.isNotEmpty) {
          print("    → valList[0]的所有key: ${(valList[0] as Map).keys.toList()}");
        }
      }
      
      // 開始處理 24 小時
      for (int i = 0; i < 24; i++) {
        int wxIndex = i ~/ 3;
        
        if (wxIndex >= wxTimeList.length) {
          wxIndex = wxTimeList.length - 1;
        }
        
        var item = wxTimeList[wxIndex];
        var valList = _safeGetList(item, 'ElementValue');
        if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
        
        String hourlyWxText = valList.isNotEmpty 
          ? (_safeGet(valList[0], 'Weather') ??  // 🔥 改成 Weather
            _safeGet(valList[0], 'weather') ??  // 🔥 也試試小寫
            _safeGet(valList[0], 'value') ?? 
            _safeGet(valList[0], 'Value') ?? 
            "多雲").toString() 
          : "多雲";
        
        int pop = (i < cwaHourlyRainChance.length) ? cwaHourlyRainChance[i] : 0;

        // 只有在尚未修正過且文字有雨時才補 15%
        if (hourlyWxText.contains('雨') && pop == 0) {
          pop = 15;
          if (i < cwaHourlyRainChance.length) {
            cwaHourlyRainChance[i] = 15;
          }
        }

        int code = decideConditionCode(hourlyWxText, pop);
        hourlyConditionCodes.add(code);
        
        // 🔥 詳細 debug（前 8 小時）
        if (i < 8) {
          print("⏰ 第 $i 小時: 使用第 $wxIndex 筆 → wx='$hourlyWxText', pop=$pop%, code=$code");
        }
      }
    }

    // 最後再次同步
    if (cwaHourlyRainChance.isNotEmpty) {
      currentRainChance = cwaHourlyRainChance.first;
    }
    
    if (wx.contains('雨') && currentRainChance == 0) {
      currentRainChance = 15;
    }

    openWeatherMapCode = decideConditionCode(wx, currentRainChance);

  } catch (e) {
    print("❌ 解析逐時圖示失敗: $e");
    hourlyConditionCodes = List.filled(24, openWeatherMapCode);
  }

  if (hourlyConditionCodes.isEmpty) {
    hourlyConditionCodes = List.filled(24, openWeatherMapCode);
  }

  print("🎯 最終結果: code=$openWeatherMapCode, 降雨=$currentRainChance%");
  print("🎯 逐時前8筆 codes: ${hourlyConditionCodes.take(8).toList()}");
  print("🎯 逐時前8筆 rain: ${cwaHourlyRainChance.take(8).toList()}");


    // 5️⃣ 回傳 WeatherModel
    return WeatherModel(
      temperature: currentTemp,
      tempMax: cwaHourlyTemps.reduce((a, b) => a > b ? a : b),
      tempMin: cwaHourlyTemps.reduce((a, b) => a < b ? a : b),
      description: wx,
      areaName: "$city ${_safeGet(targetLocation, 'LocationName')}",
      conditionCode: openWeatherMapCode, // ✅ 使用正確計算的值
      hourlyConditionCodes: hourlyConditionCodes,
      sunrise: baseData.sunrise,
      sunset: baseData.sunset,
      humidity: humidity,
      windSpeed: windSpeed,
      date: DateTime.now(),
      hourlyTemps: cwaHourlyTemps,
      rainChance: currentRainChance, // ✅ 使用正確修正的值
      hourlyRainChance: cwaHourlyRainChance,
      dewPoint: baseData.dewPoint,
      feelsLike: baseData.feelsLike,
      windDirection: baseData.windDirection,
      weatherForecast: null,
      dailyForecasts: dailyForecasts,
    );
  }

  
  // ===============================================================
  // 4. Helpers & Mappings
  // ===============================================================

  dynamic _safeGet(dynamic data, String key) {
    if (data is! Map) return null;
    if (data.containsKey(key)) return data[key];
    return null;
  }
  
  List _safeGetList(dynamic data, String key) {
    var val = _safeGet(data, key);
    return (val is List) ? val : [];
  }

  // 對應 CWA 代碼到 OpenWeather
  int _mapCwaCodeToOpenWeather(int cwaCode) {
    if (cwaCode == 1) return 800; 
    if (cwaCode >= 2 && cwaCode <= 3) return 801; 
    if (cwaCode == 4) return 803; 
    if (cwaCode >= 5 && cwaCode <= 7) return 804; 
    if (cwaCode >= 8 && cwaCode <= 14) return 500; 
    if (cwaCode >= 15 && cwaCode <= 18) return 200; 
    if (cwaCode >= 19 && cwaCode <= 22) return 201; 
    if (cwaCode >= 29) return 502; 
    if (cwaCode >= 24 && cwaCode <= 28) return 700; 
    return 802; 
  }

  int _calculateRainChanceFromOWMCode(int code) {
      if (code >= 200 && code < 300) return 85; 
      if (code >= 300 && code < 400) return 65; 
      if (code >= 500 && code < 600) return 75; 
      if (code == 800) return 10; 
      return 20;
  }

  double _calculateFeelsLike(double temp, double windSpeed) {
    if (temp < 10 && windSpeed > 3) {
      return 13.12 + 0.6215 * temp - 11.37 * (windSpeed * 3.6).abs().clamp(0, 100) + 0.3965 * temp * (windSpeed * 3.6).abs().clamp(0, 100);
    }
    return temp - (windSpeed * 0.5);
  }

  double _calculateDewPoint(double temp, double humidity) {
    double a = 17.27; double b = 237.7;
    double alpha = ((a * temp) / (b + temp)) + (humidity / 100.0).abs();
    double alphaNatLog = alpha > 0 ? 2.303 * (alpha / 10).abs() : 0.0;
    return (b * alphaNatLog) / (a - alphaNatLog);
  }

  String _windDegreeToDirection(double? degree) {
    if (degree == null) return '未知';
    if (degree >= 337.5 || degree < 22.5) return '北風';
    if (degree >= 22.5 && degree < 67.5) return '東北風';
    if (degree >= 67.5 && degree < 112.5) return '東風';
    if (degree >= 112.5 && degree < 157.5) return '東南風';
    if (degree >= 157.5 && degree < 202.5) return '南風';
    if (degree >= 202.5 && degree < 247.5) return '西南風';
    if (degree >= 247.5 && degree < 292.5) return '西風';
    if (degree >= 292.5 && degree < 337.5) return '西北風';
    return '未知';
  }

  // 🔥 新增：將天氣現象中文轉換成 OpenWeather 代碼
  int _wxTextToOpenWeatherCode(String wxText) {
    if (wxText.isEmpty) return 800;
    
    // 晴天
    if (wxText.contains('晴')) return 800;
    
    // 多雲
    if (wxText.contains('多雲')) return 803;
    if (wxText.contains('陰')) return 804;
    
    // 雨天
    if (wxText.contains('雷')) return 200; // 雷雨
    if (wxText.contains('大雨')) return 502;
    if (wxText.contains('豪雨')) return 503;
    if (wxText.contains('陣雨') || wxText.contains('短暫雨')) return 500;
    if (wxText.contains('雨')) return 501;
    
    // 霧霾
    if (wxText.contains('霧') || wxText.contains('霾')) return 701;
    
    return 802; // 預設為少雲
  }

  // 🔥 新增：根據天氣現象文字推估降雨機率
  int _estimateRainFromWx(String wxText) {
    if (wxText.contains('雷雨') || wxText.contains('大雨')) return 80;
    if (wxText.contains('陣雨') || wxText.contains('短暫雨')) return 60;
    if (wxText.contains('雨')) return 50;
    if (wxText.contains('多雲') || wxText.contains('陰')) return 20;
    if (wxText.contains('晴')) return 10;
    return 15; // 預設值
  }

  int decideConditionCode(String wx, int pop) {
    if (wx.contains('雷')) return 200;
    
    if (wx.contains('雨')) {
      if (pop >= 70 || wx.contains('大雨') || wx.contains('豪雨')) return 502; 
      return 500;
    }

    // 🔥 關鍵：加入這段
    if (pop >= 30) {
      if (pop >= 70) return 502;
      return 500;
    }

    if (wx.contains('陰')) return 804;
    if (wx.contains('多雲')) {
      if (wx.contains('晴')) return 801; 
      return 803; 
    }
    if (wx.contains('晴')) return 800; 
    
    return _wxTextToOpenWeatherCode(wx);
  }

  // 🔥 這裡的 Helper 也要同步更新，確保 PoP 解析正確
  List<int> expandPoP3hToHourly(List timeList) {
    List<int> hourly = [];
    List<int> popValues = [];

    for (var item in timeList) {
      var valList = item['ElementValue'] ?? item['elementValue'] ?? [];
      if (valList.isNotEmpty) {
        String? v = valList[0]['value']?.toString() ?? valList[0]['Value']?.toString();
        popValues.add(int.tryParse(v ?? '0') ?? 0);
      }
    }

    if (popValues.isEmpty) return List.filled(24, 0);

    // CWA 的 PoP3h 通常代表未來 3 小時的機率
    // 我們簡單地將每 3 小時的值填入該區間
    for (int pop in popValues) {
      for (int h = 0; h < 3; h++) {
        if (hourly.length < 24) {
          hourly.add(pop); 
        }
      }
    }

    // 如果數量不足 24 小時，用最後一個值補齊
    while (hourly.length < 24) {
      hourly.add(popValues.last);
    }

    return hourly;
  }

  int hourlyIconFromWxAndPop(String wx, int pop) {
    // 優先判斷雨
    if (wx.contains('雨') || pop >= 30) {
      if (pop >= 70 || wx.contains('大雨')) return 502;
      return 500; 
    }
    
    // 判斷晴/雲
    if (wx.contains('晴')) {
      if (wx.contains('多雲')) return 801;
      return 800;
    }
    
    if (wx.contains('陰')) return 804;
    if (wx.contains('多雲')) return 803;
    
    return 800;
  }

  // 🔥 新增：展開溫度資料 (處理 3 小時一筆的情況)
  List<double> _expandTempToHourly(List timeList) {
    if (timeList.isEmpty) return [];
    
    print("🔍 _expandTempToHourly 收到 ${timeList.length} 筆資料");
    
    List<double> temps3h = [];
    
    for (int i = 0; i < timeList.length; i++) {
      var item = timeList[i];
      
      // 🔥 改進：同時嘗試多種可能的欄位名稱
      String startTime = (_safeGet(item, 'StartTime') ?? 
                        _safeGet(item, 'startTime') ?? 
                        _safeGet(item, 'DataTime') ?? 
                        _safeGet(item, 'dataTime') ?? "").toString();
      
      String endTime = (_safeGet(item, 'EndTime') ?? 
                      _safeGet(item, 'endTime') ?? "").toString();
      
      var valList = _safeGetList(item, 'ElementValue');
      if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
      
      if (valList.isNotEmpty) {
        var val = _safeGet(valList[0], 'value') ?? 
                  _safeGet(valList[0], 'Value') ?? 
                  _safeGet(valList[0], 'Temperature');
        
        double temp = double.tryParse(val?.toString() ?? '0') ?? 0.0;
        temps3h.add(temp);
        
        // 🔥 改進：只在有時間資料時才印出
        if (i < 10) {
          if (startTime.isNotEmpty) {
            print("  [$i] ${startTime.substring(0, startTime.length > 16 ? 16 : startTime.length)} → ${temp.toStringAsFixed(2)}°C");
          } else {
            print("  [$i] (無時間資訊) → ${temp.toStringAsFixed(2)}°C");
          }
        }
      }
    }
    
    print("✅ 成功解析 ${temps3h.length} 筆溫度");
    
    if (temps3h.isEmpty) return [];
    
    // 🔥 線性插值產生逐時溫度
    List<double> hourly = [];
    
    for (int i = 0; i < temps3h.length - 1; i++) {
      double startTemp = temps3h[i];
      double endTemp = temps3h[i + 1];
      
      // 產生 3 個小時的溫度（線性變化）
      for (int h = 0; h < 3; h++) {
        if (hourly.length < 24) {
          double ratio = h / 3.0;
          double interpolated = startTemp + (endTemp - startTemp) * ratio;
          hourly.add(interpolated);
        }
      }
    }
    
    // 補上最後一筆
    while (hourly.length < 24 && temps3h.isNotEmpty) {
      hourly.add(temps3h.last);
    }
    
    // 🔥 新增：印出最終的逐時溫度
    print("📊 逐時溫度 (前 24 小時):");
    for (int i = 0; i < hourly.length && i < 24; i += 3) {  // 每 3 小時印一次
      print("  第 $i 小時: ${hourly[i].toStringAsFixed(2)}°C");
    }
    
    return hourly;
  }
}