import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:weather_test/bloc/weather_bloc_bloc.dart';
import 'package:weather_test/screens/search_screen.dart';
import 'package:weather_test/screens/weather_background.dart';
import 'package:weather_test/tool/keep_alive_wrapper.dart';
import 'chat_screen.dart';
import 'weather_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      
      // 🔥 重大改變：這裡不要用 BlocBuilder 包住全家！
      // 改成用 Stack，讓背景和前景分開處理
      body: Stack(
        children: [
          // ==========================================
          // Layer 0: 背景層 (自己有一個 BlocBuilder)
          // ==========================================
          Positioned.fill(
            child: BlocBuilder<WeatherBlocBloc, WeatherBlocState>(
              buildWhen: (previous, current) {
                // 優化：只有當天氣代碼改變時才重繪背景，提升效能
                if (previous is WeatherBlocSuccess && current is WeatherBlocSuccess) {
                  return previous.weather.conditionCode != current.weather.conditionCode;
                }
                return true;
              },
              builder: (context, state) {
                dynamic weather;
                if (state is WeatherBlocSuccess) {
                  weather = state.weather;
                }
                return WeatherBackground(
                  weather: weather,
                  child: const SizedBox(),
                );
              },
            ),
          ),

          // ==========================================
          // Layer 1: 內容層 (PageView 獨立出來，不被 Bloc 影響)
          // ==========================================
          PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(), // 建議用 Clamping 比較不會有彈跳露餡的問題
            allowImplicitScrolling: true, // 🔥 這行依然是核心，開啟預載
            children: [
              
              // [Page 0] Chat (完全靜態，不受天氣 Bloc 影響)
              const KeepAliveWrapper(
                child: ChatScreen(),
              ),

              // [Page 1] Weather (只有這一頁需要監聽 Bloc)
              KeepAliveWrapper(
                child: BlocBuilder<WeatherBlocBloc, WeatherBlocState>(
                  builder: (context, state) {
                    if (state is WeatherBlocSuccess) {
                      return WeatherView(
                        weather: state.weather,
                        leading: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: Color.fromARGB(255, 57, 57, 57)),
                          onPressed: () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.search, size: 30, color: Color.fromARGB(255, 57, 57, 57)),
                          onPressed: () => _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                        ),
                      );
                    } else {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                  },
                ),
              ),

              // [Page 2] Search (完全靜態)
              KeepAliveWrapper(
                child: SearchScreen(
                  onCitySelected: () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}