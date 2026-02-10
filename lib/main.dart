import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:weather_test/bloc/weather_bloc_bloc.dart';
import 'package:weather_test/screens/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz; 
import 'package:flutter_timezone/flutter_timezone.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 載入 .env 檔案
  await dotenv.load(fileName: ".env");

  await initializeDateFormatting('zh_TW', null);

  // 初始化全球時區資料庫
  tz.initializeTimeZones();

  // 取得裝置目前所在時區
  final String localTimeZone = await FlutterTimezone.getLocalTimezone();

  // 設定整個 App 的本地時區
  tz.setLocalLocation(tz.getLocation(localTimeZone));

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
              create: (context) => WeatherBlocBloc()..add(
                FetchWeather(snap.data as Position)
              ),
              child: const HomeScreen(),
            );
          } else if (snap.hasError) {
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