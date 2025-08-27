import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/weather_service.dart';
import '../services/event_service.dart';
import '../services/chat_gemini_service.dart';
import '../models/event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WeatherService _weatherService = WeatherService();
  EventService _eventService = EventService();
  GeminiService _aiService = GeminiService();
  
  Map<String, dynamic>? _weatherData;
  List<Event> _todayEvents = [];
  String? _aiRecommendation;
  bool _isLoading = true;
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 날씨 정보 로드
      await _loadWeatherData();
      
      // 오늘 일정 로드
      await _loadTodayEvents();
      
      // AI 추천 로드
      await _loadAiRecommendation();
      
    } catch (e) {
      print('홈 데이터 로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadWeatherData() async {
    try {
      final weather = await _weatherService.fetchCurrentLocationWeather();
      if (mounted) {
        setState(() {
          _weatherData = weather;
        });
      }
    } catch (e) {
      print('날씨 정보 로드 실패: $e');
    }
  }

  Future<void> _loadTodayEvents() async {
    try {
      final today = DateTime.now();
      final events = await _eventService.getEventsForDate(today);
      if (mounted) {
        setState(() {
          _todayEvents = events;
        });
      }
    } catch (e) {
      print('오늘 일정 로드 실패: $e');
    }
  }

  Future<void> _loadAiRecommendation() async {
    if (!mounted) return;
    
    setState(() {
      _isAiLoading = true;
    });

    try {
      final today = DateTime.now();
      final events = await _eventService.getEventsForDate(today);
      
      if (events.isNotEmpty) {
        final eventSummary = events.map((e) => 
          '${DateFormat('HH:mm').format(e.startTime)} - ${e.title}'
        ).join('\n');
        
        final prompt = '''
오늘 일정을 바탕으로 AI 비서가 도움을 드리겠습니다.

오늘 일정:
$eventSummary

위 일정을 바탕으로 다음을 추천해주세요:
1. 일정 관리 팁
2. 시간 활용 조언
3. 준비사항 안내
4. 긍정적인 격려 메시지

간결하고 실용적인 조언을 해주세요.
''';

        final response = await _aiService.sendMessage(
          message: prompt,
          systemPrompt: '당신은 친근하고 도움이 되는 AI 비서입니다. 사용자의 일정을 바탕으로 실용적인 조언을 제공해주세요.',
          functionDeclarations: [],
        );
        
        if (mounted) {
          setState(() {
            _aiRecommendation = response.text ?? 'AI 추천을 불러오는 중 오류가 발생했습니다.';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _aiRecommendation = '오늘은 특별한 일정이 없네요! 새로운 일정을 추가해보시는 건 어떨까요? 😊';
          });
        }
      }
    } catch (e) {
      print('AI 추천 로드 실패: $e');
      if (mounted) {
        setState(() {
          _aiRecommendation = 'AI 추천을 불러오는 중 오류가 발생했습니다.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '좋은 아침이에요!';
    if (hour < 18) return '좋은 오후에요!';
    return '좋은 저녁이에요!';
  }

  Widget _buildWeatherCard() {
    if (_weatherData == null) {
      return _buildLoadingCard('날씨 정보를 불러오는 중...');
    }

    final temp = _weatherData!['main']?['temp']?.toString() ?? 'N/A';
    final description = _weatherData!['weather']?[0]?['description'] ?? '날씨 정보 없음';
    final icon = _weatherData!['weather']?[0]?['icon'] ?? '01d';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 날씨 아이콘 (텍스트로 대체)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.wb_sunny,
                size: 30,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 날씨',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$temp°C',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayEventsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '오늘의 일정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_todayEvents.length}개',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_todayEvents.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '오늘은 일정이 없어요!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ..._todayEvents.take(3).map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            if (_todayEvents.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '그 외 ${_todayEvents.length - 3}개 일정 더...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiRecommendationCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'AI 비서 추천',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isAiLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_aiRecommendation == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'AI 추천을 불러오는 중...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              Text(
                _aiRecommendation!,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(String message) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
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
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHomeData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 헤더
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(DateTime.now()),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 날씨 카드
                    _buildWeatherCard(),
                    
                    // 오늘 일정 카드
                    _buildTodayEventsCard(),
                    
                    // AI 추천 카드
                    _buildAiRecommendationCard(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
