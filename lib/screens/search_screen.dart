import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:weather_test/bloc/weather_bloc_bloc.dart';
import 'package:weather_test/tool/fade_route.dart';
import 'WeatherPreviewScreen.dart'; 

class CityData {
  final String id;
  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final bool isEnglish;

  CityData({
    required this.id, 
    required this.name, 
    required this.country, 
    required this.latitude, 
    required this.longitude,
    this.isEnglish = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'latitude': latitude,
    'longitude': longitude,
    'isEnglish': isEnglish,
  };

  factory CityData.fromJson(Map<String, dynamic> json) {
    final double lat = (json['latitude'] as num).toDouble();
    final double lon = (json['longitude'] as num).toDouble();

    return CityData(
      id: json['id'] ??
          '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}',
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      latitude: lat,
      longitude: lon,
      isEnglish: json['isEnglish'] ?? false,
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
  
  String _userCountryCode = 'TW';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<CityData> _searchResults = [];
  List<CityData> _savedCities = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isFocused = false;
  bool _currentSearchIsEnglish = false;
  Timer? _debounce;
  
  @override
  void initState() {
    super.initState();
    _loadSavedCities();

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
        if (!_isFocused && _controller.text.isEmpty) {
          _searchResults.clear();
        }
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (value.isEmpty) {
      setState(() {
        _searchResults.clear();
        _errorMessage = '';
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchCity(value);
    });
  }

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
    final exists = _savedCities.any((c) => c.id == city.id);
    if (exists) return;

    setState(() {
      _savedCities.insert(0, city);
    });
    _saveToPrefs();
  }

  Future<void> _removeCity(CityData city) async {
    setState(() {
      _savedCities.removeWhere((c) => c.id == city.id);
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

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      await setLocaleIdentifier("zh_TW");
      debugPrint("目前位置使用 zh_TW locale");
      
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

  Future<void> _searchCity(String query) async {
    if (query.isEmpty) return;
    
    if (_containsBopomofo(query)) {
      setState(() {
        _errorMessage = "請輸入中文或英文城市名稱";
        _isLoading = false;
        _searchResults = [];
      });
      return;
    }
    
    // 根據搜尋語言設定 geocoding locale
    _currentSearchIsEnglish = _isEnglish(query);
    if (_currentSearchIsEnglish) {
      // 英文搜尋 → 使用英文結果
      await setLocaleIdentifier("en_US");
      debugPrint("設定 locale 為 en_US");
    } else {
      // 中文搜尋 → 使用繁體中文結果  
      await setLocaleIdentifier("zh_TW");
      debugPrint("設定 locale 為 zh_TW");
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchResults = [];
    });

    try {
      List<String> searchQueries = _generateSearchVariations(query);
      
      // 去除重複的搜尋詞
      searchQueries = searchQueries.toSet().toList();
      
      debugPrint("將搜尋 ${searchQueries.length} 個變體: $searchQueries");
      
      List<Location> allLocations = [];
      
      for (int i = 0; i < searchQueries.length; i += 5) {
        int end = (i + 5 < searchQueries.length) ? i + 5 : searchQueries.length;
        List<String> batch = searchQueries.sublist(i, end);
        
        List<Future<List<Location>>> searches = batch.map((q) {
          return locationFromAddress(q).timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              debugPrint("搜尋 '$q' 超時");
              return <Location>[];
            },
          ).catchError((e) {
            debugPrint("搜尋 '$q' 失敗: $e");
            return <Location>[];
          });
        }).toList();
        
        List<List<Location>> batchResults = await Future.wait(searches);
        for (var results in batchResults) {
          allLocations.addAll(results);
        }
        
        if (allLocations.length >= 20) break;
      }

      if (allLocations.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = "找不到「$query」相關地點";
            _isLoading = false;
            _searchResults = [];
          });
        }
        return;
      }

      Map<String, CityData> uniqueLocations = {};
      int processedCount = 0;
      
      for (var loc in allLocations) {
        if (processedCount >= 30) break;
        
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            loc.latitude, 
            loc.longitude
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint("⏱️ 解析座標超時");
              return <Placemark>[];
            },
          );
          
          if (placemarks.isEmpty) continue;
          
          Placemark p = placemarks.first;
          String title = p.locality ?? p.subLocality ?? p.name ?? query;
          // 如果抓到的名字是空的或是純數字，就改用上一層行政區
          if (title.trim().isEmpty || RegExp(r'^\d+$').hasMatch(title)) {
             title = p.administrativeArea ?? query;
          }

          // 決定副標題 (Subtitle) - 組合「行政區, 國家」
          List<String> subParts = [];
          
          // 如果行政區存在，且跟標題不一樣
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty && p.administrativeArea != title) {
            subParts.add(p.administrativeArea!);
          }
          // 加入國家
          if (p.country != null && p.country!.isNotEmpty) {
            subParts.add(p.country!);
          }
          
