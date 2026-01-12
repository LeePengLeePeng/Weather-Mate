import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:weather/weather.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'weather_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math'; // 修正: 需要引入 math 來計算 pow 或 log (雖然你的露點公式用的是自定義運算，但引入較保險)

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

  Future<Map<String, double>?> _fetchCityMinMaxT(String cityName) async {
    try {
      final cityMapping = {
        '臺北市': '臺北市', '新北市': '新北市', '桃園市': '桃園市',
        '臺中市': '臺中市', '臺南市': '臺南市', '高雄市': '高雄市',
        '基隆市': '基隆市', '新竹市': '新竹市', '新竹縣': '新竹縣',
        '苗栗縣': '苗栗縣', '彰化縣': '彰化縣', '南投縣': '南投縣',
        '雲林縣': '雲林縣', '嘉義市': '嘉義市', '嘉義縣': '嘉義縣',
        '屏東縣': '屏東縣', '宜蘭縣': '宜蘭縣', '花蓮縣': '花蓮縣',
        '臺東縣': '臺東縣', '澎湖縣': '澎湖縣', '金門縣': '金門縣',
        '連江縣': '連江縣',
      };
      
      String normalizedCity = cityName.replaceAll('台', '臺');
      if (!cityMapping.containsKey(normalizedCity)) {
        print("⚠️ $cityName 不在 F-C0032-001 支援範圍");
        return null;
      }
      
      final uri = Uri.https(
        'opendata.cwa.gov.tw',
        '/api/v1/rest/datastore/F-C0032-001',
        {
          'Authorization': cwaApiKey,
          'locationName': cityMapping[normalizedCity],
        },
      );
      
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        print("❌ F-C0032-001 API Error: ${response.statusCode}");
        return null;
      }
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] != 'true') {
        print("❌ F-C0032-001 API 回傳錯誤");
        return null;
      }
      
      var records = _safeGet(data, 'records');
      var locations = _safeGetList(records, 'location');
      
      if (locations.isEmpty) return null;
      
      var location = locations[0];
      var weatherElements = _safeGetList(location, 'weatherElement');
      
      final now = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(now);
      
      double? maxT;
      double? minT;
      
      // MaxT
      var maxTNode = weatherElements.firstWhere(
        (e) => _safeGet(e, 'elementName') == 'MaxT',
        orElse: () => null,
      );
      
      if (maxTNode != null) {
        var timeList = _safeGetList(maxTNode, 'time');
        for (var item in timeList) {
          var startTime = _safeGet(item, 'startTime')?.toString() ?? '';
          var endTime = _safeGet(item, 'endTime')?.toString() ?? '';
          
          if (startTime.startsWith(todayKey) || endTime.startsWith(todayKey)) {
            var parameter = _safeGet(item, 'parameter');
            var value = _safeGet(parameter, 'parameterName')?.toString();
            if (value != null) {
              maxT = double.tryParse(value);
              break; 
            }
          }
        }
      }
      
      // MinT
      var minTNode = weatherElements.firstWhere(
        (e) => _safeGet(e, 'elementName') == 'MinT',
        orElse: () => null,
      );
      
      if (minTNode != null) {
        var timeList = _safeGetList(minTNode, 'time');
        for (var item in timeList) {
          var startTime = _safeGet(item, 'startTime')?.toString() ?? '';
          var endTime = _safeGet(item, 'endTime')?.toString() ?? '';
          
          if (startTime.startsWith(todayKey) || endTime.startsWith(todayKey)) {
            var parameter = _safeGet(item, 'parameter');
            var value = _safeGet(parameter, 'parameterName')?.toString();
            if (value != null) {
              minT = double.tryParse(value);
              break; 
            }
          }
        }
      }
      
      if (maxT != null && minT != null) {
        return {'max': maxT, 'min': minT};
      }
      
      return null;
      
    } catch (e) {
      print("❌ 取得 F-C0032-001 MinT/MaxT 失敗: $e");
      return null;
    }
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

      WeatherModel weather = await getWeather(lat, lon);
      return _generateAIReport(locationName, weather);
    } catch (e) {
      return "查詢 $locationName 天氣時發生錯誤: $e";
    }
  }

  String _generateAIReport(String city, WeatherModel w) {
    StringBuffer sb = StringBuffer();

    sb.writeln("【地點】：$city (${w.areaName})");
    sb.writeln(
        "【目前】：${w.description}, 氣溫 ${w.temperature}°C, 體感 ${w.feelsLike}°C, 降雨機率 ${w.rainChance}%");

    // 2. 未來 12 小時
    sb.writeln("\n--- 未來 12 小時預報 (短期) ---");
    DateTime now = DateTime.now();

    int hourlyCount = w.hourlyTemps.length;
    if (w.hourlyRainChance.length < hourlyCount) hourlyCount = w.hourlyRainChance.length;
    if (hourlyCount > 12) hourlyCount = 12;

    for (int i = 0; i < hourlyCount; i += 3) {
      DateTime time = now.add(Duration(hours: i));
      String timeStr = DateFormat('MM/dd HH:mm').format(time);
      double temp = w.hourlyTemps[i];
      int rain = w.hourlyRainChance[i];
      sb.writeln("$timeStr -> 溫 ${temp.toStringAsFixed(1)}°C, 雨 $rain%");
    }

    // 3. 今日 + 未來5天（共6天）
    if (w.dailyForecasts != null && w.dailyForecasts!.isNotEmpty) {
      sb.writeln("\n--- 今日 + 未來 5 天預報 (共 6 天) ---");
      for (var d in w.dailyForecasts!) {
        String dateStr = DateFormat('MM/dd (E)', 'zh_TW').format(d.date);
        sb.writeln(
            "📅 $dateStr : 低溫 ${d.minTemp.toStringAsFixed(1)}°C / 高溫 ${d.maxTemp.toStringAsFixed(1)}°C, 降雨機率 ${d.rainChance}%");
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

    WeatherModel openWeatherData = await _fetchFromOpenWeather(lat, lon);

    if (_isInTaiwan(lat, lon)) {
      try {
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
    WeatherFactory wf =
        WeatherFactory(openWeatherApiKey, language: Language.CHINESE_TRADITIONAL);

    Weather current = await wf.currentWeatherByLocation(lat, lon);
    List<Weather> forecast = await wf.fiveDayForecastByLocation(lat, lon);

    // 1. 逐時資料 (24hr)
    List<double> hourlyTemps = [];
    List<int> hourlyRainChances = [];
    List<int> hourlyCodes = [];

    double currentTemp = current.temperature?.celsius ?? 0;
    int currentPop = _calculateRainChanceFromOWMCode(current.weatherConditionCode ?? 800);
    String currentDesc = current.weatherDescription ?? "";
    
    hourlyTemps.add(currentTemp);
    hourlyRainChances.add(currentPop);
    hourlyCodes.add(hourlyIconFromWxAndPop(currentDesc, currentPop));

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

    // 2. 每日預報分組
    Map<String, List<Weather>> groupedByDay = {};
    DateTime now = DateTime.now();
    String todayKey = DateFormat('yyyy-MM-dd').format(now);
    groupedByDay[todayKey] = [current]; // 先放入當前天氣

    for (var w in forecast) {
      if (w.date != null) {
        String dateKey = DateFormat('yyyy-MM-dd').format(w.date!);
        groupedByDay.putIfAbsent(dateKey, () => []).add(w);
      }
    }

    // =======================================================
    // 🔥 修正邏輯開始：計算今日 API 預測的最高/最低溫
    // =======================================================
    double apiTodayMax = current.temperature?.celsius ?? 0;
    double apiTodayMin = current.temperature?.celsius ?? 0;

    // 從 forecast 列表中找出所有「屬於今天」的時段，更新 Max/Min
    if (groupedByDay.containsKey(todayKey)) {
      var todayList = groupedByDay[todayKey]!;
      for (var w in todayList) {
        double t = w.temperature?.celsius ?? current.temperature?.celsius ?? 0;
        double max = w.tempMax?.celsius ?? t;
        double min = w.tempMin?.celsius ?? t;
        
        if (max > apiTodayMax) apiTodayMax = max;
        if (min < apiTodayMin) apiTodayMin = min;
      }
    }
    // =======================================================
    // 🔥 修正邏輯結束
    // =======================================================

    List<DailyWeather> dailyForecasts = [];
    List<String> sortedKeys = groupedByDay.keys.toList()..sort();

    // 🔥 使用 DailyTempManager
    final prefs = await SharedPreferences.getInstance();
    final cityName = current.areaName ?? "unknown";
    final tempManager = DailyTempManager(prefs, 'owm', cityKey: cityName);
        
    // 3. 獲取緩存的溫度（這裡可能會拿到當前溫度作為預設值）
    final todayMinMax = await tempManager.getTodayMinMax(currentTemp);
    
    // 4. 🔥 結合「緩存(過去)」與「API(未來)」來決定最終今日溫度
    //    如果 API 看到的未來溫度比緩存的高，就更新上去
    double finalMaxT = todayMinMax['max']!;
    double finalMinT = todayMinMax['min']!;

    if (apiTodayMax > finalMaxT) finalMaxT = apiTodayMax;
    if (apiTodayMin < finalMinT) finalMinT = apiTodayMin;

    // 將修正後的數值存回 Manager，以免下次刷新又變回舊的
    if (finalMaxT != todayMinMax['max'] || finalMinT != todayMinMax['min']) {
      await tempManager.updateTodayRaw(finalMaxT, finalMinT);
    }

    // 生成 dailyForecasts
    for (int i = 0; i < 6; i++) {
      String dateKey;
      List<Weather> dayData;

      if (i < sortedKeys.length) {
        dateKey = sortedKeys[i];
        dayData = groupedByDay[dateKey]!;
      } else {
        DateTime lastDate = DateTime.parse(sortedKeys.last).add(Duration(days: i - sortedKeys.length + 1));
        dateKey = DateFormat('yyyy-MM-dd').format(lastDate);
        dayData = groupedByDay[sortedKeys.last]!;
      }

      double maxT, minT;
      
      if (i == 0) {
        // ✅ 今天：使用我們剛才修正過的最終值
        maxT = finalMaxT;
        minT = finalMinT;
      } else {
        // 未來幾天：從 API 計算
        maxT = dayData
            .map((e) => e.tempMax?.celsius ?? e.temperature?.celsius ?? 0)
            .reduce((a, b) => a > b ? a : b);
        minT = dayData
            .map((e) => e.tempMin?.celsius ?? e.temperature?.celsius ?? 0)
            .reduce((a, b) => a < b ? a : b);
        
        // 如果是明天，保存預測
        if (i == 1) {
          await tempManager.saveTomorrowForecast(maxT, minT);
        }
      }

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

    return WeatherModel(
      latitude: lat,
      longitude: lon,
      temperature: current.temperature?.celsius ?? 0,
      tempMax: finalMaxT, // 使用修正後的值
      tempMin: finalMinT, // 使用修正後的值
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
  // 3. 處理 CWA 台灣資料
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
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('CWA API Error: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data['success'] != 'true') throw Exception("CWA API 回傳錯誤");

    var locationsNode = _safeGetList(_safeGet(data, 'records'), 'Locations')[0];
    List locationListRaw = _safeGetList(locationsNode, 'Location');

    // 3. 尋找對應行政區
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
    } catch (_) {
      targetLocation = locationListRaw[0];
    }
    if (targetLocation == null) targetLocation = locationListRaw[0];

    final weatherElements = _safeGetList(targetLocation, 'WeatherElement');
    
    // --- Helper: 通用取值 ---
    String? getElementValue(List<String> possibleNames) {
      try {
        var el = weatherElements.firstWhere(
          (e) => possibleNames.contains(_safeGet(e, 'ElementName')),
          orElse: () => null,
        );
        if (el == null) return null;

        var timeList = _safeGetList(el, 'Time');
        if (timeList.isEmpty) return null;

        var item = timeList[0];
        var valList = _safeGetList(item, 'ElementValue');
        if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
        if (valList.isEmpty) return null;

        return _readCwaValue(valList[0]);
      } catch (_) {
        return null;
      }
    }

    // 4. 基礎數值
    double currentTemp = double.tryParse(getElementValue(['T', '溫度']) ?? '') ?? baseData.temperature;
    double humidity = double.tryParse(getElementValue(['RH', '相對濕度']) ?? '') ?? baseData.humidity;
    double windSpeed = double.tryParse(getElementValue(['WindSpeed', '風速']) ?? '') ?? baseData.windSpeed;

    String wx = baseData.description;
    try {
      var wxNode = weatherElements.firstWhere(
        (e) => ['Wx', '天氣現象'].contains(_safeGet(e, 'ElementName')),
        orElse: () => null,
      );
      if (wxNode != null) {
        var wxTimeList = _safeGetList(wxNode, 'Time');
        if (wxTimeList.isNotEmpty) {
          var item = wxTimeList[0];
          var valList = _safeGetList(item, 'ElementValue');
          if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
          if (valList.isNotEmpty) {
            wx = (_safeGet(valList[0], 'Weather') ??
                    _safeGet(valList[0], 'weather') ??
                    _safeGet(valList[0], 'value') ??
                    _safeGet(valList[0], 'Value') ??
                    "多雲")
                .toString();
          }
        }
      }
    } catch (e) {
      print("⚠️ 取得當前天氣描述失敗: $e");
    }

    print("📊 基礎數值解析: 溫=$currentTemp, 濕=$humidity, 風=$windSpeed, 況=$wx");
    

    // ===========================================================
    // 解析 CWA tempPoints
    // ===========================================================
    List<MapEntry<DateTime, double>> tempPoints = [];
      try {
        var tempNode = weatherElements.firstWhere(
          (e) => ['T', '溫度'].contains(_safeGet(e, 'ElementName')),
          orElse: () => null,
        );
        if (tempNode != null) {
          var timeList = _safeGetList(tempNode, 'Time');
          tempPoints = _parseCwaTempPoints(timeList);
        }
      } catch (_) {}

      // 逐時溫度
      List<double> cwaHourlyTemps = [];
      if (tempPoints.isNotEmpty) {
        final now = DateTime.now();
        cwaHourlyTemps.add(currentTemp);
        final future = tempPoints.where((p) => !p.key.isBefore(now)).toList();
        for (var point in future) {
          if (cwaHourlyTemps.length >= 24) break;
          cwaHourlyTemps.add(point.value);
        }
      }
      if (cwaHourlyTemps.isEmpty) cwaHourlyTemps = List.filled(24, currentTemp);
      while (cwaHourlyTemps.length < 24) cwaHourlyTemps.add(cwaHourlyTemps.last);
      if (cwaHourlyTemps.length > 24) cwaHourlyTemps = cwaHourlyTemps.sublist(0, 24);

      // 逐時降雨
     List<int> cwaHourlyRainChance = [];
      int currentRainChance = 0;

      try {
        var pop3hNode = weatherElements.firstWhere(
          (e) => ['PoP3h', '3小時降雨機率'].contains(_safeGet(e, 'ElementName')),
          orElse: () => null,
        );
        
        if (pop3hNode != null) {
          var timeList = _safeGetList(pop3hNode, 'Time');
          final now = DateTime.now();
          
          // ✅ 先找出「當前時段」的降雨機率
          for (var item in timeList) {
            final startStr = _safeGet(item, 'StartTime')?.toString() ?? '';
            final endStr = _safeGet(item, 'EndTime')?.toString() ?? '';
            
            final start = DateTime.tryParse(startStr);
            final end = DateTime.tryParse(endStr);
            
            if (start != null && end != null) {
              // 如果「現在」落在這個時段內
              if (!now.isBefore(start) && now.isBefore(end)) {
                var valList = _safeGetList(item, 'ElementValue');
                if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
                
                if (valList.isNotEmpty) {
                  final raw = _readCwaValue(valList[0]) ?? '0';
                  currentRainChance = int.tryParse(raw) ?? 0;
                  break;
                }
              }
            }
          }
          
          // ✅ 展開成 24 小時（第一筆會是當前時段的機率）
          cwaHourlyRainChance = expandPoP3hToHourly(timeList);
          
          if (cwaHourlyRainChance.length > 24) {
            cwaHourlyRainChance = cwaHourlyRainChance.sublist(0, 24);
          }
        }
      } catch (e) {
        print("❌ PoP3h 解析失敗: $e");
      }

      // 預設值處理
      if (cwaHourlyRainChance.isEmpty) {
        cwaHourlyRainChance = List.filled(24, 0);
      }

      if (cwaHourlyRainChance.isNotEmpty) {
        currentRainChance = cwaHourlyRainChance.first;
      }

      // 最後的安全檢查：如果天氣明確說有雨但機率還是 0
      if (wx.contains('雨') && currentRainChance == 0) {
        currentRainChance = _estimateRainFromWx(wx);
        // ✅ 同時更新第一筆
        if (cwaHourlyRainChance.isNotEmpty) {
          cwaHourlyRainChance[0] = currentRainChance;
        }
        print("⚠️ 最終安全檢查：天氣「$wx」但降雨=0，調整為 $currentRainChance%");
      }

    int openWeatherMapCode = decideConditionCode(wx, currentRainChance);

    // ===========================================================
    // 🔥 使用 DailyTempManager
    // ===========================================================
    final prefs = await SharedPreferences.getInstance();
    final cityKey = "$city-$district";
    final tempManager = DailyTempManager(prefs, 'cwa', cityKey: cityKey);

    final todayMinMax = await tempManager.getTodayMinMax(currentTemp);
    double todayMaxTemp = todayMinMax['max']!;
    double todayMinTemp = todayMinMax['min']!;

    // 檢查是否為首次查詢
    bool isFirstQuery = (todayMaxTemp == currentTemp && todayMinTemp == currentTemp);

    // 嘗試從 F-C0032-001 獲取基本範圍
    if (isFirstQuery) {
      final cityMinMaxT = await _fetchCityMinMaxT(city);
      if (cityMinMaxT != null) {
        todayMaxTemp = cityMinMaxT['max']!;
        todayMinTemp = cityMinMaxT['min']!;
        // 這裡僅作變數更新，等等下方會統一做 updateTodayRaw
        print("✅ [CWA] 使用 F-C0032-001 基礎範圍: ${todayMinTemp.toStringAsFixed(1)}~${todayMaxTemp.toStringAsFixed(1)}°C");
      }
    }

    // ===========================================================
    // 🔥 修正邏輯：掃描 CWA 逐時預報 (tempPoints)
    // 如果今天稍晚的鄉鎮預報有更高溫/更低溫，就擴展範圍
    // ===========================================================
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    // 遍歷所有時間點
    for (var entry in tempPoints) {
      // 判斷該時間點是否屬於「今天」
      if (DateFormat('yyyy-MM-dd').format(entry.key) == todayStr) {
        double val = entry.value;
        if (val > todayMaxTemp) todayMaxTemp = val;
        if (val < todayMinTemp) todayMinTemp = val;
      }
    }

    // 將修正後的數值存回，確保一致性
    await tempManager.updateTodayRaw(todayMaxTemp, todayMinTemp);

    // ===========================================================
    // 生成每日預報
    // ===========================================================
    final startDay = DateTime(now.year, now.month, now.day);
    final endExclusive = startDay.add(const Duration(days: 6));
    final tomorrowKey = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));

    final owmDailyMap = <String, DailyWeather>{};
    if (baseData.dailyForecasts != null) {
      for (final d in baseData.dailyForecasts!) {
        final k = DateFormat('yyyy-MM-dd').format(d.date);
        owmDailyMap[k] = d;
      }
    }

    final dayTemps = <String, List<double>>{};
    if (tempPoints.isNotEmpty) {
      for (final p in tempPoints) {
        if (p.key.isBefore(startDay) || !p.key.isBefore(endExclusive)) continue;
        final k = DateFormat('yyyy-MM-dd').format(p.key);
        dayTemps.putIfAbsent(k, () => []).add(p.value);
      }
    }

    final dayWx = <String, String>{};
    try {
      // ... (這段 Wx 解析邏輯保持原本的即可)
      final wxNode = weatherElements.firstWhere(
        (e) => ['Wx', '天氣現象'].contains(_safeGet(e, 'ElementName')),
        orElse: () => null,
      );
      if (wxNode != null) {
        final wxTimeList = _safeGetList(wxNode, 'Time');
        for (final item in wxTimeList) {
          final start = _safeGet(item, 'StartTime')?.toString() ?? '';
          if (start.length < 10) continue;
          final dateKey = start.substring(0, 10);
          final dt = DateTime.tryParse(start);
          if (dt == null) continue;
          if (dt.isBefore(startDay) || !dt.isBefore(endExclusive)) continue;
          
          var valList = _safeGetList(item, 'ElementValue');
          if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
          if (valList.isEmpty) continue;
          
          final wxText = (_safeGet(valList[0], 'Weather') ?? '多雲').toString();
          final isDaytime = start.contains('06:00') || start.contains('09:00') ||
              start.contains('12:00') || start.contains('15:00');
          if (!dayWx.containsKey(dateKey) || isDaytime) {
            dayWx[dateKey] = wxText;
          }
        }
      }
    } catch (_) {}

    final dayPop = <String, int>{};
    void putMaxPop(String k, int v) {
      if (!dayPop.containsKey(k) || v > dayPop[k]!) dayPop[k] = v;
    }

    bool hasPop12h = false;
    try {
      final pop12hNode = weatherElements.firstWhere(
        (e) => ['PoP12h', '12小時降雨機率'].contains(_safeGet(e, 'ElementName')),
        orElse: () => null,
      );
      if (pop12hNode != null) {
        final list = _safeGetList(pop12hNode, 'Time');
        for (final item in list) {
          final start = _safeGet(item, 'StartTime')?.toString() ?? '';
          final dt = DateTime.tryParse(start);
          if (dt == null) continue;
          if (dt.isBefore(startDay) || !dt.isBefore(endExclusive)) continue;

          final k = DateFormat('yyyy-MM-dd').format(dt);

          var valList = _safeGetList(item, 'ElementValue');
          if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
          if (valList.isEmpty) continue;

          final raw = _readCwaValue(valList[0]) ?? '0';
          final pop = int.tryParse(raw) ?? 0;
          putMaxPop(k, pop);
          hasPop12h = true;
        }
      }
    } catch (_) {}

    if (!hasPop12h) {
      try {
        final pop3hNode = weatherElements.firstWhere(
          (e) => ['PoP3h', '3小時降雨機率'].contains(_safeGet(e, 'ElementName')),
          orElse: () => null,
        );
        if (pop3hNode != null) {
          final list = _safeGetList(pop3hNode, 'Time');
          for (final item in list) {
            final start = _safeGet(item, 'StartTime')?.toString() ?? '';
            final dt = DateTime.tryParse(start);
            if (dt == null) continue;
            if (dt.isBefore(startDay) || !dt.isBefore(endExclusive)) continue;

            final k = DateFormat('yyyy-MM-dd').format(dt);

            var valList = _safeGetList(item, 'ElementValue');
            if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
            if (valList.isEmpty) continue;

            final raw = _readCwaValue(valList[0]) ?? '0';
            final pop = int.tryParse(raw) ?? 0;
            putMaxPop(k, pop);
          }
        }
      } catch (_) {}
    }

    List<DailyWeather> dailyForecasts = [];

    for (int offset = 0; offset < 6; offset++) {
      final date = startDay.add(Duration(days: offset));
      final k = DateFormat('yyyy-MM-dd').format(date);

      if (offset == 0) {
        // ✅ 今日：使用剛剛修正後的 todayMaxTemp/todayMinTemp
        dailyForecasts.add(DailyWeather(
          date: date,
          maxTemp: todayMaxTemp,
          minTemp: todayMinTemp,
          rainChance: currentRainChance,
          conditionCode: openWeatherMapCode,
        ));
        
        print("📅 $k (今日修正後): ${todayMinTemp.toStringAsFixed(1)}~${todayMaxTemp.toStringAsFixed(1)}°C");
        
      } else if (dayTemps.containsKey(k) && dayTemps[k]!.isNotEmpty) {
        final temps = dayTemps[k]!;
        double maxT = temps.reduce((a, b) => a > b ? a : b);
        double minT = temps.reduce((a, b) => a < b ? a : b);
        final wxText = dayWx[k] ?? '多雲';
        // 使用預設值，避免 null
        int pop = dayPop[k] ?? 0;
        // 如果機率是 0 但文字描述有雨，就用你寫的函式去推算
        if (pop == 0 && wxText.contains('雨')) {
          pop = _estimateRainFromWx(wxText);
        }

        dailyForecasts.add(DailyWeather(
          date: date,
          maxTemp: maxT,
          minTemp: minT,
          rainChance: pop,
          conditionCode: _wxTextToOpenWeatherCode(wxText),
        ));

        if (k == tomorrowKey) {
          await tempManager.saveTomorrowForecast(maxT, minT);
        }
      } else if (owmDailyMap.containsKey(k)) {
        dailyForecasts.add(owmDailyMap[k]!);
        final d = owmDailyMap[k]!;
        if (k == tomorrowKey) {
          await tempManager.saveTomorrowForecast(d.maxTemp, d.minTemp);
        }
      } else {
        dailyForecasts.add(DailyWeather(
          date: date,
          maxTemp: currentTemp,
          minTemp: currentTemp,
          rainChance: currentRainChance,
          conditionCode: openWeatherMapCode,
        ));
      }
    }

    List<int> hourlyConditionCodes = [];
    try {
      var wxNode = weatherElements.firstWhere(
        (e) => ['Wx', '天氣現象'].contains(_safeGet(e, 'ElementName')),
        orElse: () => null,
      );

      if (wxNode != null) {
        var wxTimeList = _safeGetList(wxNode, 'Time');

        for (int i = 0; i < 24; i++) {
          int wxIndex = i ~/ 3;
          if (wxIndex >= wxTimeList.length) wxIndex = wxTimeList.length - 1;

          var item = wxTimeList[wxIndex];
          var valList = _safeGetList(item, 'ElementValue');
          if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');

          String hourlyWxText = valList.isNotEmpty
              ? (_safeGet(valList[0], 'Weather') ??
                      _safeGet(valList[0], 'weather') ??
                      _safeGet(valList[0], 'value') ??
                      _safeGet(valList[0], 'Value') ??
                      "多雲")
                  .toString()
              : "多雲";

          int pop = (i < cwaHourlyRainChance.length) ? cwaHourlyRainChance[i] : 0;

          if (hourlyWxText.contains('雨') && pop == 0) {
            // 不要寫死 15，改用推算的
            pop = _estimateRainFromWx(hourlyWxText); 
            
            // 這一行記得保留，這樣才能更新陣列
            if (i < cwaHourlyRainChance.length) cwaHourlyRainChance[i] = pop;
          }

          int code = decideConditionCode(hourlyWxText, pop);
          hourlyConditionCodes.add(code);
        }
      }
    } catch (e) {
      print("❌ 解析逐時圖示失敗: $e");
      hourlyConditionCodes = List.filled(24, openWeatherMapCode);
    }
    if (hourlyConditionCodes.isEmpty) {
      hourlyConditionCodes = List.filled(24, openWeatherMapCode);
    }

    print("🎯 最終結果: code=$openWeatherMapCode, 降雨=$currentRainChance%");

    return WeatherModel(
      latitude: lat,
      longitude: lon, 
      temperature: currentTemp,
      tempMax: todayMaxTemp,
      tempMin: todayMinTemp,
      description: wx,
      areaName: "$city ${_safeGet(targetLocation, 'LocationName')}",
      conditionCode: openWeatherMapCode,
      hourlyConditionCodes: hourlyConditionCodes,
      sunrise: baseData.sunrise,
      sunset: baseData.sunset,
      humidity: humidity,
      windSpeed: windSpeed,
      date: DateTime.now(),
      hourlyTemps: cwaHourlyTemps,
      rainChance: currentRainChance,
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

  String? _readCwaValue(dynamic v) {
    if (v is! Map) return null;
    return v['value']?.toString() ??
        v['Value']?.toString() ??
        v['Temperature']?.toString() ??
        v['Temp']?.toString() ??
        v['ParameterValue']?.toString();
  }

  List<MapEntry<DateTime, double>> _parseCwaTempPoints(List timeList) {
    final points = <MapEntry<DateTime, double>>[];

    for (final item in timeList) {
      final startStr = (_safeGet(item, 'StartTime') ??
              _safeGet(item, 'DataTime') ??
              _safeGet(item, 'startTime') ??
              _safeGet(item, 'dataTime'))
          ?.toString();

      if (startStr == null || startStr.isEmpty) continue;

      var valList = _safeGetList(item, 'ElementValue');
      if (valList.isEmpty) valList = _safeGetList(item, 'elementValue');
      if (valList.isEmpty) continue;

      final raw = _readCwaValue(valList[0]);
      final temp = double.tryParse(raw ?? '');
      if (temp == null) continue;

      final dt = DateTime.tryParse(startStr);
      if (dt == null) continue;

      points.add(MapEntry(dt, temp));
    }

    points.sort((a, b) => a.key.compareTo(b.key));
    return points;
  }

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
      return 13.12 +
          0.6215 * temp -
          11.37 * (windSpeed * 3.6).abs().clamp(0, 100) +
          0.3965 * temp * (windSpeed * 3.6).abs().clamp(0, 100);
    }
    return temp - (windSpeed * 0.5);
  }

  double _calculateDewPoint(double temp, double humidity) {
    double a = 17.27;
    double b = 237.7;
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

  int _wxTextToOpenWeatherCode(String wxText) {
    if (wxText.isEmpty) return 800;
    if (wxText.contains('晴')) return 800;
    if (wxText.contains('多雲')) return 803;
    if (wxText.contains('陰')) return 804;
    if (wxText.contains('雷')) return 200;
    if (wxText.contains('大雨')) return 502;
    if (wxText.contains('豪雨')) return 503;
    if (wxText.contains('陣雨') || wxText.contains('短暫雨')) return 500;
    if (wxText.contains('雨')) return 501;
    if (wxText.contains('霧') || wxText.contains('霾')) return 701;
    return 802;
  }

  int _estimateRainFromWx(String wxText) {
    // 更精細的降雨機率估算
    if (wxText.contains('雷雨') || wxText.contains('大雨') || wxText.contains('豪雨')) {
      return 85;  // 強降雨
    }
    if (wxText.contains('陣雨')) {
      return 65;  // 陣雨：局部性但較強
    }
    if (wxText.contains('短暫雨')) {
      return 40;  // 短暫雨：時間短、範圍小
    }
    if (wxText.contains('雨')) {
      return 55;  // 一般降雨
    }
    if (wxText.contains('多雲時陰')) {
      return 25;  // 可能下雨
    }
    if (wxText.contains('多雲') || wxText.contains('陰')) {
      return 15;  // 不太會下雨
    }
    if (wxText.contains('晴')) {
      return 5;   // 幾乎不會下雨
    }
    return 10;  // 預設值
  }


  int decideConditionCode(String wx, int pop) {
    if (wx.contains('雷')) return 200;
    if (wx.contains('雨')) {
      if (pop >= 70 || wx.contains('大雨') || wx.contains('豪雨')) return 502;
      return 500;
    }
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

  List<int> expandPoP3hToHourly(List timeList) {
    List<int> hourly = [];
    final now = DateTime.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);
    
    // 建立一個 Map: 時間 -> 降雨機率
    Map<DateTime, int> popMap = {};
    
    for (var item in timeList) {
      final startStr = _safeGet(item, 'StartTime')?.toString() ?? '';
      final start = DateTime.tryParse(startStr);
      
      if (start != null) {
        var valList = item['ElementValue'] ?? item['elementValue'] ?? [];
        if (valList is List && valList.isNotEmpty) {
          final raw = _readCwaValue(valList[0]) ?? '0';
          final pop = int.tryParse(raw) ?? 0;
          popMap[start] = pop;
        }
      }
    }
    
    // ✅ 從「當前整點」開始，依序找未來 24 小時
    for (int i = 0; i < 24; i++) {
      final targetHour = currentHour.add(Duration(hours: i));
      
      // 找出這個小時對應的 3 小時區間
      int? pop;
      for (var entry in popMap.entries) {
        if (!targetHour.isBefore(entry.key) && 
            targetHour.isBefore(entry.key.add(const Duration(hours: 3)))) {
          pop = entry.value;
          break;
        }
      }
      
      // 如果沒找到，用上一筆或預設值
      if (pop == null) {
        pop = hourly.isEmpty ? 0 : hourly.last;
      }
      
      hourly.add(pop);
    }
    
    return hourly;
  }

  int hourlyIconFromWxAndPop(String wx, int pop) {
    if (wx.contains('雨') || pop >= 30) {
      if (pop >= 70 || wx.contains('大雨')) return 502;
      return 500;
    }
    if (wx.contains('晴')) {
      if (wx.contains('多雲')) return 801;
      return 800;
    }
    if (wx.contains('陰')) return 804;
    if (wx.contains('多雲')) return 803;
    return 800;
  }
}

// ===========================================================
// 共用函數：管理每日溫度（預測緩存 + 累積器）
// ===========================================================

class DailyTempManager {
  final SharedPreferences prefs;
  final String prefix; // 'cwa' 或 'owm'
  final String cityKey; // ✅ 修正: 增加 cityKey 來區分不同地點
  
  // ✅ 修正: 建構子接收 cityKey
  DailyTempManager(this.prefs, this.prefix, {required this.cityKey});

  // 輔助屬性：產生唯一的 Key (例如 "cwa_Taipei_Forecast_date")
  String get uniquePrefix => '${prefix}_${cityKey.replaceAll(" ", "_")}';
  
  Future<Map<String, double>> getTodayMinMax(double currentTemp) async {
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    
    // 讀取該城市的日期
    final storedDate = prefs.getString('${uniquePrefix}_forecast_date');
    
    double maxTemp;
    double minTemp;
    
    if (storedDate != todayKey) {
      print("🌅 [$prefix-$cityKey] 新的一天！日期從 $storedDate 切換到 $todayKey");
      
      // 讀取該城市的預測值
      double? forecastMax = prefs.getDouble('${uniquePrefix}_today_forecast_max');
      double? forecastMin = prefs.getDouble('${uniquePrefix}_today_forecast_min');
      
      if (forecastMax != null && forecastMin != null) {
        maxTemp = forecastMax;
        minTemp = forecastMin;
        print("📊 [$prefix-$cityKey] 使用預存的今日預測: ${minTemp.toStringAsFixed(1)}~${maxTemp.toStringAsFixed(1)}°C");
      } else {
        maxTemp = currentTemp;
        minTemp = currentTemp;
        print("⚠️ [$prefix-$cityKey] 沒有預存預測，使用當前溫度: ${currentTemp.toStringAsFixed(1)}°C");
      }
      
      await prefs.setString('${uniquePrefix}_forecast_date', todayKey);
    } else {
      maxTemp = prefs.getDouble('${uniquePrefix}_daily_max') ?? currentTemp;
      minTemp = prefs.getDouble('${uniquePrefix}_daily_min') ?? currentTemp;
    }
    
    if (currentTemp > maxTemp) maxTemp = currentTemp;
    if (currentTemp < minTemp) minTemp = currentTemp;
    
    await prefs.setDouble('${uniquePrefix}_daily_max', maxTemp);
    await prefs.setDouble('${uniquePrefix}_daily_min', minTemp);
    
    print("📊 [$prefix-$cityKey] 今日溫度範圍（累積）: ${minTemp.toStringAsFixed(1)}~${maxTemp.toStringAsFixed(1)}°C");
    
    return {'max': maxTemp, 'min': minTemp};
  }
  
  Future<void> saveTomorrowForecast(double maxTemp, double minTemp) async {
    await prefs.setDouble('${uniquePrefix}_today_forecast_max', maxTemp);
    await prefs.setDouble('${uniquePrefix}_today_forecast_min', minTemp);
    
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowKey = DateFormat('yyyy-MM-dd').format(tomorrow);
    print("💾 [$prefix-$cityKey] 已保存明天 ($tomorrowKey) 的預測: ${minTemp.toStringAsFixed(1)}~${maxTemp.toStringAsFixed(1)}°C");
  }

  Future<void> updateTodayRaw(double newMax, double newMin) async {
    await prefs.setDouble('${uniquePrefix}_daily_max', newMax);
    await prefs.setDouble('${uniquePrefix}_daily_min', newMin);
    print("🔄 [$prefix-$cityKey] 根據 API 預報修正今日範圍: ${newMin.toStringAsFixed(1)}~${newMax.toStringAsFixed(1)}°C");
  }
}