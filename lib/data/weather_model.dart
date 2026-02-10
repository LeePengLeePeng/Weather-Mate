class DailyWeather {
  final DateTime date;        // 日期
  final double maxTemp;       // 當日最高溫
  final double minTemp;       // 當日最低溫
  final int rainChance;       // 當日降雨機率
  final int conditionCode;    // 當日天氣代碼

  DailyWeather({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.rainChance,
    required this.conditionCode,
  });
}

class WeatherModel {
  final double? latitude;
  final double? longitude; 
  final double temperature;    // 溫度
  final double tempMax;        // 最高溫 (今天的)
  final double tempMin;        // 最低溫 (今天的)
  final String description;    // 天氣描述
  final int conditionCode;     // Icon 代碼
  final List<int> hourlyConditionCodes;
  final String areaName;       // 地點
  final DateTime date;         // 時間
  final DateTime sunrise;      // 日出
  final DateTime sunset;       // 日落
  final double humidity;       // 濕度
  final double windSpeed;      // 風速
  final List<double> hourlyTemps; // 24小時溫度
  final int rainChance;           // 降雨機率 (0-100)
  
  final List<int> hourlyRainChance; // 每小時的降雨機率
  
  final double? dewPoint;         // 露點溫度
  final double? feelsLike;        // 體感溫度
  final String? comfort;          // 舒適度指數
  final String? windDirection;    // 風向
  final String? weatherForecast;  // 天氣預報綜合描述
  final int timezoneOffset;
  final List<DailyWeather> dailyForecasts; 

  WeatherModel({
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.tempMax,
    required this.tempMin,
    required this.description,
    required this.conditionCode,
    required this.areaName,
    required this.date,
    required this.sunrise,
    required this.sunset,
    required this.humidity,
    required this.windSpeed,
    required this.hourlyTemps,
    required this.timezoneOffset,
    this.rainChance = 0,
    
    this.hourlyRainChance = const [], 
    this.hourlyConditionCodes = const [],
    this.dewPoint,
    this.feelsLike,
    this.comfort,
    this.windDirection,
    this.weatherForecast,
    this.dailyForecasts = const [], 
  });
}