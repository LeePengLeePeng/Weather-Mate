import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:weather_test/IconPlayer/WeatherIconPlayer.dart'; 

class WeatherView extends StatelessWidget {
  final dynamic weather; 
  final Widget? leading; 
  final Widget? trailing; 

  const WeatherView({
    super.key,
    required this.weather,
    this.leading,
    this.trailing,
  });

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
    // ⚡ 雷雨
    if (code >= 230 && code < 300) {
      return WeatherIconPlayer(
        introAsset: 'assets/thunder_loop.webp', 
        loopAsset: 'assets/thunder_loop.webp',
        replayKey: weather.areaName,
      );
    }
    // 🌧️ 雨天 (包含毛毛雨、大雨)
    if ((code >= 200 && code < 230) || (code >= 300 && code < 400) || (code >= 500 && code < 600)) {
      return WeatherIconPlayer(
        introAsset: 'assets/rain_intro.webp', 
        loopAsset: 'assets/rain_loop.webp',
        replayKey: weather.areaName,
      );
    }
    // ❄️ 下雪
    if (code >= 600 && code < 700) {
      return WeatherIconPlayer(
        introAsset: 'assets/snow_loop.webp', 
        loopAsset: 'assets/snow_loop.webp',
        replayKey: weather.areaName,
      );
    }
    // 🌫️ 霧/大氣
    if (code >= 700 && code < 800) {
      return WeatherIconPlayer(
        introAsset: 'assets/Atmosphere.webp', 
        loopAsset: 'assets/Atmosphere.webp',
        replayKey: weather.areaName,
      );
    }
    // ☀️ 晴天
    if (code == 800) {
      return WeatherIconPlayer(
        introAsset: 'assets/sun_intro.webp', 
        loopAsset: 'assets/sun_loop.webp', 
        replayKey: weather.areaName,
      );
    }
    // 🌤️ 晴時多雲
    if (code == 801 || code == 802) {
      return WeatherIconPlayer(
        introAsset: 'assets/sun_cloud_intro.webp', 
        loopAsset: 'assets/sun_cloud_loop.webp',
        replayKey: weather.areaName,
      );
    }
    // ☁️ 多雲/陰天
    if (code == 803 || code == 804) {
      return WeatherIconPlayer(
        introAsset: 'assets/cloud_loop.webp', 
        loopAsset: 'assets/cloud_loop.webp',
        replayKey: weather.areaName,
      );
    }
    
