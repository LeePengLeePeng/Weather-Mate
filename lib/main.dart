import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:weather_test/bloc/weather_bloc_bloc.dart';
import 'package:weather_test/screens/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  // 3. 確保 Flutter 引擎綁定初始化 (讀檔或用 plugin 前必加)
  WidgetsFlutterBinding.ensureInitialized();

  // 4. 載入 .env 檔案
  await dotenv.load(fileName: ".env");

  await initializeDateFormatting('zh_TW', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home : FutureBuilder(
        future: _determinePosition(),
        builder: (context, snap) {
          if(snap.hasData) {
            return BlocProvider<WeatherBlocBloc>(
              // 這裡要注意：確保 WeatherBlocBloc 初始化時 dotenv 已經 load 完畢 (上面的 await 保證了這點)
              create: (context) => WeatherBlocBloc()..add(
                FetchWeather(snap.data as Position)
              ),
              child: const HomeScreen(),
            );
          } else if (snap.hasError) {
             // 建議加一個錯誤處理，不然如果沒開定位 App 會一直轉圈圈
             return Scaffold(
               body: Center(child: Text("錯誤: ${snap.error}")),
             );
          } else {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        }
      )
    );
  }
}

Future<Object?>? _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error("Location services are disabled.");
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error("Location permission are denied.");
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error(
      "Location permission are permanently demied, we cannot request permisiion."
    );
  }

  return await Geolocator.getCurrentPosition();
}