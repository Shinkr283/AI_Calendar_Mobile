import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService {
  final String apiKey = '7091ebdaf31310384aa6c653de1948d0';

  Future<Map<String, dynamic>?> fetchWeather(double lat, double lon) async {
    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return null;
  }

  // 현재 위치의 날씨를 가져오는 헬퍼
  Future<Map<String, dynamic>?> fetchCurrentLocationWeather() async {
    // 권한 및 위치 확인
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return null;
    }
    if (perm == LocationPermission.deniedForever) return null;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return await fetchWeather(pos.latitude, pos.longitude);
  }
} 