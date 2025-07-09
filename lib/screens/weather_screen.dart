import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({Key? key}) : super(key: key);

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  Map<String, dynamic>? weatherData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  Future<void> fetchWeather() async {
    setState(() => isLoading = true);
    // 위치 권한 요청 및 현재 위치 받아오기
    LocationPermission permission = await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    // 날씨 정보 받아오기
    WeatherService weatherService = WeatherService();
    final data =
        await weatherService.fetchWeather(position.latitude, position.longitude);

    setState(() {
      weatherData = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (weatherData == null) {
      return const Center(child: Text('날씨 정보를 불러올 수 없습니다.'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('현재 날씨')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${weatherData!['name']}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              '${weatherData!['main']['temp']}°C',
              style: const TextStyle(fontSize: 48),
            ),
            Text(
              '${weatherData!['weather'][0]['description']}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: fetchWeather,
              child: const Text('새로고침'),
            ),
          ],
        ),
      ),
    );
  }
} 