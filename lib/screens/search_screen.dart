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
  
  String _userCountryCode = 'TW';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<CityData> _searchResults = [];
  List<CityData> _savedCities = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isFocused = false;
  
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

  Future<void> _searchCity(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchResults = [];
    });

    try {
      List<String> searchQueries = _generateSearchVariations(query);
      List<Location> allLocations = [];
      
      for (int i = 0; i < searchQueries.length; i += 5) {
        int end = (i + 5 < searchQueries.length) ? i + 5 : searchQueries.length;
        List<String> batch = searchQueries.sublist(i, end);
        
        List<Future<List<Location>>> searches = batch.map((q) {
          return locationFromAddress(q).timeout(
            const Duration(seconds: 3),
            onTimeout: () => <Location>[],
          ).catchError((e) {
            debugPrint("搜尋 '$q' 失敗: $e");
            return <Location>[];
          });
        }).toList();
        
        List<List<Location>> batchResults = await Future.wait(searches);
        for (var results in batchResults) {
          allLocations.addAll(results);
        }
        
        if (allLocations.length >= 10) break;
      }

      if (allLocations.isEmpty) {
        setState(() {
          _errorMessage = "找不到「$query」相關地點";
          _isLoading = false;
        });
        return;
      }

      Map<String, CityData> uniqueLocations = {};
      int processedCount = 0;
      
      for (var loc in allLocations) {
        if (processedCount >= 15) break;
        
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            loc.latitude, 
            loc.longitude
          ).timeout(
            const Duration(seconds: 2),
            onTimeout: () => <Placemark>[],
          );
          
          if (placemarks.isEmpty) continue;
          
          Placemark p = placemarks.first;
          String country = p.country ?? '';
          String administrativeArea = p.administrativeArea ?? '';
          String locality = p.locality ?? '';
          String subAdministrativeArea = p.subAdministrativeArea ?? '';
          
          String displayName = _formatAppleStyleName(
            country: country,
            administrativeArea: administrativeArea,
            locality: locality,
            subAdministrativeArea: subAdministrativeArea,
            query: query,
          );
          
          String locationKey = _getDistrictKey(
            country: country,
            administrativeArea: administrativeArea,
            locality: locality,
            subAdministrativeArea: subAdministrativeArea,
          );
          
          if (!uniqueLocations.containsKey(locationKey)) {
            uniqueLocations[locationKey] = CityData(
              name: displayName,
              latitude: loc.latitude,
              longitude: loc.longitude,
            );
          }
          
          processedCount++;
        } catch (e) {
          debugPrint("解析地區失敗: $e");
        }
      }

      List<CityData> filteredResults = uniqueLocations.values
          .where((city) => _isMatchingCity(city.name, query))
          .toList();
      
      if (filteredResults.isEmpty && uniqueLocations.isNotEmpty) {
        bool isCountryQuery = _isCountryQuery(query);
        if (isCountryQuery || _isEnglish(query)) {
          debugPrint("⚠️ 查詢無匹配結果，顯示所有找到的地點");
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
          if (_searchResults.isEmpty) {
            _errorMessage = "找不到「$query」相關地點";
          }
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "搜尋發生錯誤，請稍後再試";
        });
      }
      debugPrint("搜尋錯誤: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  List<String> _generateSearchVariations(String query) {
    List<String> variations = [];
    variations.add(query);
    
    if (_isEnglish(query)) {
      List<String> knownVariations = _getAllCityNameVariations(query.toLowerCase());
      if (knownVariations.length > 1) {
        variations.add(knownVariations[0]);
        bool isCountryName = ['canada', 'japan', 'china', 'usa', 'uk', 'france', 'australia'].contains(query.toLowerCase());
        if (!isCountryName) {
          variations.add('${knownVariations[0]}, USA');
          variations.add('${knownVariations[0]}, UK');
          variations.add('${knownVariations[0]}, Japan');
          variations.add('${knownVariations[0]}, Canada');
        }
      } else {
        variations.add('$query, USA');
        variations.add('$query, Canada');
        variations.add('$query, UK');
        variations.add('$query, Australia');
        variations.add('$query, Japan');
      }
    } else {
      variations.add('${query}市');
      variations.add('${query}區');
      variations.add('台灣$query');
      variations.add('$query Japan');
      variations.add('日本$query');
      variations.add('$query China');
      variations.add('$query Canada');
    }
    
    return variations;
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
      'canada', '加拿大',
      'japan', '日本',
      'china', '中國', '中国',
      'usa', 'america', '美國', '美国',
      'uk', 'britain', '英國', '英国',
      'france', '法國', '法国',
      'australia', '澳大利亞', '澳大利亚',
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
    debugPrint("🎯 Final display name: $displayName");
    
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
                    hintText: '輸入城市名稱（例如：台北）',
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
                fontSize: 17,
                fontWeight: FontWeight.w500
              ),
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
                    context.read<WeatherBlocBloc>().add(FetchWeather(Position(
                      latitude: city.latitude,
                      longitude: city.longitude,
                      timestamp: DateTime.now(),
                      accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0, isMocked: false
                    )));
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