import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:weather_test/IconPlayer/WeatherIconPlayer.dart';
import 'package:weather_test/data/outfit_recommendation_service.dart';
import 'package:weather_test/tool/city_time_service.dart';
import 'package:weather_test/tool/localization_helper.dart';

class WeatherView extends StatefulWidget {
  final dynamic weather; 
  final String? displayCityName;
  final Widget? leading; 
  final Widget? trailing; 

  const WeatherView({
    super.key,
    required this.weather,
    this.displayCityName,
    this.leading,
    this.trailing,
  });

  @override
  State<WeatherView> createState() => _WeatherViewState();
}

class _WeatherViewState extends State<WeatherView> {
  late DateTime _currentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = CityTimeService.getCityLocalTime(widget.weather.timezoneOffset);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = CityTimeService.getCityLocalTime(widget.weather.timezoneOffset);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 判斷是否為英文顯示
  bool get _isEnglish => LocalizationHelper.isEnglishCity(widget.displayCityName ?? widget.weather.areaName);

  // 取得完整星期名稱
  String _getFullDayName(DateTime date) {
    if (_isEnglish) {
      return DateFormat('EEEE').format(date);
    } else {
      const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
      return weekdays[date.weekday - 1];
    }
  }

  // --- 1. 靜態圖示路徑 (備用) ---
  String _getIconPath(int code) {
    return switch (code) {
      >= 200 && < 300 => 'assets/thunder.png',
      >= 300 && < 600 => 'assets/rain.png',
      >= 600 && < 700 => 'assets/cloud.png',
      >= 700 && < 800 => 'assets/sun_cloud.png',
      800 => 'assets/sun_loop.webp',
      > 800 => 'assets/cloud_sun.png',
      _ => 'assets/cloud_sun.png',
    };
  }

