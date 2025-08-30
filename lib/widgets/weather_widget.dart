import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_weather_service.dart';
import '../services/chat_service.dart';
import '../screens/chat_screen.dart';

class WeatherWidget extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback? onTap;

  const WeatherWidget({super.key, required this.isEnabled, this.onTap});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  bool _isLoading = true;
  Map<String, dynamic>? _weatherData;

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
    });

    try {
      print('🌤️ WeatherWidget: 날씨 데이터 로드 시작');
      final weatherService = LocationWeatherService();
      final weather = await weatherService.fetchAndSaveLocationWeather();

      print(
        '🌤️ WeatherWidget: 날씨 데이터 로드 완료 - ${weather != null ? '성공' : '실패'}',
      );
      if (weather != null) {
        print('🌤️ WeatherWidget: 날씨 데이터 구조 - ${weather.keys.toList()}');
        print('🌤️ WeatherWidget: 온도 - ${weather['main']?['temp']}');
        print(
          '🌤️ WeatherWidget: 날씨 설명 - ${weather['weather']?[0]?['description']}',
        );
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
          _isLoading = false;
        });
      }
    }
  }

  // 날씨 상태에 따른 아이콘 반환
  IconData _getWeatherIcon() {
    if (_weatherData == null) return Icons.wb_sunny;

    final condition =
        (_weatherData!['weather']?[0]?['description'] as String?) ?? '';
    final temp = (_weatherData!['main']?['temp'] as num?)?.toDouble() ?? 0;

    // 날씨 상태별 아이콘
    if (condition.contains('비') ||
        condition.contains('Rain') ||
        condition.contains('drizzle')) {
      return Icons.water_drop;
    } else if (condition.contains('눈') || condition.contains('Snow')) {
      return Icons.ac_unit;
    } else if (condition.contains('흐림') ||
        condition.contains('Cloud') ||
        condition.contains('cloudy')) {
      return Icons.cloud;
    } else if (condition.contains('안개') ||
        condition.contains('fog') ||
        condition.contains('mist')) {
      return Icons.cloud;
    } else if (condition.contains('맑음') ||
        condition.contains('Clear') ||
        condition.contains('sunny')) {
      return Icons.wb_sunny;
    } else if (condition.contains('천둥') ||
        condition.contains('thunder') ||
        condition.contains('storm')) {
      return Icons.thunderstorm;
    } else if (temp > 30) {
      return Icons.wb_sunny;
    } else if (temp < 5) {
      return Icons.ac_unit;
    } else {
      return Icons.wb_sunny;
    }
  }

  // 날씨 상태에 따른 제목 반환
  String _getWeatherTitle() {
    if (_weatherData == null) return '오늘의 날씨';

    final condition =
        (_weatherData!['weather']?[0]?['description'] as String?) ?? '';
    final temp = (_weatherData!['main']?['temp'] as num?)?.toDouble() ?? 0;

    // 실제 받아온 날씨 정보를 제목에 표시
    if (condition.isNotEmpty) {
      return condition; // 예: "맑음", "흐림", "비", "눈" 등
    } else {
      // 날씨 정보가 없으면 온도 기반으로 표시
      if (temp > 30) {
        return '더운 날';
      } else if (temp < 5) {
        return '추운 날';
      } else {
        return '좋은 날씨';
      }
    }
  }

  String _getWeatherAdvice() {
    if (_weatherData == null) return '날씨 정보를 확인해보세요';

    // OpenWeatherMap API 응답 구조에 맞게 수정
    final temp = (_weatherData!['main']?['temp'] as num?)?.toDouble() ?? 0;
    final condition =
        (_weatherData!['weather']?[0]?['description'] as String?) ?? '';

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

  // 채팅 화면 표시
  void _showChatScreen() {
    // ChatProvider 초기화
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.clearMessages();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wb_sunny,
                      color: Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '날씨 AI 비서',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // AI 채팅 화면
              Expanded(
                child: ChatScreen(
                  initialEvent: null,
                  initialTopic: '날씨',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _showChatScreen,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        padding: const EdgeInsets.all(14),
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
                Icon(_getWeatherIcon(), color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  _getWeatherTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_weatherData?['main']?['temp'] as num?)?.toStringAsFixed(1) ?? 'N/A'}°C',
                  style: const TextStyle(
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
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _loadWeatherData,
                    tooltip: '날씨 새로고침',
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              _getWeatherAdvice(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
