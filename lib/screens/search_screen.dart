import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:weather_test/bloc/weather_bloc_bloc.dart';
import 'package:weather_test/tool/fade_route.dart';
// 請確認您的檔案名稱大小寫是否正確
import 'WeatherPreviewScreen.dart'; 

// ⚠️ 注意：如果您的 WeatherPreviewScreen.dart 或 weather_model.dart 裡面已經有定義 CityData
// 請刪除下面這個 class CityData 定義，並改用 import 匯入，否則會報錯 "CityData is defined in..."
class CityData {
  final String name;
  final double latitude;
  final double longitude;

  CityData({required this.name, required this.latitude, required this.longitude});

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory CityData.fromJson(Map<String, dynamic> json) {
    return CityData(
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}

class SearchScreen extends StatefulWidget {
  final VoidCallback? onCitySelected;
  
  const SearchScreen({super.key, this.onCitySelected});
  
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  
  String _userCountryCode = 'TW'; // 預設台灣

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<CityData> _searchResults = [];
  List<CityData> _savedCities = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isFocused = false;
  
  @override
  void initState() {
    super.initState();
    _loadSavedCities();

    // 嘗試抓取系統語系來決定預設國家 (例如 zh_TW -> TW)
    try {
      final String? systemCountry = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      if (systemCountry != null) {
        _userCountryCode = systemCountry; 
      }
    } catch (e) {
      debugPrint("無法獲取系統地區: $e");
    }

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
        // 當失去焦點且沒內容時，清空搜尋結果
        if (!_isFocused && _controller.text.isEmpty) {
          _searchResults.clear();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _onSearchChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _searchResults.clear();
      }
    });
  }