  // --- 2. 大圖示邏輯 (整合 WeatherIconPlayer) ---
  Widget getWeatherIcon(int code) {
    // 雷雨
    if (code >= 230 && code < 300) {
      return WeatherIconPlayer(
        introAsset: 'assets/thunder_loop.webp', 
        loopAsset: 'assets/thunder_loop.webp',
        replayKey: widget.weather.areaName,
      );
    }
    // 雨天 (包含毛毛雨、大雨)
    if ((code >= 200 && code < 230) || (code >= 300 && code < 400) || (code >= 500 && code < 600)) {
      return WeatherIconPlayer(
        introAsset: 'assets/rain_intro.webp', 
        loopAsset: 'assets/rain_loop.webp',
        replayKey: widget.weather.areaName,
      );
    }
    // 下雪
    if (code >= 600 && code < 700) {
      return WeatherIconPlayer(
        introAsset: 'assets/snow_loop.webp', 
        loopAsset: 'assets/snow_loop.webp',
        replayKey: widget.weather.areaName,
      );
    }
    // 霧/大氣
    if (code >= 700 && code < 800) {
      return WeatherIconPlayer(
        introAsset: 'assets/Atmosphere.webp', 
        loopAsset: 'assets/Atmosphere.webp',
        replayKey: widget.weather.areaName,
      );
    }
    // 晴天
    if (code == 800) {
      return WeatherIconPlayer(
        introAsset: 'assets/sun_intro.webp', 
        loopAsset: 'assets/sun_loop.webp', 
        replayKey: widget.weather.areaName,
      );
    }
    // 晴時多雲
    if (code == 801 || code == 802) {
      return WeatherIconPlayer(
        introAsset: 'assets/sun_cloud_intro.webp', 
        loopAsset: 'assets/sun_cloud_loop.webp',
        replayKey: widget.weather.areaName,
      );
    }
    // 多雲/陰天
    if (code == 803 || code == 804) {
      return WeatherIconPlayer(
        introAsset: 'assets/cloud_loop.webp', 
        loopAsset: 'assets/cloud_loop.webp',
        replayKey: widget.weather.areaName,
      );
    }
    
    // 如果都沒有匹配,回傳靜態圖
    return Image.asset(
      _getIconPath(code),
      width: 150, 
      height: 150, 
      fit: BoxFit.contain, 
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.cloud, size: 150, color: Colors.white),
    );
  }

  // --- 3. 小圖示邏輯 (Hourly Forecast 用) ---
  Widget _getSmallWeatherIcon(int code, {double size = 32}) {
    IconData icon;
    Color color;
    if (code >= 200 && code < 300) { icon = Icons.flash_on; color = const Color(0xFFFFD700); }
    else if (code >= 300 && code < 600) { icon = Icons.water_drop; color = const Color(0xFF4FC3F7); }
    else if (code >= 600 && code < 700) { icon = Icons.ac_unit; color = const Color(0xFF81D4FA); }
    else if (code >= 700 && code < 800) { icon = Icons.cloud; color = const Color(0xFF90A4AE); }
    else if (code == 800) { icon = Icons.wb_sunny; color = const Color(0xFFFFA726); }
    else { icon = Icons.cloud_outlined; color = const Color(0xFF78909C); }
    return Icon(icon, size: size, color: color);
  }

  // --- 4. 資訊卡片 Helper ---
  Widget _buildInfoCard({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: const Color.fromARGB(200, 57, 57, 57)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title, 
                      style: const TextStyle(
                        color: Color.fromARGB(200, 57, 57, 57), 
                        fontSize: 12, 
                        fontWeight: FontWeight.w500, 
                        letterSpacing: 0.5
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value, 
                style: const TextStyle(
                  color: Color.fromARGB(255, 57, 57, 57), 
                  fontSize: 24, 
                  fontWeight: FontWeight.bold
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 5. 穿著建議邏輯 ---
  OutfitRecommendation _getOutfitRecommendation() {
    return OutfitRecommendationService.getRecommendation(
      temperature: widget.weather.temperature.round(),
      conditionCode: widget.weather.conditionCode,
      humidity: widget.weather.humidity.round(),
      windSpeed: widget.weather.windSpeed,
      feelsLike: widget.weather.feelsLike?.round(),
      latitude: widget.weather.latitude,
      longitude: widget.weather.longitude,
      isEnglish: _isEnglish,
    );
  }

  Widget _buildRegionIndicator(ClimateRegion region) {
    final regionName = LocalizationHelper.getClimateRegionName(region.toString().split('.').last, _isEnglish);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            OutfitRecommendationService.getRegionIcon(region),
            size: 16,
            color: const Color.fromARGB(200, 57, 57, 57),
          ),
          const SizedBox(width: 6),
          Text(
            regionName,
            style: const TextStyle(
              fontSize: 12,
              color: Color.fromARGB(200, 57, 57, 57),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    final weatherIcon = getWeatherIcon(widget.weather.conditionCode);
    final OutfitRecommendation outfitData = _getOutfitRecommendation();
    final texts = LocalizationHelper.getTexts(_isEnglish);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _WeatherHeaderDelegate(
            weather: widget.weather,
            displayCityName: widget.displayCityName, 
            expandedHeight: 530.0,
            topPadding: MediaQuery.of(context).padding.top,
            weatherIcon: weatherIcon,
            leading: widget.leading, 
            trailing: widget.trailing, 
            isEnglish: _isEnglish,
            currentTime: _currentTime,
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // --- 24 Hour Forecast ---
                Text(
                  texts['hourForecast']!, 
                  style: TextStyle(
                    color: const Color.fromARGB(255, 57, 57, 57), 
                    fontSize: _isEnglish ? 16 : 17,
                    fontWeight: _isEnglish ? FontWeight.w600 : FontWeight.w700,
                    letterSpacing: 1.2
                  )
                ),
                const SizedBox(height: 10),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25), 
                    borderRadius: BorderRadius.circular(20), 
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5)
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: 24,
                        itemBuilder: (context, index) {
                          final baseTime = CityTimeService.getCityLocalTime(widget.weather.timezoneOffset);
                          final hour = baseTime.add(Duration(hours: index));
                          
                          final temp = (widget.weather.hourlyTemps != null && index < widget.weather.hourlyTemps.length) 
                            ? widget.weather.hourlyTemps[index] 
                            : widget.weather.temperature;
                          
                          int rainChance;
                          if (widget.weather.hourlyRainChance != null && index < widget.weather.hourlyRainChance!.length) {
                            rainChance = widget.weather.hourlyRainChance![index];
                          } else {
                            if (widget.weather.conditionCode >= 200 && widget.weather.conditionCode < 600) {
                              rainChance = (widget.weather.rainChance - (index * 2)).clamp(30, 90);
                            } else {
                              rainChance = (widget.weather.rainChance - (index * 3)).clamp(0, 40);
                            }
                          }
                          
                          return Container(
                            width: 70, 
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  index == 0 ? texts['now']! : DateFormat('HH:00').format(hour),
                                  style: TextStyle(
                                    color: const Color.fromARGB(255, 57, 57, 57), 
                                    fontSize: 14, 
                                    fontWeight: index == 0 ? FontWeight.bold : FontWeight.w500
                                  )
                                ),
                                
                                const SizedBox(height: 6),
                                
                                _getSmallWeatherIcon(
                                  (widget.weather.hourlyConditionCodes != null &&
                                  index < widget.weather.hourlyConditionCodes.length)
                                    ? widget.weather.hourlyConditionCodes[index]
                                    : widget.weather.conditionCode,
                                ),
                                
                                const SizedBox(height: 4),
                                
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.water_drop,
                                      size: 10,
                                      color: rainChance > 50 
                                        ? const Color(0xFF4FC3F7)
                                        : const Color.fromARGB(120, 57, 57, 57),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$rainChance%',
                                      style: const TextStyle(
                                        color: Color.fromARGB(180, 57, 57, 57),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 4),
                                
                                Text(
                                  '${temp.round()}°', 
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 57, 57, 57), 
                                    fontSize: 16, 
                                    fontWeight: FontWeight.w600
                                  )
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // --- 5 Day Forecast ---
                Text(
                  texts['dayForecast']!, 
                  style: TextStyle(
                    color: const Color.fromARGB(255, 57, 57, 57), 
                    fontSize: _isEnglish ? 16 : 17,
                    fontWeight: _isEnglish ? FontWeight.w600 : FontWeight.w700,
                    letterSpacing: 1.2
                  )
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        
                        itemCount: (widget.weather.dailyForecasts != null && widget.weather.dailyForecasts.isNotEmpty) 
                            ? widget.weather.dailyForecasts.length 
                            : 7,
                        
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.white.withOpacity(0.3),
                          height: 1,
                          thickness: 1,
                        ),
                        itemBuilder: (context, index) {
                          final bool hasRealData = widget.weather.dailyForecasts != null && 
                                                  widget.weather.dailyForecasts.isNotEmpty && 
                                                  index < widget.weather.dailyForecasts.length;
                          
                          DateTime day;
                          int maxTemp;
                          int minTemp;
                          int rainChance;
                          int code;

                          if (hasRealData) {
                            final daily = widget.weather.dailyForecasts[index];
                            day = daily.date; 
                            maxTemp = daily.maxTemp.round();
                            minTemp = daily.minTemp.round();
                            rainChance = daily.rainChance;
                            code = daily.conditionCode;
                          } else {
                            final baseTime = CityTimeService.getCityLocalTime(widget.weather.timezoneOffset);
                            day = baseTime.add(Duration(days: index)); 
                            maxTemp = (widget.weather.tempMax - (index * 0.5)).round();
                            minTemp = (widget.weather.tempMin - (index * 0.3)).round();
                            rainChance = (widget.weather.rainChance - (index * 5)).clamp(0, 100);
                            code = widget.weather.conditionCode;
                          }

                          // ==========================================================
                          // 判斷這一天是不是該城市的「今天」
                          // ==========================================================
                          // _currentTime 是由計時器每秒更新的該城市當地時間
                          // 1. 取得該城市今天的日期字串 (yyyy-MM-dd)
                          final String cityTodayStr = DateFormat('yyyy-MM-dd').format(_currentTime);
                          
                          // 2. 取得該城市明天的日期字串
                          final DateTime cityTomorrowDate = _currentTime.add(const Duration(days: 1));
                          final String cityTomorrowStr = DateFormat('yyyy-MM-dd').format(cityTomorrowDate);
                          
                          // 3. 當前預報項目的日期字串
                          final String forecastDayStr = DateFormat('yyyy-MM-dd').format(day);

                          // 4. 判定邏輯
                          final bool isActuallyToday = (cityTodayStr == forecastDayStr);
                          final bool isActuallyTomorrow = (cityTomorrowStr == forecastDayStr);

                          String displayDayName;
                          if (isActuallyToday) {
                            displayDayName = _isEnglish ? "Today" : "今天";
                          } else if (isActuallyTomorrow) {
                            displayDayName = _isEnglish ? "Tomorrow" : "明天";
                          } else {
                            displayDayName = _getFullDayName(day);
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    displayDayName,
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 57, 57, 57),
                                      fontSize: 16,
                                      fontWeight: (isActuallyToday || isActuallyTomorrow) 
                                          ? FontWeight.bold 
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 30),
                                
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _getSmallWeatherIcon(code, size: 28),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.water_drop,
                                          size: 12,
                                          color: rainChance > 30
                                            ? const Color(0xFF4FC3F7)
                                            : const Color.fromARGB(120, 57, 57, 57),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$rainChance%',
                                          style: const TextStyle(
                                            color: Color.fromARGB(180, 57, 57, 57),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                const Spacer(), 
                                
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$minTemp°',
                                      style: const TextStyle(
                                        color: Color.fromARGB(150, 57, 57, 57),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    SizedBox(
                                      width: 40, 
                                      child: Text(
                                        '$maxTemp°',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: Color.fromARGB(255, 57, 57, 57),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      texts['outfitSuggestion']!,
                      style: TextStyle(
                        color: const Color.fromARGB(255, 57, 57, 57),
                        fontSize: _isEnglish ? 16 : 17,
                        fontWeight: _isEnglish ? FontWeight.w600 : FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                   _buildRegionIndicator(outfitData.region),
                  ],
                ),
                const SizedBox(height: 10),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.checkroom,
                                      size: 20,
                                      color: Color.fromARGB(200, 57, 57, 57),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      texts['outfitTitle']!,
                                      style: TextStyle(
                                        color: const Color.fromARGB(200, 57, 57, 57),
                                        fontSize: _isEnglish ? 14 : 15,
                                        fontWeight: _isEnglish ? FontWeight.w600 : FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  LocalizationHelper.translateOutfitSuggestion(outfitData.suggestion, _isEnglish),
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 57, 57, 57),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          Expanded(
                            flex: 2,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: outfitData.clothingItems.map((item) {
                                return Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      item,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.checkroom,
                                          size: 30,
                                          color: Color.fromARGB(150, 57, 57, 57),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),

                Text(
                  texts['details']!, 
                  style: TextStyle(
                    color: const Color.fromARGB(255, 57, 57, 57), 
                    fontSize: _isEnglish ? 16 : 17,
                    fontWeight: _isEnglish ? FontWeight.w600 : FontWeight.w700,
                    letterSpacing: 1.2
                  )
                ),
                const SizedBox(height: 10),

                Row(children: [
                  Expanded(child: _buildInfoCard(icon: Icons.thermostat, title: texts['tempMin']!, value: '${widget.weather.tempMin.round()}°C')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard(icon: Icons.thermostat, title: texts['tempMax']!, value: '${widget.weather.tempMax.round()}°C')),
                ]),
                
                const SizedBox(height: 10),
                
                Row(children: [
                  Expanded(child: _buildInfoCard(icon: Icons.wb_twilight, title: texts['sunrise']!, value: DateFormat('HH:mm').format(widget.weather.sunrise))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard(icon: Icons.wb_twilight, title: texts['sunset']!, value: DateFormat('HH:mm').format(widget.weather.sunset))),
                ]),

                const SizedBox(height: 10),

                Row(children: [
                  Expanded(child: _buildInfoCard(icon: Icons.water_drop_outlined, title: texts['humidity']!, value: '${widget.weather.humidity.round()}%')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard(icon: Icons.air, title: texts['wind']!, value: '${widget.weather.windSpeed.round()} km/h')),
                ]),
                
                const SizedBox(height: 10),
                
                Row(children: [
                  Expanded(child: _buildInfoCard(
                    icon: Icons.thermostat, 
                    title: texts['feelsLike']!,
                    value: widget.weather.feelsLike != null 
                      ? '${widget.weather.feelsLike!.round()}°C' 
                      : '${(widget.weather.temperature - 2).round()}°C'
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard(icon: Icons.wb_sunny_outlined, title: texts['uvIndex']!, value: '${(widget.weather.temperature * 0.2).round()}')),
                ]),
                
                if (widget.weather.dewPoint != null || widget.weather.windDirection != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    if (widget.weather.dewPoint != null)
                      Expanded(child: _buildInfoCard(icon: Icons.water, title: texts['dewPoint']!, value: '${widget.weather.dewPoint!.round()}°C'))
                    else
                      const Expanded(child: SizedBox()),
                    
                    const SizedBox(width: 10),
                    
                    if (widget.weather.windDirection != null)
                      Expanded(child: _buildInfoCard(
                        icon: Icons.navigation, 
                        title: texts['windDir']!, 
                        value: LocalizationHelper.translateWindDirection(widget.weather.windDirection!, _isEnglish)
                      ))
                    else
                      const Expanded(child: SizedBox()),
                  ]),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// Header Delegate
// ----------------------------------------------------------------------
class _WeatherHeaderDelegate extends SliverPersistentHeaderDelegate {
  final dynamic weather;
  final String? displayCityName; 
  final double expandedHeight;
  final double topPadding;
  final Widget weatherIcon;
  final Widget? leading; 
  final Widget? trailing;
  final bool isEnglish;
  final DateTime currentTime; 

  _WeatherHeaderDelegate({
    required this.weather,
    required this.expandedHeight,
    required this.topPadding,
    required this.weatherIcon,
    required this.isEnglish,
    required this.currentTime, 
    this.displayCityName,
    this.leading,
    this.trailing,
  });

  String _getOutfitSuggestion() {
     return LocalizationHelper.getOutfitSuggestion(
       weather.temperature.round(), 
       weather.conditionCode,
       isEnglish
     );
  }

  String _getFullDayName(DateTime date) {
    if (isEnglish) {
      return DateFormat('EEEE').format(date);
    } else {
      const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
      return weekdays[date.weekday - 1];
    }
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final double areaTop = topPadding + 15;
    
    final double outfitOpacity = (1.0 - (progress * 5.0)).clamp(0.0, 1.0);
    const double cutOffPoint = 0.6; 
    const double fadeStart = 0.55;  
    const double finishPoint = 0.8; 
    final double expandedOpacity = (1.0 - ((progress - fadeStart) / (cutOffPoint - fadeStart))).clamp(0.0, 1.0);
    
    final double bigContentScale = (1.0 - (progress * 0.4)).clamp(0.5, 1.0);
    final double bigContentTranslateY = progress * -140;
    
    final double collapsedOpacity = (progress > cutOffPoint ? (progress - cutOffPoint) / (finishPoint - cutOffPoint) : 0.0).clamp(0.0, 1.0);
    final double bgAlpha = (progress > cutOffPoint ? (progress - cutOffPoint) / (finishPoint - cutOffPoint) * 0.4 : 0.0).clamp(0.0, 0.4);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(bgAlpha),
                Colors.white.withOpacity(bgAlpha),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.0, 0.7, 1.0], 
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: areaTop, 
                left: 20,
                right: 20,
                child: Text(
                  displayCityName ?? weather.areaName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: Color.fromARGB(255, 57, 57, 57)
                  )
                )
              ),
              
              Positioned(
                top: areaTop + 45, 
                left: 20, 
                right: 20, 
                child: Opacity(
                  opacity: outfitOpacity, 
                  child: Text(
                    _getOutfitSuggestion(), 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.w500, 
                      color: Color.fromARGB(255, 80, 80, 80)
                    )
                  )
                )
              ),
              
              Positioned(
                top: 0, 
                left: 0, 
                right: 0, 
                height: maxExtent, 
                child: Transform.translate(
                  offset: Offset(0, bigContentTranslateY), 
                  child: Transform.scale(
                    scale: bigContentScale, 
                    alignment: Alignment.center, 
                    child: Opacity(
                      opacity: expandedOpacity, 
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [
                          SizedBox(height: topPadding + 60), 
                          SizedBox(
                            width: 200, 
                            height: 200, 
                            child: weatherIcon
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${weather.temperature.round()}°C', 
                            style: const TextStyle(
                              fontSize: 40, 
                              fontWeight: FontWeight.w600, 
                              color: Color.fromARGB(255, 57, 57, 57)
                            )
                          ),
                          Text(
                            LocalizationHelper.translateWeatherDescription(weather.description, isEnglish).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 30, 
                              fontWeight: FontWeight.w500, 
                              color: Color.fromARGB(255, 57, 57, 57)
                            )
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${DateFormat('MM/dd').add_jm().format(currentTime)}\n${_getFullDayName(currentTime)}', // 🔥 使用 currentTime
                            textAlign: TextAlign.center, 
                            style: const TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.w300, 
                              color: Color.fromARGB(255, 57, 57, 57)
                            )
                          ),
                        ]
                      )
                    )
                  )
                )
              ),

              Positioned(
                top: areaTop + 50, 
                left: 0, 
                right: 0,
                child: Opacity(
                  opacity: collapsedOpacity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    crossAxisAlignment: CrossAxisAlignment.center, 
                    children: [
                      SizedBox(
                        height: 100, 
                        width: 100, 
                        child: weatherIcon
                      ),
                      const SizedBox(height: 10), 
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.baseline, 
                        textBaseline: TextBaseline.alphabetic, 
                        children: [
                          Text(
                            '${weather.temperature.round()}°C', 
                            style: const TextStyle(
                              fontSize: 26, 
                              fontWeight: FontWeight.w500, 
                              color: Color.fromARGB(255, 57, 57, 57), 
                              height: 1.0
                            )
                          ),
                          const SizedBox(height: 10),
                          Text(
                            LocalizationHelper.translateWeatherDescription(weather.description, isEnglish),
                            style: const TextStyle(
                              fontSize: 25, 
                              fontWeight: FontWeight.w500, 
                              color: Color.fromARGB(255, 80, 80, 80), 
                              height: 1.0
                            )
                          ),
                        ]
                      )
                    ]
                  )
                )
              ),

              Positioned(
                top: topPadding, 
                left: 20, 
                right: 20, 
                height: kToolbarHeight,
                child: NavigationToolbar(
                  leading: leading ?? const SizedBox(), 
                  trailing: trailing ?? const SizedBox(), 
                  centerMiddle: false
                )
              ),
            ]
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => kToolbarHeight + topPadding + 120; 

  @override
  bool shouldRebuild(covariant _WeatherHeaderDelegate oldDelegate) => 
    oldDelegate.weather != weather || oldDelegate.currentTime != currentTime; 
}