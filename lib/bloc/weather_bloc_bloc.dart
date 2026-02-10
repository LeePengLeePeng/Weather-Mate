import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:weather_test/data/weather_model.dart';
import 'package:weather_test/data/weather_repository.dart';

part 'weather_bloc_event.dart';
part 'weather_bloc_state.dart';

class WeatherBlocBloc extends Bloc<WeatherBlocEvent, WeatherBlocState> {
  final WeatherRepository _repository = WeatherRepository();
  WeatherBlocBloc() : super(WeatherBlocInitial()) {
    on<FetchWeather>((event, emit) async {
      emit(WeatherBlocLoading());
     try {
        print("目前定位座標: ${event.position.latitude}, ${event.position.longitude}");
        // 這一行最重要：Bloc 不管在哪，只管跟 Repository 要資料
        final weather = await _repository.getWeather(
          event.position.latitude,
          event.position.longitude,
          displayCityName: event.cityName,
        );
        print("成功取得資料: ${weather.areaName}");
        emit(WeatherBlocSuccess(weather));
      } catch (e) {
        print("發生錯誤 (Error): $e");
        emit(WeatherBlocFailure());
      }
    });
  }
}