          String countryInfo = subParts.join(', ');
          String locationKey = _getDistrictKey(
            country: p.country ?? '',
            administrativeArea: p.administrativeArea ?? '',
            locality: title,
            subAdministrativeArea: p.subAdministrativeArea ?? '',
          );
          
          final cityId =
            '${loc.latitude.toStringAsFixed(4)},${loc.longitude.toStringAsFixed(4)}';

          if (!uniqueLocations.containsKey(locationKey)) {
            uniqueLocations[locationKey] = CityData(
              id: cityId,
              name: title, 
              country: countryInfo,
              latitude: loc.latitude,
              longitude: loc.longitude,
              isEnglish: _currentSearchIsEnglish,
            );
          }
          
          processedCount++;
        } catch (e) {
          debugPrint("解析地址失敗: $e");
        }
      }

      List<CityData> filteredResults = uniqueLocations.values
        .where((city) => _isMatchingCity(city.name, query))
        .toList();
    
      if (filteredResults.isEmpty && uniqueLocations.isNotEmpty) {
        bool isCountryQuery = _isCountryQuery(query);
        bool isEnglishQuery = _isEnglish(query);
        bool isProbablyCountry = query.length <= 4 && !_isEnglish(query);
        
        if (isCountryQuery || isEnglishQuery || isProbablyCountry) {
          debugPrint("查詢無匹配結果,顯示所有找到的地點");
          filteredResults = uniqueLocations.values.toList();
        }
      }
      
      filteredResults.sort((a, b) {
        bool aIsLocal = a.name.contains('台灣') || !a.name.contains('(');
        bool bIsLocal = b.name.contains('台灣') || !b.name.contains('(');
        
        if (aIsLocal && !bIsLocal) return -1;
        if (!aIsLocal && bIsLocal) return 1;
        return 0;
      });

      if (mounted) {
        setState(() {
          _searchResults = filteredResults;
          _isLoading = false;
          _errorMessage = filteredResults.isEmpty ? "找不到「$query」相關地點" : '';
          
          if (_searchResults.isNotEmpty) {
            debugPrint("找到 ${_searchResults.length} 個結果");
          }
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "搜尋發生錯誤,請稍後再試";
          _isLoading = false;
          _searchResults = [];
        });
      }
      debugPrint("搜尋錯誤: $e");
    }
  }
  String _getDistrictKey({
    required String country,
    required String administrativeArea,
    required String locality,
    required String subAdministrativeArea,
  }) {
    if (country.contains('Taiwan') || country.contains('台灣')) {
      if (locality.isNotEmpty) {
        return '$administrativeArea-$locality';
      } else if (subAdministrativeArea.isNotEmpty) {
        return '$administrativeArea-$subAdministrativeArea';
      }
      return administrativeArea;
    }
    return '$country-$administrativeArea-$locality';
  }

  // 檢測注音符號
  bool _containsBopomofo(String text) {
    return RegExp(r'[\u3105-\u312F\u31A0-\u31BF]').hasMatch(text);
  }

  List<String> _generateSearchVariations(String query) {
    List<String> variations = [];
    String lowerQuery = query.toLowerCase().trim();
    
    // 優先檢查是否為已知城市/國家
    Map<String, String> knownPlaces = _getKnownPlaceMapping();
    
    if (knownPlaces.containsKey(lowerQuery)) {
      variations.add(knownPlaces[lowerQuery]!);
      return variations;
    }
    
    variations.add(query);
    
    if (_isEnglish(query)) {
      // 英文查詢
      List<String> cityVariations = _getAllCityNameVariations(lowerQuery);
      
      if (cityVariations.length > 1) {
        variations.addAll(cityVariations);
      }
      
      // 如果是完整單字且不是國家名,加上常見國家
      bool isCountryName = _isCountryQuery(query);
      if (!isCountryName && query.length > 2) {
        variations.add('$query, USA');
        variations.add('$query, Canada');
        variations.add('$query, UK');
      }
    } else {
      // 中文查詢
      if (query.length <= 2) {
        variations.add(query);
        
        // 嘗試加上「國」
        if (!query.contains('國')) {
          variations.add('$query國');
        }
      } else if (query.length <= 4) {
        // 中等長度
        variations.add(query);
        
        if (!query.contains('市') && !query.contains('區') && !query.contains('縣')) {
          variations.add('$query市');
        }
        
        // 嘗試主要國家
        variations.add('$query Japan');
        variations.add('$query Canada');
        variations.add('台灣$query');
      } else {
        // 長查詢
        variations.add(query);
        variations.add('$query市');
        variations.add('台灣$query');
        variations.add('$query Japan');
        variations.add('$query China');
      }
    }
    
    return variations;
  }
  
  // 常見城市/國家對應表
  Map<String, String> _getKnownPlaceMapping() {
    return {
      '加': 'Canada',
      '美': 'United States',
      '日': 'Japan',
      '英': 'United Kingdom',
      '法': 'France',
      '德': 'Germany',
      '加拿大': 'Canada',
      '美國': 'United States',
      '日本': 'Japan',
      '英國': 'United Kingdom',
      '法國': 'France',
      '德國': 'Germany',
      '班夫': 'Banff, Canada',
      '紐約': 'New York',
      '東京': 'Tokyo',
      '京都': 'Kyoto',
      '大阪': 'Osaka',
      '巴黎': 'Paris',
      '倫敦': 'London',
      '雪梨': 'Sydney',
      '墨爾本': 'Melbourne',
      '多倫多': 'Toronto',
      '溫哥華': 'Vancouver',
    };
  }
  
  bool _isMatchingCity(String cityName, String query) {
    String lowerCityName = cityName.toLowerCase();
    String lowerQuery = query.toLowerCase();
    
    if (_isEnglish(query)) {
      List<String> possibleNames = _getAllCityNameVariations(lowerQuery);
      for (String name in possibleNames) {
        if (lowerCityName.contains(name.toLowerCase())) {
          return true;
        }
      }
    }
    
    if (lowerCityName.contains(lowerQuery)) {
      return true;
    }
    
    String cityNameNoSpace = lowerCityName.replaceAll(' ', '');
    String queryNoSpace = lowerQuery.replaceAll(' ', '');
    if (cityNameNoSpace.contains(queryNoSpace)) {
      return true;
    }
    
    List<String> countryNames = ['日本', '中國', '美國', '英國', '法國', '加拿大', '澳大利亞', '澳洲'];
    String cityNameNoCountry = lowerCityName;
    for (String country in countryNames) {
      cityNameNoCountry = cityNameNoCountry.replaceAll(country.toLowerCase(), '');
    }
    if (cityNameNoCountry.contains(lowerQuery)) {
      return true;
    }
    
    return false;
  }

  List<String> _getAllCityNameVariations(String lowerQuery) {
    Map<String, List<String>> cityVariations = {
      'newyork': ['New York', 'newyork', '紐約', '纽约'],
      'new york': ['New York', 'newyork', '紐約', '纽约'],
      'tokyo': ['Tokyo', '東京', '东京'],
      'kyoto': ['Kyoto', '京都'],
      'osaka': ['Osaka', '大阪'],
      'beijing': ['Beijing', '北京'],
      'shanghai': ['Shanghai', '上海'],
      'hongkong': ['Hong Kong', 'hongkong', '香港'],
      'hong kong': ['Hong Kong', 'hongkong', '香港'],
      'losangeles': ['Los Angeles', 'losangeles', '洛杉磯', '洛杉矶'],
      'los angeles': ['Los Angeles', 'losangeles', '洛杉磯', '洛杉矶'],
      'sanfrancisco': ['San Francisco', 'sanfrancisco', '舊金山', '旧金山'],
      'san francisco': ['San Francisco', 'sanfrancisco', '舊金山', '旧金山'],
      'london': ['London', '倫敦', '伦敦'],
      'paris': ['Paris', '巴黎'],
      'singapore': ['Singapore', '新加坡'],
      'sydney': ['Sydney', '雪梨', '悉尼'],
      'melbourne': ['Melbourne', '墨爾本', '墨尔本'],
      'lasvegas': ['Las Vegas', 'lasvegas', '拉斯維加斯', '拉斯维加斯'],
      'las vegas': ['Las Vegas', 'lasvegas', '拉斯維加斯', '拉斯维加斯'],
      'toronto': ['Toronto', '多倫多', '多伦多'],
      'vancouver': ['Vancouver', '溫哥華', '温哥华'],
      'montreal': ['Montreal', '蒙特婁', '蒙特利尔'],
      'banff': ['Banff', '班夫'],
      'canada': ['Canada', '加拿大'],
    };
    
    return cityVariations[lowerQuery] ?? [lowerQuery];
  }

  bool _isEnglish(String text) {
    return RegExp(r'^[a-zA-Z\s]+$').hasMatch(text);
  }
  
  bool _isCountryQuery(String query) {
    String lowerQuery = query.toLowerCase();
    List<String> countries = [
      'canada', '加拿大', '加',
      'japan', '日本', '日',
      'china', '中國', '中国',
      'usa', 'america', '美國', '美国', '美',
      'uk', 'britain', '英國', '英国', '英',
      'france', '法國', '法国', '法',
      'australia', '澳大利亞', '澳大利亚',
      'switzerland', '瑞士',
      'germany', '德國', '德国', '德',
      'italy', '意大利', '義大利',
      'spain', '西班牙',
      'korea', '韓國', '韩国',
      'thailand', '泰國', '泰国',
      'vietnam', '越南',
    ];
    
    return countries.contains(lowerQuery);
  }

  String _formatAppleStyleName({
    required String country,
    required String administrativeArea,
    required String locality,
    required String subAdministrativeArea,
    required String query,
  }) {
    List<String> parts = [];
    
    debugPrint("🔍 Formatting: country=$country, admin=$administrativeArea, locality=$locality");
    
    if (country.contains('Taiwan') || country.contains('台灣')) {
      if (locality.isNotEmpty && locality != administrativeArea) {
        parts.add(locality);
      } else if (subAdministrativeArea.isNotEmpty && subAdministrativeArea != administrativeArea) {
        parts.add(subAdministrativeArea);
      } else if (administrativeArea.isNotEmpty) {
        parts.add(administrativeArea);
      } else {
        parts.add(query);
      }
      
      if (administrativeArea.isNotEmpty && !parts.contains(administrativeArea)) {
        parts.add(administrativeArea);
      }
      
      return parts.join('');
    }
    
    if (administrativeArea.isNotEmpty) {
      parts.add(administrativeArea);
    } else if (locality.isNotEmpty) {
      parts.add(locality);
    } else if (subAdministrativeArea.isNotEmpty) {
      parts.add(subAdministrativeArea);
    } else {
      List<String> mappedCities = _getAllCityNameVariations(query.toLowerCase());
      parts.add(mappedCities.isNotEmpty ? mappedCities[0] : query);
    }
    
    if (country.isNotEmpty) {
      bool isLocalCountry = _isLocalCountry(country);
      if (!isLocalCountry) {
        String countryName = _simplifyCountryName(country);
        parts.add(countryName);
      }
    }
    
    String displayName = parts.join('');
    debugPrint("Final display name: $displayName");
    
    return displayName;
  }

  String _simplifyCountryName(String country) {
    if (country.contains('Japan') || country.contains('日本')) return '日本';
    if (country.contains('China') || country.contains('中國') || country.contains('中国')) return '中國';
    if (country.contains('Hong Kong') || country.contains('香港')) return '香港';
    if (country.contains('United States') || country.contains('美國')) return '美國';
    if (country.contains('Korea') || country.contains('韓國')) return '韓國';
    if (country.contains('Canada') || country.contains('加拿大')) return '加拿大';
    return country;
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
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.transparent, 
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark, 
        
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color.fromARGB(255, 57, 57, 57)),
          onPressed: () {
            _focusNode.unfocus();
            widget.onCitySelected?.call();
          },
        ),
        title: const Text("管理城市", style: TextStyle(color: Color.fromARGB(255, 57, 57, 57), fontWeight: FontWeight.bold)),
      ),
      
      body: Stack(
        children: [
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

          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: '輸入城市名稱(例如:台北)',
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

              Expanded(
                child: Stack(
                  children: [
                    if (_isLoading)
                       const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 57, 57, 57))),
                    
                    if (_errorMessage.isNotEmpty)
                       Center(child: Text(_errorMessage, style: const TextStyle(color: Color.fromARGB(255, 57, 57, 57)))),

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
    return Column(
      children: [
        // 固定的 "目前位置"
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1),
            ),
            child: ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blueAccent),
              title: const Text(
                "目前位置",
                style: TextStyle(
                  color: Color.fromARGB(255, 57, 57, 57),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                "GPS 定位",
                style: TextStyle(color: Color.fromARGB(255, 57, 57, 57), fontSize: 12),
              ),
              onTap: _useCurrentLocation,
            ),
          ),
        ),
        
        // 可排序的城市列表
        Expanded(
          child: _savedCities.isEmpty
              ? const SizedBox()
              : SlidableAutoCloseBehavior(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _savedCities.length,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final double elevation = lerpDouble(0, 6, Curves.easeInOut.transform(animation.value))!;
                          final double scale = lerpDouble(1.0, 1.05, Curves.easeInOut.transform(animation.value))!;
                          
                          return Transform.scale(
                            scale: scale,
                            child: Material(
                              elevation: elevation,
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
                        
                        final city = _savedCities.removeAt(oldIndex);
                        _savedCities.insert(adjustedNewIndex, city);
                        
                        _saveToPrefs();
                      });
                    },
                    itemBuilder: (context, index) {
                      final city = _savedCities[index];

                      return Container(
                        key: Key(city.id), // 每個項目都要有唯一 key
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Slidable(
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
                              leading: const Icon(
                                Icons.drag_handle, // 🔥 拖動手柄圖示
                                color: Colors.black54,
                              ),
                              title: Text(
                                city.name,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: city.country.isNotEmpty
                                  ? Text(
                                      city.country,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    )
                                  : null,
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.black54,
                                size: 14,
                              ),
                              onTap: () async {
                                // 根據保存的語言設定設置 locale
                                if (city.isEnglish) {
                                  await setLocaleIdentifier("en_US");
                                  debugPrint("城市使用英文顯示，設定 locale 為 en_US");
                                } else {
                                  await setLocaleIdentifier("zh_TW");
                                  debugPrint("城市使用中文顯示，設定 locale 為 zh_TW");
                                }

                                final displayName = _formatCityNameForDisplay(city);
                                print("從列表選擇城市: $displayName (isEnglish: ${city.isEnglish})");

                                context.read<WeatherBlocBloc>().add(FetchWeather(
                                      Position(
                                        latitude: city.latitude,
                                        longitude: city.longitude,
                                        timestamp: DateTime.now(),
                                        accuracy: 0,
                                        altitude: 0,
                                        heading: 0,
                                        speed: 0,
                                        speedAccuracy: 0,
                                        altitudeAccuracy: 0,
                                        headingAccuracy: 0,
                                        isMocked: false,
                                      ),
                                      cityName: displayName,
                                    ));
                                widget.onCitySelected?.call();
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
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
        String region = _simplifyEnglishName(parts[0]);
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
                fontSize: 17,
                fontWeight: FontWeight.w500
              ),
            ),
            subtitle: Text(
              city.country,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            onTap: () async {
                _focusNode.unfocus();
                
                final bool? shouldAdd = await Navigator.push(
                  context,
                  createFadeRoute(WeatherPreviewScreen(city: city)),
                );

                if (!mounted) return;

                if (shouldAdd == true) {
                  await _addCityToSaved(city);

                  _controller.clear(); 
                  setState(() {
                    _searchResults.clear();
                    _errorMessage = '';
                  });

                  if (mounted) {
                    // 根據保存的語言設定設置 locale
                    if (city.isEnglish) {
                      await setLocaleIdentifier("en_US");
                      debugPrint("城市使用英文顯示，設定 locale 為 en_US");
                    } else {
                      await setLocaleIdentifier("zh_TW");
                      debugPrint("城市使用中文顯示，設定 locale 為 zh_TW");
                    }
                    
                    final displayName = _formatCityNameForDisplay(city);
                    print("準備顯示城市: $displayName (isEnglish: ${city.isEnglish})");
                    context.read<WeatherBlocBloc>().add(FetchWeather(Position(
                      latitude: city.latitude,
                      longitude: city.longitude,
                      timestamp: DateTime.now(),
                      accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0, isMocked: false
                    ),
                    cityName: displayName,
                    ));
                  }

                  widget.onCitySelected?.call(); 
              }
            },
          ),
        );
      },
    );
  }
}