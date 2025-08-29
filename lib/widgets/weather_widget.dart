import 'package:flutter/material.dart';
import '../services/location_weather_service.dart';

class WeatherWidget extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback? onTap;

  const WeatherWidget({
    super.key,
    required this.isEnabled,
    this.onTap,
  });

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  bool _isLoading = true;
  Map<String, dynamic>? _weatherData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.isEnabled) {
      _loadWeatherData();
    }
  }

  @override
  void didUpdateWidget(WeatherWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _loadWeatherData();
    }
  }

  Future<void> _loadWeatherData() async {
    if (!widget.isEnabled) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('🌤️ WeatherWidget: 날씨 데이터 로드 시작');
      final weatherService = LocationWeatherService();
      final weather = await weatherService.fetchAndSaveLocationWeather();
      
      print('🌤️ WeatherWidget: 날씨 데이터 로드 완료 - ${weather != null ? '성공' : '실패'}');
      if (weather != null) {
        print('🌤️ WeatherWidget: 날씨 데이터 구조 - ${weather.keys.toList()}');
        print('🌤️ WeatherWidget: 온도 - ${weather['main']?['temp']}');
        print('🌤️ WeatherWidget: 날씨 설명 - ${weather['weather']?[0]?['description']}');
      }
      
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ WeatherWidget: 날씨 데이터 로드 실패 - $e');
      if (mounted) {
        setState(() {
          _errorMessage = '날씨 정보를 가져올 수 없습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _getWeatherAdvice() {
    if (_weatherData == null) return '날씨 정보를 확인해보세요';
    
    // OpenWeatherMap API 응답 구조에 맞게 수정
    final temp = (_weatherData!['main']?['temp'] as num?)?.toDouble() ?? 0;
    final condition = (_weatherData!['weather']?[0]?['description'] as String?) ?? '';
    
    // 온도 기반 기본 조언
    String advice = '';
    if (temp < 5) {
      advice = '따뜻한 옷을 입고 외출하세요';
    } else if (temp < 15) {
      advice = '가벼운 겉옷을 챙기세요';
    } else if (temp < 25) {
      advice = '날씨가 좋습니다. 야외 활동하기 좋아요';
    } else {
      advice = '더운 날씨입니다. 시원한 곳에서 휴식을 취하세요';
    }
    
    // 날씨 상태별 추가 조언
    if (condition.contains('비') || condition.contains('Rain')) {
      advice += ' 우산을 챙기세요!';
    } else if (condition.contains('눈') || condition.contains('Snow')) {
      advice += ' 미끄러지지 않게 조심하세요!';
    } else if (condition.contains('흐림') || condition.contains('Cloud')) {
      advice += ' 갑자기 비가 올 수 있어요.';
    } else if (condition.contains('맑음') || condition.contains('Clear')) {
      advice += ' 햇볕이 강할 수 있어요.';
    }
    
    return advice;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade300, Colors.orange.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  '오늘의 날씨',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Text(
                '날씨 정보를 가져오는 중...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              )
            else if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              )
            else if (_weatherData != null) ...[
              Row(
                children: [
                  Text(
                    '${(_weatherData!['main']?['temp'] as num?)?.toStringAsFixed(1) ?? 'N/A'}°C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _weatherData!['weather']?[0]?['description'] ?? '날씨 정보 없음',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getWeatherAdvice(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
