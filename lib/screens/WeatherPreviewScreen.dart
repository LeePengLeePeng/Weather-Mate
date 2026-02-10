import 'package:flutter/material.dart';
import 'package:weather_test/screens/search_screen.dart';
import '../data/weather_repository.dart';
import '../data/weather_model.dart';
import 'weather_view.dart';
import 'weather_background.dart'; 

class WeatherPreviewScreen extends StatefulWidget {
  final CityData city;

  const WeatherPreviewScreen({super.key, required this.city});

  @override
  State<WeatherPreviewScreen> createState() => _WeatherPreviewScreenState();
}

class _WeatherPreviewScreenState extends State<WeatherPreviewScreen> {
  final WeatherRepository _repository = WeatherRepository();
  WeatherModel? _weather;
  bool _isLoading = true;
  String _error = '';
  String _userCountryCode = 'TW';

  String get _displayCityName => _formatCityNameForDisplay(widget.city);

  @override
  void initState() {
    super.initState();
    _fetchWeather();

  try {
      final String? systemCountry = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      if (systemCountry != null) {
        _userCountryCode = systemCountry; 
      }
    } catch (e) {
      debugPrint("無法獲取系統地區: $e");
    }
  }

  Future<void> _fetchWeather() async {
    try {
      final data = await _repository.getWeather(
        widget.city.latitude, 
        widget.city.longitude, 
      );
      if (mounted) {
        setState(() {
          _weather = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "無法載入天氣資訊";
          _isLoading = false;
        });
      }
    }
  }

  String _formatCityNameForDisplay(CityData city) {
    // 如果沒有國家信息,直接返回城市名
    if (city.country.isEmpty) {
      return _simplifyEnglishName(city.name);
    }
    
    // 解析 country 字段 (格式: "行政區, 國家" 或 "國家")
    List<String> parts = city.country.split(',').map((e) => e.trim()).toList();
    String cityName = _simplifyEnglishName(city.name);
    String country = parts.isNotEmpty ? parts.last : '';
    
    // 判斷是否為本地國家
    bool isLocalCountry = _isLocalCountry(country);
    
    // 本地國家:只顯示 "城市名, 行政區"
    if (isLocalCountry) {
      if (parts.length >= 2) {
        String region = _simplifyEnglishName(parts[0]); // 第一部分是行政區
        // 避免重複顯示
        if (cityName.contains(region) || region.contains(cityName)) {
          return cityName; // 只顯示城市名
        }
        return '$cityName, $region';
      }
      return cityName;
    }
    
    // 如果城市名本身就很長,只顯示城市名
    if (cityName.length > 15) {
      return cityName;
    }
    
    return '$cityName, $country';
  }

  // 簡化英文地名,移除 District/City/Township 等後綴
  String _simplifyEnglishName(String name) {
    return name
        .replaceAll(' District', '')
        .replaceAll(' City', '')
        .replaceAll(' Township', '')
        .replaceAll(' County', '')
        .trim();
  }

  bool _isLocalCountry(String country) {
    if (_userCountryCode == 'TW') {
      return country.contains('台灣') || country.contains('Taiwan') || country.contains('中華民國');
    }
    if (_userCountryCode == 'JP') {
      return country.contains('日本') || country.contains('Japan');
    }
    if (_userCountryCode == 'US') {
      return country.contains('美國') || country.contains('United States');
    }
    return false;
  }
  
  @override
  Widget build(BuildContext context) {
    // 載入中畫面
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 錯誤畫面
    if (_error.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.black)),
        body: Center(child: Text(_error)),
      );
    }
    
    // 成功畫面
    return Scaffold(
      body: Stack(
        children: [
          // ===========================================
          // 1. 補回背景層
          // ===========================================
          Positioned.fill(
            child: WeatherBackground(
              weather: _weather,
              child: const SizedBox(),
            ),
          ),

          // ===========================================
          // 2. 內容層 (WeatherView)
          // ===========================================
          Positioned.fill(
            child: WeatherView(
              weather: _weather!,
              displayCityName: _displayCityName,
              
              // 取消按鈕
              leading: IconButton(
                icon: const Icon(Icons.close, color: Color.fromARGB(255, 57, 57, 57), size: 30),
                onPressed: () => Navigator.pop(context, false),
              ),
              
              // 加入按鈕
              trailing: TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "加入", 
                  style: TextStyle(
                    color: Colors.blueAccent, 
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}