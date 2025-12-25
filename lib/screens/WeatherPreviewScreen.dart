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

  @override
  void initState() {
    super.initState();
    _fetchWeather();
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

    // 🔥 成功畫面
    return Scaffold(
      // 這裡的 backgroundColor 設什麼都沒關係，因為會被 WeatherBackground 蓋過
      body: Stack(
        children: [
          // ===========================================
          // 1. 補回背景層
          // ===========================================
          Positioned.fill(
            child: WeatherBackground(
              weather: _weather, // 把抓到的天氣傳進去，這樣預覽時背景顏色也會跟著變！
              child: const SizedBox(),
            ),
          ),

          // ===========================================
          // 2. 內容層 (WeatherView)
          // ===========================================
          Positioned.fill(
            child: WeatherView(
              weather: _weather!,
              
              // 左上角：取消按鈕 (X)
              leading: IconButton(
                icon: const Icon(Icons.close, color: Color.fromARGB(255, 57, 57, 57), size: 30),
                onPressed: () => Navigator.pop(context, false),
              ),
              
              // 右上角：加入按鈕
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