  // --- 💾 儲存與讀取 ---
  Future<void> _loadSavedCities() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedStringList = prefs.getStringList('saved_cities');
    if (savedStringList != null) {
      setState(() {
        _savedCities = savedStringList
            .map((item) => CityData.fromJson(jsonDecode(item)))
            .toList();
      });
    }
  }

  Future<void> _addCityToSaved(CityData city) async {
    final exists = _savedCities.any((c) => c.name == city.name);
    if (exists) return;

    setState(() {
      _savedCities.insert(0, city);
    });
    _saveToPrefs();
  }

  Future<void> _removeCity(CityData city) async {
    setState(() {
      _savedCities.removeWhere((c) => c.name == city.name);
    });
    _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> stringList = _savedCities
        .map((city) => jsonEncode(city.toJson()))
        .toList();
    await prefs.setStringList('saved_cities', stringList);
  }

  // --- 📍 抓取目前位置 ---
  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("位置權限被拒絕");
        }
      }
      
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      if (mounted) {
        context.read<WeatherBlocBloc>().add(FetchWeather(position));
        widget.onCitySelected?.call();
      }
    } catch (e) {
      setState(() => _errorMessage = "無法取得目前位置: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 🔍 搜尋邏輯 (雙軌搜尋：同時找當地與全球) ---
  Future<void> _searchCity(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchResults = [];
    });

    try {
      // 1. 定義兩個搜尋任務
      // 任務 A: 全域搜尋 (通常會找到最熱門的，例如日本三重)
      Future<List<Location>> globalSearch = locationFromAddress(query);
      
      // 任務 B: 當地優先搜尋 (強制加上國家名，例如 "台灣三重")
      String localQuery = "${_countryCodeToName(_userCountryCode)}$query";
      Future<List<Location>> localSearch = locationFromAddress(localQuery);

      // 2. 同時執行並等待結果 (catchError 確保其中一個失敗不會讓程式崩潰)
      List<List<Location>> results = await Future.wait([
        globalSearch.catchError((_) => <Location>[]), 
        localSearch.catchError((_) => <Location>[])
      ]);

      List<Location> globalLocations = results[0];
      List<Location> localLocations = results[1];

      // 3. 解析與合併結果
      List<CityData> mergedResults = [];

      // 輔助函式：將 Location 轉為 CityData 並加入清單
      Future<void> parseAndAdd(List<Location> locs) async {
        for (var loc in locs) {
          try {
            List<Placemark> placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
            if (placemarks.isNotEmpty) {
              Placemark p = placemarks.first;
              String city = p.administrativeArea ?? ''; 
              String district = p.locality ?? p.subLocality ?? ''; 
              String country = p.country ?? '';

              // 組合顯示名稱
              String displayName = "";
              if (district.isNotEmpty) {
                displayName = district;
                if (city.isNotEmpty && city != district) displayName += ", $city";
              } else if (city.isNotEmpty) {
                displayName = city;
              } else {
                displayName = p.name ?? query;
              }
              
              // 🔥 強制顯示國家，區分 "日本" vs "台灣"
              if (country.isNotEmpty) displayName += " ($country)";

              // 檢查重複 (避免清單出現一模一樣的)
              if (!mergedResults.any((element) => element.name == displayName)) {
                mergedResults.add(CityData(name: displayName, latitude: loc.latitude, longitude: loc.longitude));
              }
            }
          } catch (e) { 
            debugPrint("解析地址失敗: $e"); 
          }
        }
      }

      // 依序加入：優先放當地結果 (Task B)，再放全球結果 (Task A)
      await parseAndAdd(localLocations);
      await parseAndAdd(globalLocations);

      setState(() {
        _searchResults = mergedResults;
        if (_searchResults.isEmpty) _errorMessage = "找不到相關地點";
      });

    } catch (e) {
      setState(() {
        _errorMessage = "搜尋發生錯誤，請稍後再試";
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 簡單的國家代碼轉中文名稱 (輔助搜尋用)
  String _countryCodeToName(String code) {
    if (code == 'TW') return '台灣';
    if (code == 'JP') return '日本';
    if (code == 'US') return '美國';
    if (code == 'CN') return '中國';
    if (code == 'HK') return '香港';
    return ''; 
  }

  // --- 🎨 UI 建構 ---
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.transparent, 
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light, 
        
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
          onPressed: () {
            _focusNode.unfocus();
            widget.onCitySelected?.call();
          },
        ),
        title: const Text("管理城市", style: TextStyle(color: Color.fromARGB(255, 57, 57, 57), fontWeight: FontWeight.bold)),
      ),
      
      body: Stack(
        children: [
          // Layer A: 背景模糊遮罩
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: (_isFocused || _searchResults.isNotEmpty || _isLoading) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,    
                        end: Alignment.bottomCenter,   
                        stops: const [0.0, 0.15, 1.0], 
                        colors: [
                          Colors.white.withOpacity(0.0), 
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.3), 
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Layer B: 點擊空白處收起鍵盤
          if (_isFocused || _searchResults.isNotEmpty || _isLoading)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _focusNode.unfocus();
                  setState(() {
                    if (_searchResults.isEmpty) _controller.clear();
                  });
                },
                child: Container(color: Colors.transparent),
              ),
            ),

          // Layer C: 搜尋框與列表
          Column(
            children: [
              // 1. 搜尋框
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: '輸入城市名稱 (例如: Taipei)',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.5), 
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _searchResults.clear();
                                _errorMessage = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (value) => _searchCity(value),
                ),
              ),

              // 2. 列表區域
              Expanded(
                child: Stack(
                  children: [
                    if (_isLoading)
                       const Center(child: CircularProgressIndicator(color: Colors.white)),
                    
                    if (_errorMessage.isNotEmpty)
                       Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.white))),

                    if (_searchResults.isNotEmpty)
                      _buildSearchResults()
                    else if (!_isFocused && _controller.text.isEmpty)
                      _buildListWithCurrentLocation(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildListWithCurrentLocation() {
    int totalCount = 1 + _savedCities.length;

    return SlidableAutoCloseBehavior(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: totalCount,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2), 
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1),
              ),
              child: ListTile(
                leading: const Icon(Icons.my_location, color: Colors.blueAccent),
                title: const Text("目前位置", style: TextStyle(color: Color.fromARGB(255, 57, 57, 57), fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: const Text("GPS 定位", style: TextStyle(color: Color.fromARGB(255, 57, 57, 57), fontSize: 12)),
                onTap: _useCurrentLocation, 
              ),
            );
          }

          final city = _savedCities[index - 1]; 
          
          return Slidable(
            key: Key(city.name),
            groupTag: 'saved_cities_list', 
            endActionPane: ActionPane(
              motion: const BehindMotion(), 
              extentRatio: 0.3, 
              children: [
                CustomSlidableAction(
                  onPressed: (context) => _removeCity(city),
                  backgroundColor: Colors.transparent, 
                  foregroundColor: Colors.white,
                  child: Container(
                    width: 50, 
                    height: 50, 
                    decoration: BoxDecoration(
                      color: Colors.red, 
                      borderRadius: BorderRadius.circular(12), 
                    ),
                    child: const Icon(Icons.delete, color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(15), 
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
              ),
              child: ListTile(
                title: Text(city.name, style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black54, size: 14), 
                onTap: () {
                  context.read<WeatherBlocBloc>().add(FetchWeather(Position(
                    latitude: city.latitude,
                    longitude: city.longitude,
                    timestamp: DateTime.now(),
                    accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0, isMocked: false
                  )));

                  widget.onCitySelected?.call();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final city = _searchResults[index];
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
          ),
          child: ListTile(
            leading: const Icon(Icons.place, color: Colors.blueAccent),
            title: Text(
              city.name, 
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18, 
                fontWeight: FontWeight.bold
              )
            ),
            onTap: () async {
                _focusNode.unfocus(); // 收起鍵盤
                
                // 跳轉到預覽頁面
                final bool? shouldAdd = await Navigator.push(
                  context,
                  createFadeRoute(WeatherPreviewScreen(city: city)),
                );

                if (!mounted) return;

                // 判斷使用者是否在預覽頁按下了「新增」
                if (shouldAdd == true) {
                  // (A) 加入儲存列表
                  await _addCityToSaved(city);

                  _controller.clear(); 
                  setState(() {
                    _searchResults.clear();
                    _errorMessage = '';
                  });

                  // (C) 通知 Bloc 更新天氣
                  if (mounted) {
                    context.read<WeatherBlocBloc>().add(FetchWeather(Position(
                      latitude: city.latitude,
                      longitude: city.longitude,
                      timestamp: DateTime.now(),
                      accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0, isMocked: false
                    )));
                  }

                  // (D) 呼叫 callback 滑回主頁
                  widget.onCitySelected?.call(); 
              }
            },
          ),
        );
      },
    );
  }
}