    // 如果都沒有匹配，回傳靜態圖
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
      padding: const EdgeInsets.all(16),
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
                  Text(title, style: const TextStyle(color: Color.fromARGB(200, 57, 57, 57), fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(color: Color.fromARGB(255, 57, 57, 57), fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // --- 5. 穿著建議邏輯 ---
  Map<String, dynamic> _getOutfitRecommendation() {
    final int temp = weather.temperature.round();
    final int code = weather.conditionCode;
    final bool isRaining = code >= 200 && code < 600;
    
    String suggestion = '';
    List<String> clothingItems = []; // 儲存服裝圖片路徑
    
    if (isRaining) {
      suggestion = '今天會下雨,記得帶傘並穿防水外套';
      clothingItems.add('assets/outfit/umbrella.png');
      
      if (temp >= 25) {
        clothingItems.addAll(['assets/outfit/tshirt.png', 'assets/outfit/shorts.png']);
      } else if (temp >= 20) {
        clothingItems.addAll(['assets/outfit/tshirt.png', 'assets/outfit/jeans.png', 'assets/outfit/light_jacket.png']);
      } else if (temp >= 15) {
        clothingItems.addAll(['assets/outfit/hoodie.png', 'assets/outfit/jeans.png']);
      } else {
        clothingItems.addAll(['assets/outfit/coat.png', 'assets/outfit/jeans.png', 'assets/outfit/scarf.png']);
      }
    } else {
      // 非雨天的穿著建議
      if (temp >= 30) {
        suggestion = '天氣炎熱,穿著短袖短褲並做好防曬';
        clothingItems.addAll(['assets/outfit/tshirt.png', 'assets/outfit/shorts.png', 'assets/outfit/sunglasses.png', 'assets/outfit/cap.png']);
      } else if (temp >= 25) {
        suggestion = '天氣溫暖舒適,輕便服裝即可';
        clothingItems.addAll(['assets/outfit/tshirt.png', 'assets/outfit/shorts.png']);
      } else if (temp >= 20) {
        suggestion = '早晚稍涼,建議攜帶薄外套';
        clothingItems.addAll(['assets/outfit/tshirt.png', 'assets/outfit/jeans.png', 'assets/outfit/light_jacket.png']);
      } else if (temp >= 15) {
        suggestion = '天氣轉涼,請穿著長袖與外套';
        clothingItems.addAll(['assets/outfit/hoodie.png', 'assets/outfit/jeans.png']);
      } else if (temp >= 10) {
        suggestion = '天氣寒冷,需要厚外套與圍巾';
        clothingItems.addAll(['assets/outfit/coat.png', 'assets/outfit/jeans.png', 'assets/outfit/scarf.png']);
      } else {
        suggestion = '寒流來襲!請穿著羽絨外套並戴手套';
        clothingItems.addAll(['assets/outfit/down_jacket.png', 'assets/outfit/jeans.png', 'assets/outfit/scarf.png', 'assets/outfit/gloves.png']);
      }
    }
    
    return {
      'suggestion': suggestion,
      'items': clothingItems,
    };
  }

    String formatDayLabel(DateTime date) {
    DateTime today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);
    DateTime targetDay = DateTime(date.year, date.month, date.day);
    
    int daysDifference = targetDay.difference(today).inDays;
    
    if (daysDifference == 0) {
      return 'Today';
    } else if (daysDifference == 1) {
      return 'Tomorrow';
    } else {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    }
  }

  @override
  Widget build(BuildContext context) {

    final weatherIcon = getWeatherIcon(weather.conditionCode);
    final outfitData = _getOutfitRecommendation();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _WeatherHeaderDelegate(
            weather: weather,
            expandedHeight: 530.0,
            topPadding: MediaQuery.of(context).padding.top,
            weatherIcon: weatherIcon,
            leading: leading, 
            trailing: trailing,
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // --- 24 Hour Forecast ---
                const Text('24 HOUR FORECAST', style: TextStyle(color: Color.fromARGB(255, 57, 57, 57), fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Container(
                  height: 150, // 🔥 從 140 增加到 160
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
                          final hour = DateTime.now().add(Duration(hours: index));
                          
                          // 溫度
                          final temp = (weather.hourlyTemps != null && index < weather.hourlyTemps.length) 
                            ? weather.hourlyTemps[index] 
                            : weather.temperature;
                          
                          // 🔥 降雨機率
                          int rainChance;
                          if (weather.hourlyRainChance != null && index < weather.hourlyRainChance!.length) {
                            // 使用真實資料
                            rainChance = weather.hourlyRainChance![index];
                          } else {
                            // 沒有逐時資料,用當日降雨機率模擬
                            if (weather.conditionCode >= 200 && weather.conditionCode < 600) {
                              // 雨天相關天氣碼
                              rainChance = (weather.rainChance - (index * 2)).clamp(30, 90);
                            } else {
                              // 非雨天
                              rainChance = (weather.rainChance - (index * 3)).clamp(0, 40);
                            }
                          }
                          
                          return Container(
                            width: 70, 
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // ⏰ 時間
                                Text(
                                  index == 0 ? 'Now' : DateFormat('HH:00').format(hour), 
                                  style: TextStyle(
                                    color: const Color.fromARGB(255, 57, 57, 57), 
                                    fontSize: 14, 
                                    fontWeight: index == 0 ? FontWeight.bold : FontWeight.w500
                                  )
                                ),
                                
                                const SizedBox(height: 6),
                                
                                // 🌤️ 天氣圖示
                                _getSmallWeatherIcon(
                                  (weather.hourlyConditionCodes != null &&
                                  index < weather.hourlyConditionCodes.length)
                                    ? weather.hourlyConditionCodes[index]
                                    : weather.conditionCode,
                                ),
                                
                                const SizedBox(height: 4),
                                
                                // 💧 降雨機率 (緊湊版)
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
                                      style: TextStyle(
                                        color: const Color.fromARGB(180, 57, 57, 57),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 4),
                                
                                // 🌡️ 溫度
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
                const Text('5 DAY FORECAST', style: TextStyle(color: Color.fromARGB(255, 57, 57, 57), fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
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
                        
                        // 🔥 1. 如果有抓到 7 天資料，就用那筆資料的長度；否則預設 7 天
                        itemCount: (weather.dailyForecasts != null && weather.dailyForecasts.isNotEmpty) 
                            ? weather.dailyForecasts.length 
                            : 7,
                        
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.white.withOpacity(0.3),
                          height: 1,
                          thickness: 1,
                        ),
                        itemBuilder: (context, index) {
                          // 🔥 2. 判斷是否有真實資料
                          final bool hasRealData = weather.dailyForecasts != null && weather.dailyForecasts.isNotEmpty && index < weather.dailyForecasts.length;
                          
                          // 定義變數
                          DateTime day;
                          int maxTemp;
                          int minTemp;
                          int rainChance;
                          int code;

                          if (hasRealData) {
                            // ✅ 使用真實資料 (從 API 抓來的)
                            final daily = weather.dailyForecasts[index];
                            day = daily.date;
                            maxTemp = daily.maxTemp.round();
                            minTemp = daily.minTemp.round();
                            rainChance = daily.rainChance;
                            code = daily.conditionCode;
                          } else {
                            // ⚠️ 備用假資料 (只有在 API 失敗時才用這個)
                            day = DateTime.now().add(Duration(days: index + 1));
                            maxTemp = (weather.tempMax - (index * 0.5)).round();
                            minTemp = (weather.tempMin - (index * 0.3)).round();
                            rainChance = (weather.rainChance - (index * 5)).clamp(0, 100);
                            code = weather.conditionCode;
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                // 📅 日期
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    // 這裡可以根據需求改成顯示 "週一", "週二" 等
                                    formatDayLabel(day),
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 57, 57, 57),
                                      fontSize: 16,
                                      fontWeight: (index == 0 && !hasRealData) ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 30),
                                
                                // 🌤️ 天氣圖示 + 降雨機率
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ✅ 這裡現在會根據每天不同的 code 顯示不同圖示
                                    _getSmallWeatherIcon(code, size: 28),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.water_drop,
                                          size: 12,
                                          color: rainChance > 30 // 超過 30% 變藍色
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
                                
                                // 🌡️ 溫度
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

                const Text('OUTFIT SUGGESTION', style: TextStyle(color: Color.fromARGB(255, 57, 57, 57), fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Row(
                        children: [
                          // 左側:文字建議
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.checkroom, size: 20, color: Color.fromARGB(200, 57, 57, 57)),
                                    SizedBox(width: 8),
                                    Text('今日穿搭建議', style: TextStyle(color: Color.fromARGB(200, 57, 57, 57), fontSize: 14, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  outfitData['suggestion'],
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 57, 57, 57),
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // 右側:服裝圖示
                          Expanded(
                            flex: 2,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: (outfitData['items'] as List<String>).map((item) {
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
                                        // 如果圖片不存在,顯示預設圖示
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

                // 🔥🔥🔥 Details Grid (整合所有資訊) 🔥🔥🔥
                const Text('DETAILS', style: TextStyle(color: Color.fromARGB(255, 57, 57, 57), fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                const SizedBox(height: 10),

                // 第三排:最高溫 & 最低溫
                Row(children: [
                  Expanded(child: _buildInfoCard(icon: Icons.thermostat, title: 'TEMP MAX', value: '${weather.tempMax.round()}°C')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard(icon: Icons.thermostat, title: 'TEMP MIN', value: '${weather.tempMin.round()}°C')),
                ]),
                
                const SizedBox(height: 10),
                
                // 第四排:日出 & 日落
                Row(children: [
                  Expanded(child: _buildInfoCard(icon: Icons.wb_twilight, title: 'SUNRISE', value: DateFormat('HH:mm').format(weather.sunrise))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard(icon: Icons.wb_twilight, title: 'SUNSET', value: DateFormat('HH:mm').format(weather.sunset))),
                ]),

                const SizedBox(height: 10),

                // 第一排:濕度 & 風速
                Row(children: [
                  Expanded(child: _buildInfoCard(icon: Icons.water_drop_outlined, title: 'HUMIDITY', value: '${weather.humidity.round()}%')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard(icon: Icons.air, title: 'WIND', value: '${weather.windSpeed.round()} km/h')),
                ]),
                
                const SizedBox(height: 10),
                
                // 第二排:體感溫度 & UV指數
                Row(children: [
                  Expanded(child: _buildInfoCard(
                    icon: Icons.thermostat, 
                    title: 'FEELS LIKE', 
                    value: weather.feelsLike != null 
                      ? '${weather.feelsLike!.round()}°C' 
                      : '${(weather.temperature - 2).round()}°C'
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard(icon: Icons.wb_sunny_outlined, title: 'UV INDEX', value: '${(weather.temperature * 0.2).round()}')),
                ]),
                
                // 可選欄位:露點溫度 & 風向
                if (weather.dewPoint != null || weather.windDirection != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    if (weather.dewPoint != null)
                      Expanded(child: _buildInfoCard(icon: Icons.water, title: 'DEW POINT', value: '${weather.dewPoint!.round()}°C'))
                    else
                      const Expanded(child: SizedBox()),
                    
                    const SizedBox(width: 10),
                    
                    if (weather.windDirection != null)
                      Expanded(child: _buildInfoCard(icon: Icons.navigation, title: 'WIND DIR', value: weather.windDirection!))
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
  final double expandedHeight;
  final double topPadding;
  final Widget weatherIcon;
  final Widget? leading; 
  final Widget? trailing; 

  _WeatherHeaderDelegate({
    required this.weather,
    required this.expandedHeight,
    required this.topPadding,
    required this.weatherIcon,
    this.leading,
    this.trailing,
  });

  String _getOutfitSuggestion() {
     final int temp = weather.temperature.round();
     final int code = weather.conditionCode;
     if (code >= 200 && code < 600) return "外面正在下雨,記得帶把傘出門 ☔️";
     if (temp >= 30) return "天氣炎熱,建議穿著短袖與透氣衣物 ☀️";
     else if (temp >= 25) return "天氣溫暖,穿件舒適的 T-shirt 即可 👕";
     else if (temp >= 20) return "稍有涼意,建議加件薄外套 🧥";
     else if (temp >= 15) return "天氣變冷了,請穿著夾克或毛衣 🧣";
     else return "寒流來襲!請務必穿著厚外套保暖 ❄️";
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
                left: 0, 
                right: 0, 
                child: Text(
                  '${weather.areaName}', 
                  textAlign: TextAlign.center, 
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
              
              // 🔥 Expanded view - 用同一個 weatherIcon
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
                            child: weatherIcon // 👈 用同一個
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
                            weather.description.toUpperCase(), 
                            style: const TextStyle(
                              fontSize: 30, 
                              fontWeight: FontWeight.w500, 
                              color: Color.fromARGB(255, 57, 57, 57)
                            )
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${DateFormat('MM/dd').add_jm().format(weather.date)}\n${DateFormat('EEEE').format(weather.date)}', 
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

              // 🔥 Collapsed view - 用同一個 weatherIcon  
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
                        child: weatherIcon // 👈 用同一個
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
                            weather.description, 
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
    oldDelegate.weather != weather;
}